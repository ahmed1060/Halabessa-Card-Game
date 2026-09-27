import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:halabessa/core/utils/web_utils.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_unity_widget/flutter_unity_widget.dart';
import '../../domain/models/match_state.dart';
import '../../domain/providers/game_providers.dart';
import 'package:halabessa/features/auth/presentation/providers/auth_providers.dart';
import 'package:halabessa/core/providers/settings_provider.dart';
import 'package:halabessa/features/game/presentation/providers/unity_layer_provider.dart';
import 'unity_startup_state.dart';

final unityCommunicationServiceProvider = Provider((ref) {
  final service = UnityCommunicationService(ref)..init();
  ref.onDispose(service.dispose);
  return service;
});

class UnityCommunicationService {
  final Ref _ref;
  UnityWidgetController? _controller;
  final ValueNotifier<bool> isReady = ValueNotifier<bool>(false);
  final UnityStartupState _startup = UnityStartupState();
  Timer? _startupTimer;
  StreamSubscription<dynamic>? _webMessages;

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
          if (event.origin != WebUtils.window.location.origin || event.source != WebUtils.window) {
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
    _startup.handleEvent('UNITY_FAILED');
    _startupTimer?.cancel();
    isReady.value = false;
    _ref.read(unityInitializedProvider.notifier).state = false;
    _ref.read(unityFailedProvider.notifier).state = true;
    _ref.read(unityLayerVisibilityProvider.notifier).state = false;
  }

  void dispose() {
    _startupTimer?.cancel();
    _webMessages?.cancel();
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
      debugPrint("UnityCommunicationService: Failed to postMessage ($methodName): $e");
    }
  }


  void syncState(MatchState state) {
    final currentUserUid = _ref.read(currentUserProvider)?.uid;
    final handCards = currentUserUid != null ? (state.handCards[currentUserUid] ?? []) : [];
    
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
    postMessage('UnityBridge', 'OnFlutterMessage', jsonEncode({
      'type': 'UPDATE_SKINS',
      'skinId': skinId,
    }));
  }

  void startTimer(int durationSeconds) {
    postMessage('UnityBridge', 'OnFlutterMessage', jsonEncode({
      'type': 'START_TIMER',
      'duration': durationSeconds.toDouble(),
    }));
  }

  void setMode(String mode) {
    postMessage('UnityBridge', 'OnFlutterMessage', jsonEncode({
      'type': 'SET_MODE',
      'mode': mode,
    }));
  }

  void handleUnityMessage(String message) {
    try {
      final data = jsonDecode(message);
      if (data is! Map) return;

      final event = data['event'];
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

      if (event == 'BASRA_EVENT') {
        if (settings.isHapticsEnabled) HapticFeedback.heavyImpact();
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
                (c) => c.suit.name + "_" + c.rank.name == cardId, 
                orElse: () => hand.firstWhere((c) => c.firebaseKey == cardId)
              );
              _ref.read(matchStateProvider.notifier).playCard(currentUserUid, card);
              if (settings.isHapticsEnabled) HapticFeedback.mediumImpact();
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
