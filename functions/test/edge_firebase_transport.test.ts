import test from 'node:test';
import assert from 'node:assert/strict';
import {createFirebaseDatabaseRequest} from '../../supabase/functions/halabessa-api/firebase_transport.ts';

test('conditional creation and mirror CAS do not combine if-match with print=silent', async () => {
  const request=createFirebaseDatabaseRequest('https://qa.invalid',async()=>'test-token',async(url,options)=>{
    assert.equal(String(url),'https://qa.invalid/matches/ABC12345.json');
    assert.ok(new Headers(options!.headers).get('if-match'));
    return new Response('{}',{status:200});
  });
  assert.equal((await request('matches/ABC12345','PUT',{},'null_etag')).status,200);
  assert.equal((await request('matches/ABC12345','PUT',{},'"revision-tag"')).status,200);
});

test('GET retrieves ETag and 412 retains conflict data for revision-aware refetch', async () => {
  const request=createFirebaseDatabaseRequest('https://qa.invalid',async()=>'test-token',async(url,options)=>{
    assert.equal(new URL(String(url)).search,'');
    const get=options!.method==='GET';
    if(get)assert.equal(new Headers(options!.headers).get('X-Firebase-ETag'),'true');
    return new Response('{"serverVersion":7}',{status:get?200:412,headers:{etag:'"new-tag"'}});
  });
  assert.deepEqual(await request('matches/ABC12345'),{status:200,data:{serverVersion:7},etag:'"new-tag"'});
  assert.deepEqual(await request('matches/ABC12345','PUT',{},'"old-tag"'),{status:412,data:{serverVersion:7},etag:'"new-tag"'});
});

test('unconditional supported writes handle empty 204; DELETE never adds silent', async () => {
  const request=createFirebaseDatabaseRequest('https://qa.invalid',async()=>'test-token',async(url,options)=>{
    const deletion=options!.method==='DELETE';
    assert.equal(new URL(String(url)).search,deletion?'':'?print=silent');
    return new Response(null,{status:204});
  });
  for(const method of ['PUT','POST','PATCH','DELETE'])assert.equal((await request('test',method,null)).data,null);
});
