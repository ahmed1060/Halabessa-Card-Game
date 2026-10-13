import type { CommittedRoom } from './match_delivery.ts';
import type { PublicationRunner } from './room_publication.ts';

/** Preserve settled rewards, then fence every public/private mirror. The normal
 * detached runner releases its socket before external work; a compatible
 * publisher may supply its existing transaction rather than nesting a pool
 * admission. Both external operations are idempotent and retryable. */
export async function deliverClosedRoom(run: PublicationRunner, id: string, room: CommittedRoom,
  settle: (state: CommittedRoom['state'], createdAt: string) => Promise<string>,
  erase: () => Promise<void>) {
  if (!/^[A-Z]{3}[0-9]{5}$/.test(id)) throw Error('invalid_room_id');
  if (room.state.roomClosed !== true) throw Error('room_not_closed');
  if (room.state.settlementPending === true) {
    const rows = await run(query => query(`select extract(epoch from created_at)::text as created_at
      from halabessa.rooms where room_id=$1 and state->>'roomClosed'='true'`, [id]));
    if (!rows[0]) return; // Another successful publisher already purged it.
    const receipt = await settle(room.state, String(rows[0].created_at));
    await run(query => query(`update halabessa.rooms set
      state=jsonb_set(jsonb_set(state,'{settlementPending}','false'::jsonb),'{rewardReceiptId}',to_jsonb($3::text)),
      version=version+1,updated_at=now()
      where room_id=$1 and version=$2 and state->>'roomClosed'='true'
        and state->>'settlementPending'='true'`, [id, room.version, receipt]));
    // The higher version queues another publication, which can purge SQL only
    // after observing settlementPending=false. A failed mirror keeps its intent.
  }
  await erase();
}
