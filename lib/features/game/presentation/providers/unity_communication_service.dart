import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:halabessa/core/utils/web_utils.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_unity_widget/flutter_unity_widget.dart';
import '../../domain/models/match_state.dart';
import '../../domain/providers/game_providers.dart';
import 'package:halabessa/features/auth/presentation/providers/auth_providers.dart';
import 'package:halabessa/core/providers/settings_provider.dart';
import 'package:halabessa/features/game/presentation/providers/unity_layer_provider.dart';
import 'unity_startup_state.dart';
import 'unity_visual_presentation.dart';
import 'card_feedback.dart';
import 'visual_action_queue.dart';

final unityCommunicationServiceProvider = Provider((ref) {
  final service = UnityCommunicationService(ref)..init();
  ref.onDispose(service.dispose);
  return service;
});
// Optional rebuilt-renderer capability; old exports never enable new gestures.
final unityCardInteractionsReadyProvider = StateProvider<bool>((ref) => false);
const _cardInteractionsPreview = bool.fromEnvironment(
  'HALABESSA_CARD_INTERACTIONS',
);
// Explicit local QA only. Never log card/room/player identity or hand payloads.
const _visualTrace = bool.fromEnvironment('HALABESSA_VISUAL_TRACE');

class UnityCommunicationService {
  final Ref _ref;
  UnityWidgetController? _controller;
  final ValueNotifier<bool> isReady = ValueNotifier<bool>(false);
  final UnityStartupState _startup = UnityStartupState();
  Timer? _startupTimer;
  StreamSubscription<dynamic>? _webMessages;
  late final _visual = UnityVisualPresentation(
    send: (message) {
      if (_visualTrace) {
        debugPrint(
          'Visual QA TX ${message['type']} ${message['kind'] ?? ''} '
          'generation=${message['generation']} instant=${message['instant']}',
        );
      }
      postMessage(
        'UnityBridge',
        'OnFlutterMessage',
        jsonEncode({...message, if (_visualTrace) 'trace': true}),
      );
    },
    onContact: (id, slam) =>
        _ref.read(cardFeedbackProvider).contact(id, slam: slam),
    onGestureContact: (id) => _ref.read(cardFeedbackProvider).gestureSlam(id),
    onRecoverableTimeout: () => debugPrint(
      'Unity visual ACK timed out: resynced current cards; later effects remain enabled.',
    ),
  );
  bool get supportsVisualActions => _visual.capable;
  void updateHandSelection(String cardId, bool queued, bool slam) {
    _visual.updateHandSelection(cardId, queued, slam);
  }

  bool _platformReduced = false;
  bool _disposed = false;
  bool _visualForeground = true;
  MatchState? _lastVisualState;
  MatchState? _pendingVisualState;
  bool _visualSyncScheduled = false;
  final _handPoses = <String, String>{};
  void updateHandPose(
    String cardId,
    bool peek,
    double dragFraction,
    double velocity,
  ) {
    if (!_visualForeground ||
        !_visual.capable ||
        !_ref.read(unityLayerActiveProvider)) {
      return;
    }
    final message = jsonEncode({
      'type': 'HAND_POSE',
      'generation': _visual.generation,
      'cardId': cardId,
      'peek': peek,
      'dragFraction': dragFraction,
      'velocity': velocity,
    });
    if (_handPoses[cardId] == message) return;
    if (_handPoses.length > 8) _handPoses.clear();
    _handPoses[cardId] = message;
    postMessage('UnityBridge', 'OnFlutterMessage', message);
  }

  void updateVisualAnchors(
    List<Map<String, dynamic>> anchors, {
    bool reducedMotion = false,
  }) {
    _visual.updateAnchors(anchors, reconcile: _pendingVisualState == null);
    _platformReduced = reducedMotion;
  }

  void clearVisuals() {
    _lastVisualState = null;
    _pendingVisualState = null;
    _visual.clear();
  }

  void resyncVisuals() {
    _handPoses.clear();
    _visual.resync();
  }

  /// Cancel presentation on focus loss; never pause the accepted match state.
  /// Hidden tabs can consume state without frames, and resume catches up once
  /// layout has supplied fresh anchors instead of replaying missed effects.
  void setVisualForeground(bool foreground) {
    if (_disposed || foreground == _visualForeground) return;
    _visualForeground = foreground;
    _handPoses.clear();
    final state = _pendingVisualState ?? _lastVisualState;
    _pendingVisualState = null;
    if (state == null) {
      _visual.resync();
    } else if (foreground) {
      syncState(state);
    } else {
      _acceptVisualState(state);
    }
  }

