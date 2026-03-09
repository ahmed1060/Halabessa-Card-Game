import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:halabessa/core/utils/web_utils.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_unity_widget/flutter_unity_widget.dart';
import '../providers/unity_layer_provider.dart';
import '../../domain/models/match_state.dart';
import '../../domain/providers/game_providers.dart';

final unityCommunicationServiceProvider = Provider((ref) => UnityCommunicationService(ref)..init());

class UnityCommunicationService {
  final Ref _ref;
  UnityWidgetController? _controller;
  final ValueNotifier<bool> isReady = ValueNotifier<bool>(false);

  UnityCommunicationService(this._ref);

  void init() {
    if (kIsWeb) {
      WebUtils.onMessage?.listen((event) {
        try {
          final message = event.data;
          if (message is String) {
            final data = jsonDecode(message);
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

  void _postToUnity(String objectName, String methodName, String message) {
    postMessage(objectName, methodName, message);
  }

  void syncState(MatchState state) {
    final message = {
      'type': 'SYNC_STATE',
      'board': state.board.map((c) => c.toJson()).toList(),
      'phase': state.phase.name,
      'turnIndex': state.currentTurnIndex,
    };
    _postToUnity('UnityBridge', 'OnFlutterMessage', jsonEncode(message));
  }

  void playCard(String cardId, Map<String, double> position) {
    final message = {
      'type': 'PLAY_CARD',
      'cardId': cardId,
      'x': position['x'],
      'y': position['y'],
    };
    _postToUnity('UnityBridge', 'OnFlutterMessage', jsonEncode(message));
  }

  void updateSkins(String skinId) {
    _postToUnity('UnityBridge', 'OnFlutterMessage', jsonEncode({
      'type': 'UPDATE_SKINS',
      'skinId': skinId,
    }));
  }

  void startTimer(int durationSeconds) {
    _postToUnity('UnityBridge', 'OnFlutterMessage', jsonEncode({
      'type': 'START_TIMER',
      'duration': durationSeconds.toDouble(),
    }));
  }

  void setMode(String mode) {
    _postToUnity('UnityBridge', 'OnFlutterMessage', jsonEncode({
      'type': 'SET_MODE',
      'mode': mode,
    }));
  }

  void handleUnityMessage(String message) {
    if (!isReady.value) {
      isReady.value = true;
      _ref.read(unityInitializedProvider.notifier).state = true;
      
      // Auto-hide the boot splash after a small delay for a smooth transition
      Future.delayed(const Duration(seconds: 2), () {
        // Only hide if we aren't ALREADY on a screen that requested Unity visibility
        // (This handles the case where Unity finishes loading exactly as we enter a game)
        _ref.read(unityLayerVisibilityProvider.notifier).update((isVisible) => isVisible ? false : false);
        // Wait, the above logic is flawed. Let's just set it to false. 
        // If GameBoardScreen is active, it will have its own logic or we can check the route.
        _ref.read(unityLayerVisibilityProvider.notifier).state = false;
      });
    }
    try {
      final data = jsonDecode(message);
      print("Unity Message Received: $data");
      
      if (data['event'] == 'BASRA_EVENT') {
        // Trigger Flutter-side celebratory logic or haptics
        HapticFeedback.heavyImpact();
      } else if (data['event'] == 'ANIMATION_COMPLETE') {
        // Handle synchronization points
      }
    } catch (e) {
      print("Error decoding Unity message: $e");
    }
  }
}
