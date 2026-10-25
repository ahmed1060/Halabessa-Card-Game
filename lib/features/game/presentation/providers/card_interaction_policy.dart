import '../../domain/models/match_state.dart';

// Explicit release controls. Native builds keep their existing defaults.
const cardInteractionsEnabled = bool.fromEnvironment(
  'HALABESSA_CARD_INTERACTIONS',
);
const onlineCardInteractionsEnabled = bool.fromEnvironment(
  'HALABESSA_ONLINE_CARD_INTERACTIONS',
);

/// Practice uses its existing local validator; online requires server authority.
/// Never enable special commands in a legacy client-managed online room.
bool cardInteractionsFor(
  MatchState state, {
  bool enabled = cardInteractionsEnabled,
  bool onlineEnabled = onlineCardInteractionsEnabled,
}) =>
    enabled &&
    !state.roomClosed &&
    (state.id.startsWith('OFFLINE_') ||
        (onlineEnabled && state.usesServerCommands));

bool cardInteractionInputFor(
  MatchState state, {
  required bool spectator,
  required bool unityHand,
  bool unityInteractionsReady = false,
  bool unityRefinementsReady = false,
  bool visualActionsReady = false,
  required bool refinedHand,
  bool enabled = cardInteractionsEnabled,
  bool onlineEnabled = onlineCardInteractionsEnabled,
}) =>
    cardInteractionsFor(
      state,
      enabled: enabled,
      onlineEnabled: onlineEnabled,
    ) &&
    !spectator &&
    (!unityHand ||
        (unityInteractionsReady &&
            (!refinedHand || unityRefinementsReady) &&
            visualActionsReady));
