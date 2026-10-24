'use strict';
// This page never calls the game or any cloud service. Choices are proposals only.
const storageKey='halabessa-sound-review-2026-10-24-v1';
const player=document.getElementById('player');
const status=document.getElementById('status');
const progress=document.getElementById('progress');
let catalog=[],choices={},active=null,playbackSerial=0;
const text=(tag,value,className)=>{const node=document.createElement(tag);node.textContent=value;if(className)node.className=className;return node;};
function readChoices(){try{const saved=JSON.parse(localStorage.getItem(storageKey)||'{}');return saved&&typeof saved==='object'&&!Array.isArray(saved)?saved:{};}catch{return {};}}
function validChoice(event,id){return event.candidates.some(c=>c.id===id);}
function persist(){try{localStorage.setItem(storageKey,JSON.stringify(choices));}catch{status.textContent='Browser storage is unavailable. Keep this page open and export your choices before leaving.';}}
function update(){
  let count=0;
  for(const event of catalog){
    if(validChoice(event,choices[event.id]))count++;
    for(const candidate of event.candidates){
      const input=document.getElementById(`${event.id}-${candidate.id}`);
      input.checked=choices[event.id]===candidate.id;
      input.closest('.option').classList.toggle('selected',input.checked);
    }
  }
  progress.textContent=`${count} of ${catalog.length} sounds chosen`;
}
function stop(){playbackSerial++;player.pause();player.currentTime=0;active=null;document.querySelectorAll('.playing').forEach(button=>{button.classList.remove('playing');button.textContent='Play';});document.getElementById('now-playing').textContent='Nothing playing';}
async function play(event,candidate,button){
  stop();active={event,candidate};const serial=playbackSerial;
  player.src=candidate.file; // No audio URL/download is assigned before a click.
  player.loop=event.group==='Music'&&document.getElementById('loop').checked;
  document.getElementById('now-playing').textContent=`${event.title}: ${candidate.id==='current'?'Current':candidate.id.toUpperCase()} — ${candidate.label}`;
  button.classList.add('playing');button.textContent='Playing';
  try{await player.play();if(serial===playbackSerial)status.textContent='';}catch{if(serial===playbackSerial){stop();status.textContent='Playback did not start. Press Play again or use the native audio controls.';}}
}
function packet(){
  const selected={};
  for(const event of catalog){
    const candidate=event.candidates.find(c=>c.id===choices[event.id]);
    if(!candidate)continue;
    for(const path of event.assetPaths)selected[path]={event:event.id,choice:candidate.id,label:candidate.label,file:candidate.file,fnv1a32:candidate.fnv1a32};
  }
  return {schema:1,reviewOnly:true,gameDefaultsChanged:false,reviewDate:'2026-10-24',selected,
    unchosen:catalog.filter(event=>!validChoice(event,choices[event.id])).map(event=>event.id)};
}
async function initialize(){
  const response=await fetch('catalog.json',{cache:'no-store'});
  if(!response.ok)throw new Error('Catalog unavailable');
  const data=await response.json();catalog=data.events;
  choices=readChoices();
  for(const event of catalog){
    if(!validChoice(event,choices[event.id])){
      delete choices[event.id];
      if(event.approvedChoice)choices[event.id]=event.approvedChoice;
    }
  }
  const root=document.getElementById('catalog');
  for(const group of [...new Set(catalog.map(event=>event.group))]){
    const section=document.createElement('section');section.className='group';section.dataset.group=group;
    section.append(text('h2',group));
    const list=document.createElement('ul');list.className='events';
    for(const event of catalog.filter(event=>event.group===group)){
      const row=document.createElement('li');row.className='event';
      const context=document.createElement('div');context.className='context';
      const heading=text('h3',event.title);heading.id=`title-${event.id}`;
      context.append(heading,text('p',event.when),text('small',event.assetPaths.length===3?'One choice covers all three slam routing slots.':event.assetPaths[0]));
      const options=document.createElement('fieldset');options.className='options';
      options.append(text('legend',`Choose a sound for ${event.title}`,'sr-only'));
      for(const candidate of event.candidates){
        const option=document.createElement('div');option.className='option';
        const input=document.createElement('input');input.type='radio';input.name=event.id;input.id=`${event.id}-${candidate.id}`;input.value=candidate.id;
        const label=document.createElement('label');label.htmlFor=input.id;
        const name=candidate.id==='current'?'Current':candidate.id.toUpperCase();
        label.append(input,text('span',`${name}: ${candidate.label}`));
        const button=text('button','Play');button.type='button';button.setAttribute('aria-label',`Play ${name} for ${event.title}`);
        button.addEventListener('click',()=>play(event,candidate,button));
        input.addEventListener('change',()=>{choices[event.id]=candidate.id;persist();update();});
        option.append(label,text('small',`${candidate.seconds.toFixed(2)} s • ${candidate.sampleRate/1000} kHz`),button);options.append(option);
      }
      row.append(context,options);list.append(row);
    }
    section.append(list);root.append(section);
  }
  for(const id of ['export','summary','clear'])document.getElementById(id).disabled=false;
  update();
}
document.getElementById('volume').addEventListener('input',event=>{player.volume=Number(event.target.value)/100;document.getElementById('volume-value').value=`${event.target.value}%`;});
player.volume=.35;
document.getElementById('stop').addEventListener('click',stop);
document.getElementById('loop').addEventListener('change',event=>{player.loop=active?.event.group==='Music'&&event.target.checked;});
player.addEventListener('ended',stop);
player.addEventListener('error',()=>{if(active){stop();status.textContent='This clip could not be loaded. Please tell me its event and option.';}});
document.addEventListener('visibilitychange',()=>{if(document.hidden)stop();});
window.addEventListener('pagehide',stop);
document.getElementById('category').addEventListener('change',event=>{for(const section of document.querySelectorAll('.group'))section.hidden=event.target.value!=='all'&&section.dataset.group!==event.target.value;});
document.getElementById('summary').addEventListener('click',()=>{
  const lines=catalog.map(event=>`${event.title}: ${choices[event.id]?(choices[event.id]==='current'?'Current':choices[event.id].toUpperCase()):'not chosen'}`);
  const field=document.getElementById('choice-text');field.value=`Halabessa sound choices (local review, not applied)\n${lines.join('\n')}`;
  document.getElementById('selection-summary').hidden=false;field.focus();field.select();
});
document.getElementById('clear').addEventListener('click',()=>{
  if(!window.confirm('Reset only the choices on this review page? Your approved slam A is retained. The game is not changed.'))return;
  choices={};for(const event of catalog)if(event.approvedChoice)choices[event.id]=event.approvedChoice;
  persist();update();document.getElementById('selection-summary').hidden=true;
  status.textContent='Review choices reset; the approved slam A is retained. No game setting changed.';
});
document.getElementById('export').addEventListener('click',()=>{
  const blob=new Blob([JSON.stringify(packet(),null,2)],{type:'application/json'});
  const url=URL.createObjectURL(blob),link=document.createElement('a');link.href=url;link.download='halabessa-sound-choices.json';
  document.body.append(link);link.click();link.remove();setTimeout(()=>URL.revokeObjectURL(url),1000);
  status.textContent='Choices exported. Attach the JSON in our chat; game defaults are still unchanged.';
});
initialize().catch(()=>{progress.textContent='Catalog unavailable';status.textContent='The local catalog could not be loaded. Ask me to restart the sound-review host.';});
