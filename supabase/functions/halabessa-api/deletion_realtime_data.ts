// Targeted server-only RTDB cleanup. Room/peer inventory must come from the
// authorized job and server records, never from a consumer's request payload.
const socialFields=['friends','pendingFriendRequests','sentFriendRequests'];
const batch=40;
const key=/^[A-Za-z0-9_-]{1,128}$/;
function validUid(uid: string) {
  if (!/^[A-Za-z0-9:_-]{1,128}$/.test(uid)) throw new Error('invalid_deletion_uid');
}
function roomId(id: string) {
  // Inventory includes historical RTDB keys, not only current room codes.
  // This server-only adapter still forbids slashes/path traversal and accepts
  // targets only from the durable, server-derived deletion inventory.
  if (!key.test(id)) throw new Error('invalid_deletion_room');
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
        // Firebase rejects ETag reads combined with shallow/filter queries.
        // Only unfiltered reads used for compare-and-set need an ETag.
        ...(method==='GET' && !parameters?{'X-Firebase-ETag':'true'}:{}),...(etag?{'if-match':etag}:{}),
      },...(body===undefined?{}:{body:JSON.stringify(body)})});
    } catch {throw new Error('deletion_realtime_unavailable');}
    if(!response.ok) {
      console.warn('deletion transport failed',{service:'realtime',operation:parameters?.shallow?'inventory':parameters?.orderBy?'messages':method,status:response.status});
      throw new Error('deletion_realtime_unavailable');
    }
    let data:unknown;try {data=await response.json();} catch {throw new Error('deletion_realtime_unavailable');}
    return {data,etag:response.headers.get('etag')};
  }
  return {
    async inventory(root:'users'|'matches'|'matchChat'|'matchViews') {
      const found=await request(root,'GET',undefined,undefined,{shallow:'true'});
      if(found.data===null)return [];
      if(!found.data || typeof found.data!=='object' || Array.isArray(found.data))throw new Error('invalid_deletion_realtime_data');
      const keys=Object.keys(found.data);
      // Never silently truncate an inventory and call cleanup complete.
      if(keys.length>10000 || keys.some(id=>!key.test(id)))throw new Error('deletion_inventory_too_large');
      return keys;
    },
    async legacyRoomReferences(uid:string,id:string) {
      validUid(uid);roomId(id);
      const current=await request(`matches/${id}`);
      if(current.data===null)return false;
      if(!current.data || typeof current.data!=='object' || Array.isArray(current.data))throw new Error('invalid_deletion_realtime_data');
      const row=current.data as Record<string,any>;
      // Check defined identity fields, never display-name/card substrings.
      return (Array.isArray(row.playerIds) && row.playerIds.includes(uid)) ||
        ['players','handCards','handCounts','playerNames','playerAvatars'].some(field=>row[field] && uid in row[field]) ||
        row.ownerUid===uid || row.hostUid===uid || row.lastPlayedBy===uid;
    },
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
      const profile=await request(`users/${encodeURIComponent(peer)}`);
      if(profile.data===null)return;
      if(!profile.data || typeof profile.data!=='object' || Array.isArray(profile.data))throw new Error('invalid_deletion_realtime_data');
      const snapshot=profile.data as Record<string,any>;
      if(!socialFields.some(field=>snapshot[field] && typeof snapshot[field]==='object' && Object.values(snapshot[field]).includes(uid)))return;
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
    async removeInvite(peer:string,id:string) {
      validUid(peer);roomId(id);
      await request(`users/${peer}/friendInvites/${id}`,'DELETE');
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
      updates[`matchViews/${id}/${uid}`]=null;
      await request('','PATCH',updates);
      return !more;
    },
  };
}
