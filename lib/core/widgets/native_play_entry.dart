import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../providers/settings_provider.dart';
import '../providers/native_play_provider.dart';
import '../../features/auth/domain/models/app_user.dart';
import '../../features/game/presentation/pages/offline_practice_app.dart';
import '../../features/game/presentation/widgets/table_style.dart';
import 'lantern_page_frame.dart';

class NativePlayEntry extends ConsumerStatefulWidget {
  final Future<void> Function() onOnline;
  const NativePlayEntry({super.key, required this.onOnline});
  @override
  ConsumerState<NativePlayEntry> createState() => _NativePlayEntryState();
}

class _NativePlayEntryState extends ConsumerState<NativePlayEntry> {
  bool _onlinePending = false;
  bool _practice = false;
  AppUser? _player;
  String? _error;
  int _entryGeneration = 0;
  bool _localPending = false;

  Future<void> _startPractice() async {
    if (_localPending) return;
    final generation = ++_entryGeneration;
    ref.read(nativeOnlineEnabledProvider.notifier).state = false;
    setState(() {
      _localPending = true;
      _onlinePending = false;
      _error = null;
    });
    try {
      final preferences = ref.read(sharedPreferencesProvider);
      var uid = preferences.getString('offline_player_id_v1');
      if (uid == null || !uid.startsWith('LOCAL_')) {
        uid = 'LOCAL_${const Uuid().v4()}';
        if (!await preferences.setString('offline_player_id_v1', uid)) {
          if (mounted)
            setState(() {
              _error = 'offline_save_failed';
              _localPending = false;
            });
          return;
        }
      }
      if (!mounted || generation != _entryGeneration) return;
      setState(() {
        _player = AppUser(
          uid: uid!,
          email: '',
          displayName: 'local_player_name'.tr(),
          avatarUrl: 'assets/images/avatars/avatar1.png',
        );
        _practice = true;
        _localPending = false;
      });
    } catch (_) {
      if (mounted && generation == _entryGeneration) {
        setState(() {
          _localPending = false;
          _error = 'offline_save_failed';
        });
      }
    }
  }

  Future<void> _startOnline() async {
    if (_onlinePending || _localPending) return;
    final generation = ++_entryGeneration;
    setState(() {
      _onlinePending = true;
      _error = null;
    });
    try {
      await widget.onOnline();
      // Initializing a native SDK may finish after the player chose local play.
      // Never let that old request dispose an active offline game.
      if (mounted && generation == _entryGeneration && !_practice) {
        ref.read(nativeOnlineEnabledProvider.notifier).state = true;
      }
    } catch (_) {
      if (mounted && generation == _entryGeneration)
        setState(() => _error = 'online_entry_retry');
    } finally {
      if (mounted && generation == _entryGeneration)
        setState(() => _onlinePending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_practice && _player != null)
      return OfflinePracticeApp(
        preferences: ref.read(sharedPreferencesProvider),
        player: _player!,
        onExit: () => setState(() => _practice = false),
      );
    return LanternPageFrame(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'حلبسه — Halabessa',
                      textAlign: TextAlign.center,
                      style: TableStyle.label.copyWith(
                        fontSize: 32,
                        color: TableStyle.brass,
                      ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      key: const ValueKey('native-online'),
                      onPressed: _onlinePending || _localPending
                          ? null
                          : _startOnline,
                      icon: const Icon(Icons.public),
                      label: Text('online_play_title'.tr()),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      key: const ValueKey('native-offline'),
                      onPressed: _localPending ? null : _startPractice,
                      icon: const Icon(Icons.offline_bolt_outlined),
                      label: Text('offline_practice_title'.tr()),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'offline_practice_description'.tr(),
                      textAlign: TextAlign.center,
                      style: TableStyle.detail.copyWith(fontSize: 15),
                    ),
                    if (_onlinePending)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(),
                      ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          _error!.tr(),
                          textAlign: TextAlign.center,
                          style: TableStyle.label,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
