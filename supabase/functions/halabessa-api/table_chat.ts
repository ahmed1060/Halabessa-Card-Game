import type { MirrorRequest } from './mirror_fencing.ts';
import { assertActiveIdentity, type FirebaseIdentity } from './firebase_identity.ts';

export function quickChatSuperadmin(account: FirebaseIdentity | null, authTime: unknown, email: string) {
  assertActiveIdentity(account, authTime);
  return account?.email?.toLowerCase() === email.toLowerCase();
}

type Row = Record<string, unknown>;
const object = (value: unknown): Row => value && typeof value === 'object' && !Array.isArray(value)
  ? value as Row : {};
export type QuickPhrase = { id: string; en: string; ar: string };
export type PhraseConfig = { revision: number; items: QuickPhrase[] };
export const defaultPhrases: QuickPhrase[] = [
  {id: 'gg', en: 'GG!', ar: 'ماتش حلو!'},
  {id: 'nice_play', en: 'Nice play!', ar: 'لعبة حلوة!'},
  {id: 'your_turn', en: 'Your turn', ar: 'دورك'},
  {id: 'halabessa', en: 'Halabessa!', ar: 'حلبسة!'},
  {id: 'oops', en: 'Oops!', ar: 'يا نهار!'},
];
export function chatText(value: unknown) {
  if (typeof value !== 'string' || !value.trim() || value.trim().length > 60 ||
      /[\u0000-\u001f\u007f]/.test(value)) throw Error('invalid_chat_message');
  return value.trim();
}
export function phraseId(value: unknown): string {
  if (typeof value !== 'string' || !/^[a-zA-Z0-9_-]{1,64}$/.test(value)) throw Error('invalid_chat_phrase');
  return value;
}
export function phraseConfig(value: unknown): PhraseConfig {
  if (value == null) return {revision: 0, items: defaultPhrases.map(p => ({...p}))};
  const row = object(value);
  // Firebase represents a stored empty array as an absent child.
  const items = row.items == null ? [] : row.items;
  if (!Number.isSafeInteger(row.revision) || Number(row.revision) < 0 ||
      !Array.isArray(items) || items.length > 32) throw Error('chat_unavailable');
  const parsed = items.map(value => {
    const item = object(value);
    return {id: phraseId(item.id), en: chatText(item.en), ar: chatText(item.ar)};
  });
  if (new Set(parsed.map(item => item.id)).size !== parsed.length) throw Error('chat_unavailable');
  return {revision: Number(row.revision), items: parsed};
}
export function roomChatPolicy(state: Row, uid: string,
  friendships: {owner_uid: string; friend_uid: string}[]) {
  const players = Array.isArray(state.playerIds) ? state.playerIds : [];
  if (!players.includes(uid) || uid.startsWith('bot_') || uid.startsWith('waiting_') ||
      state.roomClosed === true || state.phase === 'closed') throw Error('not_room_participant');
  if (state.protocolVersion !== 1) throw Error('chat_unavailable');
  const humans = players.filter((id): id is string => typeof id === 'string' &&
    !id.startsWith('bot_') && !id.startsWith('waiting_'));
  const edges = new Set(friendships.map(row => JSON.stringify([row.owner_uid, row.friend_uid])));
  const canType = humans.length >= 2 && humans.every(a => humans.every(b => a === b ||
    edges.has(JSON.stringify([a, b]))));
  return {canType, humanCount: humans.length};
}
export async function readQuickPhrases(request: MirrorRequest): Promise<PhraseConfig> {
  const read = await request('quickChatPresets');
  if (read.status !== 200) throw Error('chat_unavailable');
  return phraseConfig(read.data);
}
export async function updateQuickPhrase(request: MirrorRequest, body: Row) {
  const read = await request('quickChatPresets');
  if (read.status !== 200 || !read.etag) throw Error('chat_unavailable');
  const current = phraseConfig(read.data);
  if (body.revision !== current.revision) throw Error('chat_config_conflict');
  const id = phraseId(body.presetId);
  let items = current.items;
  const found = items.findIndex(item => item.id === id);
  if (body.operation === 'delete') {
    if (found < 0) throw Error('invalid_chat_phrase');
    items = items.filter(item => item.id !== id);
  } else if (body.operation === 'save') {
    const phrase = object(body.phrase);
    const next = {id, en: chatText(phrase.en), ar: chatText(phrase.ar)};
    items = found < 0 ? [...items, next] : items.map(item => item.id === id ? next : item);
    if (items.length > 32) throw Error('chat_phrase_limit');
  } else throw Error('invalid_chat_phrase');
  const next = {revision: current.revision + 1, items};
  const write = await request('quickChatPresets', 'PUT', next, read.etag);
  if (write.status === 412) throw Error('chat_config_conflict');
  if (write.status !== 200) throw Error('chat_unavailable');
  return next;
}
export function canonicalChatMessage(body: Row, actor: {uid: string; name: string},
  canType: boolean, config: PhraseConfig, now: number) {
  const id = phraseId(body.messageId);
  if (body.channel !== undefined && body.channel !== 'public') throw Error('invalid_chat_channel');
  const quick = body.presetId !== undefined;
  let text: string;
  if (quick) {
    if (body.locale !== 'en' && body.locale !== 'ar') throw Error('invalid_chat_phrase');
    const phrase = config.items.find(item => item.id === body.presetId);
    if (!phrase) throw Error('invalid_chat_phrase');
    text = phrase[body.locale];
  } else {
    if (!canType) throw Error('chat_typing_locked');
    text = chatText(body.text);
  }
  return {id, senderId: actor.uid, senderName: actor.name.slice(0, 80), text,
    timestamp: now, isQuickChat: quick, ...(quick ? {presetId: body.presetId} : {})};
}
/** One existing RTDB subtree CAS atomically accepts the message and rate stamp.
 * Historical public and team data are retained; team reads/writes are disabled
 * by rules. Transport ambiguity is retried only with the same message ID.
 */
export async function publishRoomChat(request: MirrorRequest, roomId: string,
  message: ReturnType<typeof canonicalChatMessage>) {
  const path = `matchChat/${roomId}`;
  for (let attempt = 0; attempt < 3; attempt++) {
    const read = await request(path);
    if (read.status !== 200 || !read.etag) throw Error('chat_unavailable');
    const current = object(read.data), messages = object(current.public), rate = object(current.rate);
    const prior = object(messages[message.id]);
    if (prior.id) {
      if (prior.senderId !== message.senderId || prior.text !== message.text ||
          prior.isQuickChat !== message.isQuickChat || prior.presetId !== message.presetId) throw Error('chat_message_conflict');
      return {ok: true, message: prior};
    }
    if (typeof rate[message.senderId] === 'number' &&
        message.timestamp - Number(rate[message.senderId]) < 1000) throw Error('chat_rate_limited');
    const next = {...current, public: {...messages, [message.id]: message},
      rate: {...rate, [message.senderId]: message.timestamp}};
    const write = await request(path, 'PUT', next, read.etag);
    if (write.status === 412) continue;
    if (write.status !== 200) throw Error('chat_unavailable');
    return {ok: true, message};
  }
  throw Error('chat_message_conflict');
}
