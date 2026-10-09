import {continueDeletion,type DeletionEffects} from './account_deletion.ts';
import {createDeletionJobStore,type DeletionQuery} from './deletion_job_store.ts';
import {createDeletionRoomStore} from './deletion_rooms.ts';
import {createFirebaseDeletionDataStore} from './deletion_firebase_data.ts';
import {createRealtimeDeletionDataStore} from './deletion_realtime_data.ts';
import {createFirebaseIdentityStore} from './firebase_identity.ts';
import {createDeletionAvatarStore} from './deletion_avatars.ts';
import type {MatchState} from './match_engine.ts';
import type {CommittedRoom} from './match_delivery.ts';

type Dependencies={project:string;databaseUrl:string;storageUrl:string;storageKey:string;
  token:()=>Promise<string>;settle:(state:MatchState,createdAt:string)=>Promise<string>;
  publish:(id:string,room:CommittedRoom)=>Promise<void>;fetcher?:typeof fetch};

/** One job/stage per call, admitted connection closed by the HTTP caller.
 * A minute scheduler owns retries; the deleted user's session is never needed.
 */
export async function runDeletionWorker(query:DeletionQuery,id:string,deps:Dependencies) {
  const started=Date.now();
  const store=createDeletionJobStore(query);
  const fetcher=deps.fetcher??fetch;
  const firestore=createFirebaseDeletionDataStore(deps.project,deps.token,fetcher);
  const realtime=createRealtimeDeletionDataStore(deps.databaseUrl,deps.token,fetcher);
  const identity=createFirebaseIdentityStore(deps.project,deps.token,fetcher);
  const avatars=createDeletionAvatarStore(deps.storageUrl,deps.storageKey,fetcher);
  const rooms=createDeletionRoomStore(query,store.assertLease,deps.settle,deps.publish);
  async function inventory(kind:string,items:string[]) {
    store.assertLease(id);
    await query(`insert into halabessa.account_deletion_inventory(job_id,kind,item)
      select $1::uuid,$2,value from jsonb_array_elements_text($3::jsonb)
      on conflict do nothing`,[id,kind,JSON.stringify(items)]);
  }
  async function processed(kind:string,item:string) {
    await query('update halabessa.account_deletion_inventory set processed=true where job_id=$1::uuid and kind=$2 and item=$3',[id,kind,item]);
  }
  const more=()=>{throw new Error('deletion_more_data');};
  const effects:DeletionEffects={
    async blockSessions(uid) {
      await realtime.block(uid); await firestore.block(uid);
      await identity.disableAndRevoke(uid,Math.floor(Date.now()/1000));
    },
    async releaseAndAnonymizeRooms(uid) {
      if(!await rooms.advance(id,uid))more();
    },
    async removeSocialAndMessages(uid) {
      // Canonical associations persist into SQL before their external removal.
      await firestore.removeSocialEdges(uid,peers=>inventory('peer',peers));
      for(const root of ['users','matches','matchChat'] as const) {
        const scanned=await query("select 1 from halabessa.account_deletion_inventory where job_id=$1::uuid and kind='scan' and item=$2",[id,root]);
        if(!scanned.length) {
          const keys=await realtime.inventory(root);
          await inventory(root==='users'?'peer':'room',keys.filter(key=>key!==uid));
          await inventory('scan',[root]); await processed('scan',root);
          more();
        }
      }
      // The deployed invite mirror is keyed by room ID, not sender UID. Only
      // rows whose canonical sender still matches may authorize removal.
      const invites=await query('select room_id,recipient_uid from halabessa.room_invites where sender_uid=$1 order by room_id,recipient_uid limit 1 for update',[uid]);
      if(invites[0]) {
        await realtime.removeInvite(String(invites[0].recipient_uid),String(invites[0].room_id));
        await query('delete from halabessa.room_invites where sender_uid=$1 and recipient_uid=$2 and room_id=$3',[uid,invites[0].recipient_uid,invites[0].room_id]);
        more();
      }
      const peers=await query("select item from halabessa.account_deletion_inventory where job_id=$1::uuid and kind='peer' and not processed order by item limit 5",[id]);
      if(peers.length) {
        for(const row of peers) {
          await realtime.removePeerSocialEdges(uid,String(row.item));
          await processed('peer',String(row.item));
        }
        more();
      }
      const messages=await query("select item from halabessa.account_deletion_inventory where job_id=$1::uuid and kind='room' and not processed order by item limit 5",[id]);
      for(const row of messages) {
        const roomId=String(row.item);
        // Unsupported RTDB-only historical matches require safe reconciliation;
        // never destroy a live peer's match or pretend its data was removed.
        if(await realtime.legacyRoomReferences(uid,roomId))throw new Error('legacy_deletion_room_requires_review');
        if(await realtime.removeRoomMessages(uid,roomId))await processed('room',roomId);
        // Bound normal work without hundreds of minute-long scheduler passes.
        // A slow/failed upstream request still leaves all unfinished work pending.
        if(Date.now()-started>=10000)break;
      }
      if(messages.length)more();
    },
    async removeProfileAndReservations(uid) {
      await firestore.removeProfileAndReservations(uid);
      await realtime.removeOwnProfileAndPresence(uid);
      // FK cascades remove owned social edges, invites, hands and commands.
      // rooms.owner_uid has already been safely transferred in the prior stage.
      await query('delete from halabessa.user_profiles where firebase_uid=$1',[uid]);
    },
    async removeAvatarObjects(uid) {
      // Drain uploads already admitted before acceptance. Their transport has a
      // 12s bound; don't let a late upload recreate an object after cleanup.
      const rows=await query('select extract(epoch from now()-created_at)::text as age from halabessa.account_deletion_jobs where id=$1::uuid',[id]);
      if(Number(rows[0]?.age)<120)more();
      await avatars.remove(uid);
    },
    async deleteIdentity(uid) {
      await identity.deleteIdentity(uid);
      // Inventory itself contains peers' IDs: discard it once no retry needs it.
      await query('delete from halabessa.account_deletion_inventory where job_id=$1::uuid',[id]);
      await query('delete from halabessa.account_deletion_rooms where job_id=$1::uuid',[id]);
    },
  };
  return continueDeletion(store,id,effects,1);
}