  void _acceptVisualState(MatchState state) {
    final settings = _ref.read(settingsProvider);
    _visual.accept(
      state,
      _ref.read(currentUserProvider)?.uid,
      active:
          _visualForeground &&
          isReady.value &&
          _ref.read(unityLayerActiveProvider),
      reduced: settings.reducedMotion || _platformReduced,
      interactions: _cardInteractionsPreview && state.id.startsWith('OFFLINE_'),
    );
  }

  UnityCommunicationService(this._ref);

  void init() {
    _startupTimer = Timer(const Duration(seconds: 30), () {
      if (!isReady.value) _fallbackTo2D();
    });
    if (kIsWeb) {
      _webMessages = WebUtils.onMessage?.listen((event) {
        try {
          // Unity's WebGL callbacks and Flutter's outbound bridge messages
          // are posted by this document. Ignore messages injected by a
          // foreign window before decoding an event that can trigger gameplay.
          if (event.origin != WebUtils.window.location.origin ||
              event.source != WebUtils.window) {
            return;
          }
          final message = event.data;
          if (message is String) {
            final data = jsonDecode(message);

            // Ignore echoes (messages from Flutter to Unity)
            if (data is Map && data.containsKey('objectName')) return;

            handleUnityMessage(message);
          }
        } catch (e) {
          // Non-JSON message or error
        }
      });
    }
  }

  void setController(UnityWidgetController controller) {
    _controller = controller;
  }

  void _fallbackTo2D() {
    _ref.read(unityCardInteractionsReadyProvider.notifier).state = false;
    _startup.handleEvent('UNITY_FAILED');
    _visual.clear();
    _startupTimer?.cancel();
    isReady.value = false;
    _ref.read(unityInitializedProvider.notifier).state = false;
    _ref.read(unityFailedProvider.notifier).state = true;
    _ref.read(unityLayerVisibilityProvider.notifier).state = false;
  }

  void dispose() {
    _disposed = true;
    _lastVisualState = null;
    _pendingVisualState = null;
    _startupTimer?.cancel();
    _webMessages?.cancel();
    _visual.dispose();
    isReady.dispose();
  }

  void postMessage(String objectName, String methodName, String message) {
    if (!kIsWeb && _controller == null) {
      // Unity controller not attached; silently ignore in 2D mode
      return;
    }
    try {
      if (kIsWeb) {
        // Flutter and WebGL share this document; do not broadcast bridge
        // messages to arbitrary embedded origins.
        final data = jsonEncode({
          'objectName': objectName,
          'methodName': methodName,
          'message': message,
        });
        WebUtils.postMessage(data, Uri.base.origin);
      } else {
        // For Native: Use the controller safely
        _controller?.postMessage(objectName, methodName, message);
      }
    } catch (e) {
      debugPrint(
        "UnityCommunicationService: Failed to postMessage ($methodName): $e",
      );
    }
  }

