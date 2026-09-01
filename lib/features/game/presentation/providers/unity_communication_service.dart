import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:halabessa/core/utils/web_utils.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_unity_widget/flutter_unity_widget.dart';
import '../../domain/models/match_state.dart';
import '../../domain/providers/game_providers.dart';
import 'package:halabessa/features/auth/presentation/providers/auth_providers.dart';
import 'package:halabessa/core/providers/settings_provider.dart';

final unityCommunicationServiceProvider = Provider((ref) => UnityCommunicationService(ref)..init());

class UnityCommunicationService {
  final Ref _ref;
  UnityWidgetController? _controller;
  final ValueNotifier<bool> isReady = ValueNotifier<bool>(false);

  UnityCommunicationService(this._ref);

  void init() {
    if (kIsWeb) {
      // Graceful fallback: If Unity WebGL does not report ready within 3.5s, unlock UI
      Future.delayed(const Duration(milliseconds: 3500), () {
        if (!isReady.value) {
          debugPrint("Unity WebGL startup timeout - enabling UI.");
          _ref.read(unityInitializedProvider.notifier).state = true;
        }
      });

      WebUtils.onMessage?.listen((event) {
        try {
          final message = event.data;
          if (message is String) {
            final data = jsonDecode(message);
            
            // Ignore echoes (messages from Flutter to Unity)
            if (data is Map && data.containsKey('objectName')) return;
            
            if (data['event'] == 'UNITY_READY') {
              isReady.value = true;
              _ref.read(unityInitializedProvider.notifier).state = true;
              // Initial sync after Unity WebGL is loaded
              final matchState = _ref.read(matchStateProvider);
              if (matchState != null) {
                syncState(matchState);
                setMode(matchState.mode.name);
              }
            } else {
              handleUnityMessage(message);
            }
          }
        } catch (e) {
          // Non-JSON message or error
        }
      });
    }
  }

  void setController(UnityWidgetController controller) {
    _controller = controller;
    // Fallback for native
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (!isReady.value) {
        _ref.read(unityInitializedProvider.notifier).state = true;
      }
    });
  }

  void postMessage(String objectName, String methodName, String message) {
    if (kIsWeb) {
      // For WebGL: Dispatch to the IFrame via window.postMessage
      final data = jsonEncode({
        'objectName': objectName,
        'methodName': methodName,
        'message': message,
      });
      WebUtils.postMessage(data, '*');
    } else {
      // For Native: Use the controller
      _controller?.postMessage(objectName, methodName, message);
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
    if (!isReady.value) {
      isReady.value = true;
      _ref.read(unityInitializedProvider.notifier).state = true;
      // Visibility belongs to the screen (GameBoardScreen sets it true in
      // initState / false in dispose) — a communication service should
      // never own layout state. This used to hide the Unity layer 2s after
      // the *first* message of any kind, which fires mid-match on Android
      // and iOS (every Unity event routes through here), fading the board
      // out while the game screen is still visible.
    }
    try {
      final data = jsonDecode(message);
      if (data is! Map) return;

      final event = data['event'];
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
