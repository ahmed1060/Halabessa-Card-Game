import {test} from 'node:test';
import assert from 'node:assert/strict';
import {createServer} from 'node:http';
import {readFile} from 'node:fs/promises';
import {storeAsset, type AssetUploadBody} from '../../supabase/functions/halabessa-api/asset_upload.ts';

const sample = await readFile(new URL('../../assets/audio/defaults/2026-10-24/play-d-b2250eaa.wav',import.meta.url));
const request: AssetUploadBody={kind:'sfx',assetKey:'sfx/play.mp3',contentType:'audio/wav',base64:sample.toString('base64')};
const dependencies={supabaseUrl:'https://storage.invalid',serviceRoleKey:'local-test-not-a-secret',privileged:true};
const user={uid:'test-admin'};
test('same-slot uploads use distinct immutable paths with no upsert',async()=>{
  const requests: Array<{url:string; headers:Headers; body:Uint8Array}> = [];
  const transport: typeof fetch = async(input,init)=>{
    requests.push({url:String(input),headers:new Headers(init?.headers),body:init?.body as Uint8Array});
    return new Response('{}',{status:200});
  };
  const a=await storeAsset(request,user,{...dependencies,fetch:transport});
  const b=await storeAsset(request,user,{...dependencies,fetch:transport});
  assert.notEqual(a.path,b.path);
  assert.match(a.path,/^audio\/sfx\/sfx-play-mp3\/v2\/[0-9a-f-]{36}\.wav$/);
  assert.equal(requests[0].headers.get('x-upsert'),'false');
  assert.equal(requests[0].headers.get('Content-Type'),'audio/wav');
  assert.deepEqual(Buffer.from(requests[0].body),sample);
  assert.equal(a.publicUrl,requests[0].url.replace('/object/','/object/public/'));
});
test('ordinary/anonymous admission never reaches storage for admin asset kinds',async()=>{
  let called=false;
  const transport: typeof fetch=async()=>{called=true;return new Response('{}');};
  for(const kind of ['music','sfx','storeItem']){
    await assert.rejects(storeAsset({...request,kind},user,{...dependencies,privileged:false,fetch:transport}),/admin_required/);
  }
  assert.equal(called,false);
});
test('audio validation rejects unknown/mismatched slots, image MIME and fake audio',async()=>{
  let called=false;
  const transport: typeof fetch=async()=>{called=true;return new Response('{}');};
  for(const body of [
    {...request,assetKey:'../other'}, {...request,assetKey:'music/bg_music.mp3'},
    {...request,kind:'music'}, {...request,contentType:'image/png'},
    {...request,base64:Buffer.from('<html>not audio</html>').toString('base64')},
    {...request,base64:'%%%bad'}, {...request,base64:''},
    {...request,base64:Buffer.alloc(4*1024*1024+1).toString('base64')},
  ]) await assert.rejects(storeAsset(body,user,{...dependencies,fetch:transport}),/invalid_asset/);
  assert.equal(called,false);
});
test('all 16 UI audio slots match backend policy and valid MP3/M4A containers remain supported',async()=>{
  for(const kind of ['sfx','music']){
    const screen=await readFile(new URL(`../../lib/features/home/presentation/pages/admin_${kind}_management_screen.dart`,import.meta.url),'utf8');
    const keys=Array.from(screen.matchAll(/'path':\s*'([^']+)'/g),match=>match[1]);
    for(const assetKey of keys)await storeAsset({...request,kind,assetKey},user,{...dependencies,fetch:async()=>new Response('{}')});
  }
  for(const [contentType,bytes] of [
    ['audio/mpeg',Buffer.concat([Buffer.from('ID3'),Buffer.alloc(20)])],
    ['audio/mp4',Buffer.concat([Buffer.from([0,0,0,20]),Buffer.from('ftypM4A '),Buffer.alloc(8)])],
  ] as const)await storeAsset({...request,contentType,base64:bytes.toString('base64')},user,{...dependencies,fetch:async()=>new Response('{}')});
});
test('version collision/storage failure cannot overwrite or delete the saved object',async()=>{
  const seen: string[]=[];
  for(const status of [400,409,500]){
    await assert.rejects(storeAsset(request,user,{...dependencies,fetch:async(_url,init)=>{
      seen.push(init?.method??'');assert.equal(new Headers(init?.headers).get('x-upsert'),'false');
      return new Response('collision or failure',{status});
    }}),/asset_upload_failed/);
  }
  assert.deepEqual(seen,['POST','POST','POST']);
});
test('avatar and store-item paths retain existing behavior and avatar safety',async()=>{
  const headers: string[]=[];
  const transport: typeof fetch=async(_url,init)=>{headers.push(new Headers(init?.headers).get('x-upsert')!);return new Response('{}');};
  const avatar=await storeAsset({kind:'avatar',contentType:'image/png',base64:Buffer.from('existing-image-policy').toString('base64')},user,{...dependencies,privileged:false,fetch:transport});
  assert.equal(avatar.path,'avatars/test-admin/profile.png');
  const item=await storeAsset({kind:'storeItem',contentType:'image/png',base64:Buffer.from('image').toString('base64')},user,{...dependencies,fetch:transport});
  assert.match(item.path,/^store-items\/[0-9a-f-]{36}\.png$/);assert.deepEqual(headers,['true','true']);
  await assert.rejects(storeAsset({kind:'avatar',contentType:'audio/wav',base64:request.base64},user,{...dependencies,fetch:transport}),/invalid_asset/);
});
test('actual local HTTP storage protocol preserves A after concurrent B replacements',async()=>{
  const files=new Map<string,Buffer>();
  const server=createServer(async(req,res)=>{
    const chunks: Buffer[]=[];for await(const chunk of req)chunks.push(Buffer.from(chunk));
    assert.equal(req.headers['x-upsert'],'false');
    if(files.has(req.url!)){res.writeHead(409);res.end('already exists');return;}
    files.set(req.url!,Buffer.concat(chunks));res.writeHead(200,{'Content-Type':'application/json'});res.end('{}');
  });
  await new Promise<void>(resolve=>server.listen(0,'127.0.0.1',resolve));
  try{
    const address=server.address();assert(address&&typeof address==='object');
    const config={...dependencies,supabaseUrl:`http://127.0.0.1:${address.port}`};
    const a=await storeAsset(request,user,config);
    const savedPath=new URL(a.publicUrl).pathname.replace('/object/public/','/object/');
    const old=Buffer.from(files.get(savedPath)!);
    const changed=Buffer.from(sample);changed[50]^=1;
    const replacements=await Promise.all(Array.from({length:5},()=>storeAsset({...request,base64:changed.toString('base64')},user,config)));
    assert.equal(new Set([a.path,...replacements.map(r=>r.path)]).size,6);
    assert.deepEqual(files.get(savedPath),old);assert.equal(files.size,6);
    await assert.rejects(storeAsset(request,user,{...config,versionId:()=>a.path.split('/').pop()!.slice(0,-4)}),/asset_upload_failed/);
    assert.deepEqual(files.get(savedPath),old);
  }finally{await new Promise<void>((resolve,reject)=>server.close(error=>error?reject(error):resolve()));}
});
