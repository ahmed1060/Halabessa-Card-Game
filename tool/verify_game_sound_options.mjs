// Offline artifact checks only. No browser, upload or application-settings access.
import assert from 'node:assert/strict';
import {readFile,writeFile} from 'node:fs/promises';
const directory='build/sound-options-2026-10-24';
const catalog=JSON.parse(await readFile(`${directory}/catalog.json`,'utf8'));
assert.equal(catalog.events.length,14);
const registered=[];
for(const name of ['sfx','music']){
  const source=await readFile(`lib/features/home/presentation/pages/admin_${name}_management_screen.dart`,'utf8');
  registered.push(...Array.from(source.matchAll(/'path':\s*'([^']+)'/g),m=>m[1]));
}
assert.deepEqual(catalog.events.flatMap(event=>event.assetPaths).sort(),registered.sort());
let clips=0,bytesTotal=0;
const results=[];
for(const event of catalog.events){
  assert.equal(event.candidates.length,6);
  assert.equal(new Set(event.candidates.map(c=>c.fnv1a32)).size,6,'six distinct audio files per event');
  for(const candidate of event.candidates){
    const bytes=await readFile(`${directory}/${candidate.file}`);
    assert.equal(bytes.subarray(0,4).toString(),'RIFF');
    assert.equal(bytes.subarray(8,12).toString(),'WAVE');
    assert.equal(bytes.readUInt16LE(20),1);assert.equal(bytes.readUInt16LE(22),1);
    assert.equal(bytes.readUInt16LE(34),16);assert.equal(bytes.readUInt32LE(40),bytes.length-44);
    assert.equal(bytes.length,candidate.bytes);
    let fingerprint=2166136261;
    for(const byte of bytes)fingerprint=Math.imul(fingerprint^byte,16777619)>>>0;
    assert.equal(fingerprint,candidate.fnv1a32);
    const count=(bytes.length-44)/2;
    let peak=0,sum=0,finite=true;
    for(let i=0;i<count;i++){
      const sample=bytes.readInt16LE(44+i*2)/32768;
      peak=Math.max(peak,Math.abs(sample));sum+=sample*sample;finite&&=Number.isFinite(sample);
    }
    assert(finite&&sum>0);assert(peak<1);
    if(candidate.id!=='current'){
      if(event.group==='Music'){
        const first=bytes.readInt16LE(44),second=bytes.readInt16LE(46);
        const last=bytes.readInt16LE(bytes.length-2),previous=bytes.readInt16LE(bytes.length-4);
        // An ordinary waveform has a non-zero adjacent-sample slope. Compare
        // the wrap step with its neighboring steps, not against silence.
        const wrapError=Math.abs((first-last)-((last-previous)+(second-first))/2)/32768;
        assert(wrapError<.005,'music boundary slope continuity');
      }else{
        assert(Math.abs(bytes.readInt16LE(bytes.length-2))/32768<.002,'effect tail fade');
      }
    }
    if(event.id==='slam'&&candidate.id==='current'){
      assert.equal(fingerprint,3132475412,'preserve exactly the selected slam A');
    }
    results.push({event:event.id,choice:candidate.id,peak,rms:Math.sqrt(sum/count)});
    clips++;bytesTotal+=bytes.length;
  }
}
assert.equal(clips,84);
const previous=JSON.parse(await readFile(`${directory}/catalog-before-expansion.json`,'utf8'));
let preserved=0;
for(const event of previous.events){
  for(const candidate of event.candidates){
    const expanded=catalog.events.find(e=>e.id===event.id).candidates.find(c=>c.id===candidate.id);
    assert.equal(expanded.fnv1a32,candidate.fnv1a32,'existing audition choice is immutable');
    preserved++;
  }
}
assert.equal(preserved,42);
const report={passed:true,configuredPaths:registered.length,eventGroups:catalog.events.length,clips,bytesTotal,
  preservedExistingClips:preserved,
  checks:['all registered paths covered','six distinct choices per event','valid non-silent mono PCM','metadata/fingerprint integrity','no digital clipping','candidate effect tail fades','music boundary continuity','approved slam A preserved','all original 42 clips unchanged'],results};
await writeFile(`${directory}/artifact-verification.json`,JSON.stringify(report,null,2));
console.log(JSON.stringify({...report,results:undefined}));
