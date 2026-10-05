/// Applies only when creating a new online room. Existing rooms always keep
/// their saved protocol; offline training does not use this policy.
/// An emergency rebuild can opt out with HALABESSA_SERVER_MATCHES=false.
const serverControlledRoomCreation = bool.fromEnvironment(
  'HALABESSA_SERVER_MATCHES',
  defaultValue: true,
);

int get newOnlineRoomProtocol => serverControlledRoomCreation ? 1 : 0;
