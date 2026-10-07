import test from 'node:test';
import assert from 'node:assert/strict';
import {assertAvatarUpload} from '../../supabase/functions/halabessa-api/avatar_upload_policy.ts';
test('avatars allow exactly supported image types and unambiguous verified UID paths',()=>{
  for (const type of ['image/jpeg','image/png','image/webp']) assert.doesNotThrow(()=>assertAvatarUpload('avatar',type,'alice_123-valid'));
  for (const type of ['audio/mpeg','audio/wav','audio/mp4','image/svg+xml','text/html',null]) assert.throws(()=>assertAvatarUpload('avatar',type,'alice'),/invalid_asset/);
  for (const uid of ['alice:123','../bob','a'.repeat(81),'']) assert.throws(()=>assertAvatarUpload('avatar','image/png',uid),/invalid_asset/);
  assert.doesNotThrow(()=>assertAvatarUpload('music','audio/mpeg','admin'));
});
