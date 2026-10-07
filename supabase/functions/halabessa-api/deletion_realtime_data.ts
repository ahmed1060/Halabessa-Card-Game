// Targeted server-only RTDB cleanup. Room/peer inventory must come from the
// authorized job and server records, never from a consumer's request payload.
const socialFields=['friends','pendingFriendRequests','sentFriendRequests'];
const batch=40;
const key=/^[A-Za-z0-9_-]{1,128}$/;
function validUid(uid: string) {
  if (!/^[A-Za-z0-9:_-]{1,128}$/.test(uid)) throw new Error('invalid_deletion_uid');
}
function roomId(id: string) {
  if (!/^[A-Z]{3}[0-9]{5}$/.test(id)) throw new Error('invalid_deletion_room');
}
export function createRealtimeDeletionDataStore(url: string,token: ()=>Promise<string>,fetcher: typeof fetch=fetch) {
  const parsed=new URL(url);
  if(parsed.protocol!=='https:' || parsed.pathname!=='/')throw new Error('invalid_deletion_database');
  async function request(path: string,method='GET',body?:unknown,etag?:string,parameters?:Record<string,string>) {
    const target=new URL(`/${path}.json`,parsed.origin);
    for(const [name,value] of Object.entries(parameters??{}))target.searchParams.set(name,value);
    let response:Response;
    try {
      response=await fetcher(target,{method,signal:AbortSignal.timeout(8000),headers:{
        Authorization:`Bearer ${await token()}`,'Content-Type':'application/json',
        ...(method==='GET'?{'X-Firebase-ETag':'true'}:{}),...(etag?{'if-match':etag}:{}),
      },...(body===undefined?{}:{body:JSON.stringify(body)})});
    } catch {throw new Error('deletion_realtime_unavailable');}
    if(!response.ok)throw new Error('deletion_realtime_unavailable');
    let data:unknown;try {data=await response.json();} catch {throw new Error('deletion_realtime_unavailable');}
    return {data,etag:response.headers.get('etag')};
  }
  return {
    async block(uid:string) {
      validUid(uid);
      await request(`accountDeletionBlocked/${encodeURIComponent(uid)}`,'PUT',true);
    },
    async removeOwnProfileAndPresence(uid:string) {
      validUid(uid);
      await request('','PATCH',{
        [`users/${uid}`]:null,[`userPresence/${uid}`]:null,[`userMatches/${uid}`]:null,
      });
      // Persistent accountDeletionBlocked is deliberately retained. Removing it
      // would reopen Firebase SDK access to an already-issued signed JWT.
    },
    async removePeerSocialEdges(uid:string,peer:string) {
      validUid(uid);validUid(peer);
      if(uid===peer)throw new Error('invalid_deletion_peer');
      for(const field of socialFields) {
        const path=`users/${encodeURIComponent(peer)}/${field}`;
        const current=await request(path);
        if(current.data===null)continue;
        if(!current.etag || !current.data || typeof current.data!=='object')throw new Error('invalid_deletion_realtime_data');
        const values=current.data as Record<string,unknown>;
        if(!Object.values(values).includes(uid))continue;
        // Compare-and-set only this social field, never replace the user's whole
        // mirror. A simultaneous addition changes its ETag and keeps us pending.
        const next=Array.isArray(values)?values.filter(value=>value!==uid)
          :Object.fromEntries(Object.entries(values).filter(([,value])=>value!==uid));
        await request(path,'PUT',Object.keys(next).length?next:null,current.etag);
      }
    },
    async removeRoomMessages(uid:string,id:string):Promise<boolean> {
      validUid(uid);roomId(id);
      const updates:Record<string,null>={};
      let more=false;
      for(const path of [`matchChat/${id}/public`,`matchChat/${id}/teamA`,`matchChat/${id}/teamB`,`matches/${id}/chat`]) {
        const found=await request(path,'GET',undefined,undefined,{
          orderBy:JSON.stringify('senderId'),equalTo:JSON.stringify(uid),limitToFirst:String(batch),
        });
        if(found.data===null)continue;
        if(!found.data || typeof found.data!=='object' || Array.isArray(found.data))throw new Error('invalid_deletion_realtime_data');
        const rows=Object.entries(found.data);
        if(rows.length>batch)throw new Error('invalid_deletion_realtime_data');
        for(const [messageId,message] of rows) {
          if(!key.test(messageId) || !message || typeof message!=='object' ||
            (message as Record<string,unknown>).senderId!==uid)throw new Error('invalid_deletion_realtime_data');
          updates[`${path}/${messageId}`]=null;
        }
        if(rows.length===batch)more=true;
      }
      updates[`matchChat/${id}/rate/${uid}`]=null;
      updates[`matches/${id}/presence/${uid}`]=null;
      await request('','PATCH',updates);
      return !more;
    },
  };
}
