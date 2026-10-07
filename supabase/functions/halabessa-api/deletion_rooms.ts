import type {DeletionQuery} from './deletion_job_store.ts';
import type {MatchState, Card} from './match_engine.ts';
import {anonymizeDeletedPlayer, roomReferencesDeletedPlayer} from './deletion_room_state.ts';
import {publicMatchState, type CommittedRoom} from './match_delivery.ts';

/** Runs on the SAME connection as the active deletion-job transaction. Changes
 * and an outbox entry commit together; only a later pass publishes the latest
 * committed state under its room lock. Never mirror an uncommitted mutation.
 */
export function createDeletionRoomStore(query: DeletionQuery, assertLease: (id: string) => void,
  settle: (state: MatchState, createdAt: string) => Promise<string>,
  publish: (id: string, room: CommittedRoom) => Promise<void>) {
  const uuid=/^[a-f0-9]{8}-[a-f0-9]{4}-[1-8][a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$/i;
  function room(row: Record<string,unknown>) {
    if (typeof row.room_id !== 'string' || !/^[A-Z]{3}[0-9]{5}$/.test(row.room_id) ||
        !row.state || typeof row.state !== 'object' || Array.isArray(row.state) ||
        !Number.isSafeInteger(Number(row.version)) || Number(row.version)<0) throw new Error('invalid_deletion_room');
    return {id:row.room_id,state:structuredClone(row.state) as MatchState,version:Number(row.version)};
  }
  async function secrets(id: string) {
    const rows=await query('select hands from halabessa.room_secrets where room_id=$1 for update',[id]);
    if (!rows[0]?.hands || typeof rows[0].hands !== 'object' || Array.isArray(rows[0].hands)) {
      throw new Error('missing_deletion_room_secrets');
    }
    return structuredClone(rows[0].hands) as Record<string,Card[]>;
  }
  return {
    // true means the scan/outbox is drained, false means persist progress and
    // run another bounded pass. Caller must keep the stage pending on false.
    async advance(jobId: string,uid: string): Promise<boolean> {
      assertLease(jobId);
      if (!uuid.test(jobId) || !/^[A-Za-z0-9:_-]{1,128}$/.test(uid)) throw new Error('invalid_deletion_job');
      const jobs=await query('select firebase_uid,completed_stages,status from halabessa.account_deletion_jobs where id=$1::uuid',[jobId]);
      if (jobs[0]?.firebase_uid !== uid || jobs[0]?.status !== 'pending' ||
          !Array.isArray(jobs[0]?.completed_stages) || jobs[0].completed_stages[0] !== 'blockSessions') {
        throw new Error('deletion_sessions_not_blocked');
      }
      const pending=await query('select room_id from halabessa.account_deletion_rooms where job_id=$1::uuid and not published order by room_id limit 1',[jobId]);
      if (pending[0]) {
        const id=pending[0].room_id;
        const rows=await query('select room_id,state,version::text from halabessa.rooms where room_id=$1 for update',[id]);
        if (rows[0]) {
          const latest=room(rows[0]),hands=await secrets(latest.id);
          if (roomReferencesDeletedPlayer({...latest.state,handCards:hands},uid)) {
            // Another writer reintroduced an identity: never publish or advance
            // cleanup from a stale prepared snapshot.
            throw new Error('deletion_room_identity_reintroduced');
          }
          await publish(latest.id,{state:latest.state,version:latest.version,hands});
        }
        // A normally expired/deleted SQL room is not permission to erase a
        // possibly newer RTDB room with the same short ID. No blind root delete.
        await query('update halabessa.account_deletion_rooms set published=true where job_id=$1::uuid and room_id=$2',[jobId,id]);
        return false;
      }
      const candidates=await query(`select r.room_id,r.owner_uid,r.state,r.version::text,
          extract(epoch from r.created_at)::text as created_at
        from halabessa.rooms r left join halabessa.room_secrets s on s.room_id=r.room_id
        where (r.owner_uid=$2 or strpos(r.state::text,$2)>0 or s.hands ? $2
          or exists(select 1 from halabessa.room_commands c where c.room_id=r.room_id
            and (c.actor_uid=$2 or strpos(c.result::text,$2)>0)))
          and not exists(select 1 from halabessa.account_deletion_rooms d where d.job_id=$1::uuid and d.room_id=r.room_id)
        order by r.room_id limit 1 for update of r`,[jobId,uid]);
      if (!candidates[0]) return true;
      const candidate=candidates[0],current=room(candidate),hands=await secrets(current.id);
      const full:MatchState={...current.state,handCards:hands};
      if (candidate.owner_uid !== uid && !roomReferencesDeletedPlayer(full,uid)) {
        // Coarse SQL scan also finds a peer whose name happens to equal uid.
        // Record the false positive without editing cards, identities or scores.
        // A peer command can still have an OLD snapshot after the current state
        // no longer contains uid. Remove redundant cached snapshots too.
        await query("update halabessa.room_commands set result=result-'state'-'hand' where room_id=$1 and actor_uid<>$2",[current.id,uid]);
        await query('insert into halabessa.account_deletion_rooms(job_id,room_id,published) values($1::uuid,$2,true)',[jobId,current.id]);
        return false;
      }
      if (full.protocolVersion !== 1) throw new Error('unsupported_deletion_room');
      if (full.settlementPending === true) {
        const receipt=await settle(full,String(candidate.created_at));
        if (!/^[a-f0-9]{64}$/.test(receipt)) throw new Error('invalid_deletion_reward_receipt');
        full.settlementPending=false;full.rewardReceiptId=receipt;
      }
      const anonymous=`bot_deleted_${jobId.replaceAll('-','').toLowerCase()}`;
      const next=anonymizeDeletedPlayer(full,uid,anonymous),version=current.version+1;
      let owner=candidate.owner_uid;
      if (owner === uid) {
        const humans=(next.playerIds??[]).filter(id=>!id.startsWith('bot_') && !id.startsWith('waiting_') && id!==uid);
        const owners=await query(`select p.firebase_uid from halabessa.user_profiles p
          where p.firebase_uid=any($1::text[]) and not exists(select 1 from halabessa.account_deletion_jobs d where d.firebase_uid=p.firebase_uid)
          order by array_position($1::text[],p.firebase_uid) limit 1`,[humans]);
        owner=owners[0]?.firebase_uid ?? anonymous;
        if (owner===anonymous) {
          await query(`insert into halabessa.user_profiles(firebase_uid,display_name,profile)
            values($1,'Deleted player','{"systemDeletionOwner":true}'::jsonb) on conflict do nothing`,[anonymous]);
          const stub=await query('select profile,email from halabessa.user_profiles where firebase_uid=$1',[anonymous]);
          if (stub[0]?.email!==null || (stub[0]?.profile as any)?.systemDeletionOwner!==true) throw new Error('deletion_owner_conflict');
        }
      }
      await query('update halabessa.rooms set owner_uid=$2,state=$3::jsonb,version=$4,updated_at=now() where room_id=$1',
        [current.id,owner,JSON.stringify(publicMatchState(next,version)),version]);
      await query('update halabessa.room_secrets set hands=$2::jsonb where room_id=$1',[current.id,JSON.stringify(next.handCards??{})]);
      // Keep peers' command IDs/versions/payloads for duplicate prevention, but
      // remove cached state/private-hand snapshots containing the deleted user.
      // Current participant snapshots are reconstructed by the command endpoint.
      await query("update halabessa.room_commands set result=result-'state'-'hand' where room_id=$1 and actor_uid<>$2",[current.id,uid]);
      await query('insert into halabessa.account_deletion_rooms(job_id,room_id,published) values($1::uuid,$2,false)',[jobId,current.id]);
      return false;
    },
  };
}