  void syncState(MatchState state) {
    if (cardJuiceEnabled) {
      _lastVisualState = state;
      if (!_visualForeground) {
        _pendingVisualState = null;
        _acceptVisualState(state);
        return;
      }
      // Accepted state is immediate; only its visual handoff waits for layout.
      // Flush after ALL post-frame anchors, not before the new fan is measured.
      _pendingVisualState = state;
      if (_visualSyncScheduled || _disposed) return;
      _visualSyncScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        scheduleMicrotask(() {
          _visualSyncScheduled = false;
          final next = _pendingVisualState;
          _pendingVisualState = null;
          if (_disposed || next == null) return;
          _acceptVisualState(next);
        });
      });
      WidgetsBinding.instance.ensureVisualUpdate();
      return;
    }
    final currentUserUid = _ref.read(currentUserProvider)?.uid;
    final handCards = currentUserUid != null
        ? (state.handCards[currentUserUid] ?? [])
        : [];

    final message = {
      'type': 'SYNC_STATE',
      'board': state.board.map((c) => c.toJson()).toList(),
      'handCards': handCards.map((c) => c.toJson()).toList(),
      'phase': state.phase.name,
      'turnIndex': state.currentTurnIndex,
    };
    postMessage('UnityBridge', 'OnFlutterMessage', jsonEncode(message));
  }

  void playCard(String cardId, Map<String, double> position) {
    final message = {
      'type': 'PLAY_CARD',
      'cardId': cardId,
      'x': position['x'],
      'y': position['y'],
    };
    postMessage('UnityBridge', 'OnFlutterMessage', jsonEncode(message));
  }

  void updateSkins(String skinId) {
    postMessage(
      'UnityBridge',
      'OnFlutterMessage',
      jsonEncode({'type': 'UPDATE_SKINS', 'skinId': skinId}),
    );
  }

  void startTimer(int durationSeconds) {
    postMessage(
      'UnityBridge',
      'OnFlutterMessage',
      jsonEncode({
        'type': 'START_TIMER',
        'duration': durationSeconds.toDouble(),
      }),
    );
  }

  void setMode(String mode) {
    postMessage(
      'UnityBridge',
      'OnFlutterMessage',
      jsonEncode({'type': 'SET_MODE', 'mode': mode}),
    );
  }

  void handleUnityMessage(String message) {
    try {
      final data = jsonDecode(message);
      if (data is! Map) return;

      final event = data['event'];
      if (_visualTrace &&
          (event == 'VISUAL_ACTION_COMPLETE' ||
              event == 'VISUAL_CONTACT' ||
              event == 'UNITY_VISUAL_READY' ||
              event == 'UNITY_CARD_FEEL_READY')) {
        debugPrint(
          'Visual QA RX $event generation=${data['generation']} '
          'typed=${data['generation'] is int} identified=${data['eventId'] is String}',
        );
      }
      if (event == 'UNITY_FAILED') {
        _fallbackTo2D();
        return;
      }
      if (event == 'UNITY_READY') {
        if (!_startup.handleEvent('UNITY_READY') || isReady.value) return;
        _startupTimer?.cancel();
        isReady.value = true;
        _ref.read(unityInitializedProvider.notifier).state = true;
        final match = _ref.read(matchStateProvider);
        if (match != null) {
          syncState(match);
          setMode(match.mode.name);
        }
        return;
      }
      if (!isReady.value || _startup.hasFailed) return;
      final settings = _ref.read(settingsProvider);
      if (event == 'UNITY_VISUAL_READY') {
        _ref.read(unityCardInteractionsReadyProvider.notifier).state = false;
        _visual.negotiate(data['data'] == '1' ? 1 : 0);
        final state = _ref.read(matchStateProvider);
        if (state != null) syncState(state);
        return;
      }
      if (event == 'UNITY_CARD_FEEL_READY' && data['data'] == '1') {
        _visual.negotiate(1, interactions: true);
        _ref.read(unityCardInteractionsReadyProvider.notifier).state = true;
        final state = _ref.read(matchStateProvider);
        if (state != null) syncState(state);
        return;
      }
      if (event == 'VISUAL_CONTACT' || event == 'VISUAL_ACTION_COMPLETE') {
        final id = data['eventId'], generation = data['generation'];
        if (id is String && generation is int) {
          if (event == 'VISUAL_CONTACT') {
            _visual.contact(id, generation);
          } else {
            _visual.acknowledge(id, generation);
          }
        }
        return;
      }
      if (event == 'VISUAL_PICK') {
        if (_ref.read(unityLayerActiveProvider)) {
          _ref.read(cardFeedbackProvider).pick();
        }
        return;
      }

      if (event == 'BASRA_EVENT') {
        if (settings.isHapticsEnabled && !supportsVisualActions) {
          HapticFeedback.heavyImpact();
        }
      } else if (event == 'PLAY_CARD') {
        final cardId = data['data'];
        if (cardId is! String) return;

        final matchState = _ref.read(matchStateProvider);
        if (matchState != null) {
          final currentUserUid = _ref.read(currentUserProvider)?.uid;
          if (currentUserUid != null) {
            final hand = matchState.handCards[currentUserUid] ?? [];
            try {
              final card = hand.firstWhere(
                (c) => '${c.suit.name}_${c.rank.name}' == cardId,
                orElse: () => hand.firstWhere((c) => c.firebaseKey == cardId),
              );
              final generation = _visual.generation;
              unawaited(
                _ref
                    .read(matchStateProvider.notifier)
                    .playCard(currentUserUid, card)
                    .then<void>((accepted) {
                      if (accepted || _disposed || !supportsVisualActions) {
                        return;
                      }
                      final current = _ref.read(matchStateProvider);
                      if (current?.id != matchState.id ||
                          current?.matchSequence != matchState.matchSequence ||
                          current?.roundCount != matchState.roundCount ||
                          _ref.read(currentUserProvider)?.uid !=
                              currentUserUid) {
                        return;
                      }
                      if (_visual.reject(card.firebaseKey, generation)) {
                        _ref.read(cardFeedbackProvider).reject();
                      }
                    })
                    .catchError((Object error) {
                      // Ambiguous transport failure stays with existing recovery.
                    }),
              );
              if (settings.isHapticsEnabled && !supportsVisualActions) {
                HapticFeedback.mediumImpact();
              }
            } catch (e) {
              debugPrint("Card $cardId not found in hand.");
            }
          }
        }
      } else if (event == 'ANIMATION_COMPLETE') {
        // Handle sync
      }
    } catch (e) {
      debugPrint("Error decoding Unity message: $e");
    }
  }
}
