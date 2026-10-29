import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/multimedia_service.dart';
import '../../../core/widgets/lantern_page_frame.dart';
import '../../../core/widgets/lantern_help_screen.dart';
import '../../auth/domain/models/app_user.dart';
import '../../game/presentation/pages/offline_practice_app.dart';
import '../../game/presentation/pages/game_board_screen.dart';
import '../../game/presentation/widgets/table_style.dart';
import '../data/lan_connection.dart';
import '../data/lan_socket_transport.dart';
import '../data/lan_discovery.dart';
import '../domain/lan_protocol.dart';
import 'lan_match_adapter.dart';
import 'lan_qr_scanner.dart';
import 'lan_unity_surface.dart';
import '../../../core/providers/native_play_provider.dart';
import '../../game/presentation/providers/unity_communication_service.dart';
import '../../game/presentation/widgets/unity_game_view.dart';

class LanPlayApp extends StatefulWidget {
  const LanPlayApp({
    super.key,
    required this.preferences,
    required this.player,
    required this.onExit,
    this.hostFactory,
    this.joinFactory,
    this.discoveryFactory,
    this.audioFactory,
    this.unityEnabled,
    this.unityView,
    this.bridgeFactory,
  });
  final SharedPreferences preferences;
  final AppUser player;
  final VoidCallback onExit;
  final Future<LanHostedRoom> Function(LanGameDriver, String)? hostFactory;
  final Future<LanConnection> Function(LanInvitation, String)? joinFactory;
  final LanDiscovery Function()? discoveryFactory;
  final MultimediaService Function(Ref)? audioFactory;
  // Explicit QA seams. Product entry remains mobile-only.
  final bool? unityEnabled;
  final Widget? unityView;
  final UnityCommunicationService Function(Ref)? bridgeFactory;
  @override
  State<LanPlayApp> createState() => _LanPlayAppState();
}

class _LanPlayAppState extends State<LanPlayApp> with WidgetsBindingObserver {
  final _invite = TextEditingController();
  final _manualAddress = TextEditingController(),
      _manualPort = TextEditingController(),
      _manualRoom = TextEditingController(),
      _manualPin = TextEditingController(),
      _manualSecret = TextEditingController();
  bool _manual = false;
  String _mode = 'classic';
  late final _name = TextEditingController(text: widget.player.displayName);
  late final LanDiscovery _discovery =
      widget.discoveryFactory?.call() ?? LanDiscovery();
  LanHostedRoom? _host;
  LanConnection? _connection;
  bool _busy = false, _joining = false;
  String? _error, _address;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _discovery.addListener(_changed);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      _generation++;
      if (mounted) setState(() => _busy = false);
      unawaited(_discovery.stop());
      // No background hosting: send the terminal snapshot before closing.
      if (_host != null) {
        unawaited(_host!.close());
      } else if (_connection != null) {
        unawaited(_connection!.suspend());
      }
    } else if (state == AppLifecycleState.resumed) {
      if (_joining && _connection == null) unawaited(_discovery.browse());
      if (_host == null &&
          _connection != null &&
          _connection!.status != 'ended') {
        unawaited(_connection!.reconnect().catchError((Object _) {}));
      }
    }
  }

  Future<void> _create() async {
    if (_busy) return;
    final generation = ++_generation;
    setState(() {
      _busy = true;
      _error = null;
    });
    final driver = LanMatchDriver(widget.preferences, widget.player);
    try {
      final host = await (widget.hostFactory ?? hostLanRoom)(
        driver,
        _name.text,
      );
      if (!mounted || generation != _generation) {
        await host.close();
        return;
      }
      _host = host;
      _address = host.addresses.first;
      _connection = host.local;
      _connection!.addListener(_changed);
      unawaited(_discovery.advertise(host.port, _name.text));
    } catch (_) {
      await driver.close();
      if (mounted && generation == _generation) _error = 'lan_connection_help';
    } finally {
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
  }

  Future<void> _join() async {
    if (_busy) return;
    final generation = ++_generation;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final raw = _manual
          ? LanInvitation(
              address: _manualAddress.text.trim(),
              port: int.parse(_manualPort.text.trim()),
              room: _manualRoom.text.trim(),
              fingerprint: _manualPin.text.trim().toLowerCase(),
              secret: _manualSecret.text.trim(),
            ).text
          : _invite.text;
      final invitation = LanInvitation.parse(raw);
      final connection = await (widget.joinFactory ?? joinLanRoom)(
        invitation,
        _name.text,
      );
      if (!mounted || generation != _generation) {
        await connection.close();
        connection.dispose();
        return;
      }
      _connection = connection..addListener(_changed);
      _invite.clear();
      await _discovery.stop();
    } catch (_) {
      if (mounted && generation == _generation) _error = 'lan_connection_help';
    } finally {
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
  }

  Future<void> _disconnect() async {
    _generation++;
    final connection = _connection, host = _host;
    _connection = null;
    _host = null;
    connection?.removeListener(_changed);
    if (host != null) {
      await host.close();
    } else {
      await connection?.close();
    }
    connection?.dispose();
    await _discovery.stop();
    if (mounted) {
      setState(() {
        _busy = false;
        _error = null;
        _joining = false;
      });
    }
  }

  @override
  void dispose() {
    _generation++;
    WidgetsBinding.instance.removeObserver(this);
    _connection?.removeListener(_changed);
    if (_host != null) {
      unawaited(_host!.close());
    } else if (_connection != null) {
      unawaited(_connection!.close());
    }
    _discovery.dispose();
    _invite.dispose();
    for (final field in [
      _manualAddress,
      _manualPort,
      _manualRoom,
      _manualPin,
      _manualSecret,
    ]) {
      field.dispose();
    }
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final connection = _connection, view = connection?.snapshot;
    if (connection != null &&
        (connection.status == 'ended' || view?['closed'] == true)) {
      return _frame(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off, color: TableStyle.brass, size: 48),
            const SizedBox(height: 16),
            Text(
              (view?['reason'] as String? ?? 'lan_room_ended').tr(),
              textAlign: TextAlign.center,
              style: TableStyle.label,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _disconnect,
              child: Text('return_home'.tr()),
            ),
          ],
        ),
      );
    }
    if (connection != null &&
        view?['started'] == true &&
        view?['match'] is Map) {
      return _LanTable(
        key: ValueKey('${connection.uid}:${view!['room']}'),
        connection: connection,
        preferences: widget.preferences,
        player: widget.player.copyWith(uid: connection.uid),
        onExit: _disconnect,
        audioFactory: widget.audioFactory,
        unityEnabled: widget.unityEnabled ?? isNativeMobile,
        unityView: widget.unityView,
        bridgeFactory: widget.bridgeFactory,
      );
    }
    return _frame(connection == null ? _entry() : _lobby(connection, view!));
  }

  Widget _frame(Widget child) => LanternPageFrame(
    child: Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text('lan_title'.tr()),
        leading: IconButton(
          onPressed: _busy
              ? null
              : () {
                  if (_connection != null) {
                    _disconnect();
                  } else if (_joining) {
                    _discovery.stop();
                    setState(() => _joining = false);
                  } else {
                    widget.onExit();
                  }
                },
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            key: ValueKey(_connection?.uid ?? (_joining ? 'join' : 'entry')),
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: child,
            ),
          ),
        ),
      ),
    ),
  );

  Future<void> _scan() async {
    final text = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const LanQrScanner()),
    );
    if (mounted && text != null) {
      setState(() {
        _manual = false;
        _invite.text = text;
      });
    }
  }

  Widget _manualField(
    TextEditingController controller,
    String name, {
    int length = 64,
  }) => TextField(
    key: ValueKey('lan-$name'),
    controller: controller,
    enabled: !_busy,
    maxLength: length,
    autocorrect: false,
    enableSuggestions: false,
    decoration: InputDecoration(labelText: 'lan_manual_$name'.tr()),
  );

  Widget _entry() => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Icon(Icons.wifi, color: TableStyle.brass, size: 56),
      const SizedBox(height: 16),
      Text(
        'lan_description'.tr(),
        textAlign: TextAlign.center,
        style: TableStyle.label,
      ),
      const SizedBox(height: 20),
      TextField(
        controller: _name,
        maxLength: 30,
        enabled: !_busy,
        decoration: InputDecoration(labelText: 'lan_nickname'.tr()),
      ),
      if (!_joining) ...[
        const SizedBox(height: 16),
        FilledButton.icon(
          key: const ValueKey('lan-create'),
          onPressed: _busy ? null : _create,
          icon: const Icon(Icons.add),
          label: Text('lan_create'.tr()),
        ),
        OutlinedButton.icon(
          key: const ValueKey('lan-browse'),
          onPressed: _busy
              ? null
              : () {
                  setState(() => _joining = true);
                  unawaited(_discovery.browse());
                },
          icon: const Icon(Icons.group_add),
          label: Text('lan_join'.tr()),
        ),
      ] else ...[
        Text('lan_nearby'.tr(), style: TableStyle.label),
        if (_discovery.rooms.isEmpty)
          Text(
            (_discovery.failed ? 'lan_discovery_help' : 'lan_searching').tr(),
            style: TableStyle.detail,
          ),
        for (final room in _discovery.rooms.take(12))
          ListTile(
            leading: const Icon(Icons.wifi, color: TableStyle.mint),
            title: Text(room.name ?? 'Halabessa', style: TableStyle.label),
            onTap: _busy ? null : _scan,
            trailing: const Icon(Icons.qr_code_scanner, color: TableStyle.mint),
            subtitle: Text(
              'lan_invitation_needed'.tr(),
              style: TableStyle.detail,
            ),
          ),
        const SizedBox(height: 16),
        TextField(
          controller: _invite,
          enabled: !_busy,
          minLines: 2,
          maxLines: 4,
          maxLength: 1024,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(labelText: 'lan_invitation'.tr()),
        ),
        SwitchListTile(
          title: Text('lan_manual_details'.tr(), style: TableStyle.label),
          value: _manual,
          onChanged: _busy ? null : (value) => setState(() => _manual = value),
        ),
        if (_manual) ...[
          _manualField(_manualAddress, 'address', length: 15),
          _manualField(_manualPort, 'port', length: 5),
          _manualField(_manualRoom, 'room'),
          _manualField(_manualPin, 'pin'),
          _manualField(_manualSecret, 'secret', length: 43),
        ],
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          children: [
            OutlinedButton.icon(
              onPressed: _busy ? null : _scan,
              icon: const Icon(Icons.qr_code_scanner),
              label: Text('lan_scan'.tr()),
            ),
            FilledButton(
              onPressed: _busy ? null : _join,
              child: Text('lan_join'.tr()),
            ),
          ],
        ),
      ],
      if (_busy)
        const Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(),
        ),
      if (_error != null)
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            _error!.tr(),
            textAlign: TextAlign.center,
            style: TableStyle.detail,
          ),
        ),
    ],
  );

  Widget _lobby(LanConnection connection, Map<String, dynamic> view) {
    final host = _host;
    final members = (view['members'] as List).whereType<Map>();
    final invitation = host?.invitation(_address!);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('lan_lobby'.tr(), style: TableStyle.label.copyWith(fontSize: 26)),
        const SizedBox(height: 16),
        for (final member in members)
          ListTile(
            leading: Icon(
              member['connected'] == true ? Icons.person : Icons.person_off,
              color: TableStyle.mint,
            ),
            title: Text(member['name'] as String, style: TableStyle.label),
            trailing: Text(
              member['uid'] == connection.uid ? 'table_you'.tr() : '',
              style: TableStyle.detail,
            ),
          ),
        Text('lan_empty_bots'.tr(), style: TableStyle.detail),
        if (host != null) ...[
          const SizedBox(height: 16),
          if (host.addresses.length > 1)
            DropdownButton<String>(
              value: _address,
              items: [
                for (final address in host.addresses)
                  DropdownMenuItem(value: address, child: Text(address)),
              ],
              onChanged: (value) => setState(() => _address = value),
            ),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(12),
            child: QrImageView(data: invitation!.text, size: 210),
          ),
          const SizedBox(height: 8),
          SelectableText(
            '${invitation.address}:${invitation.port}',
            style: TableStyle.label,
          ),
          OutlinedButton.icon(
            onPressed: () =>
                Clipboard.setData(ClipboardData(text: invitation.text)),
            icon: const Icon(Icons.copy),
            label: Text('lan_copy_invitation'.tr()),
          ),
          ExpansionTile(
            title: Text('lan_manual_details'.tr(), style: TableStyle.label),
            children: [
              for (final entry in {
                'address': invitation.address,
                'port': '${invitation.port}',
                'room': invitation.room,
                'pin': invitation.fingerprint,
                'secret': invitation.secret,
              }.entries)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'lan_manual_${entry.key}'.tr(),
                        style: TableStyle.detail,
                      ),
                      SelectableText(entry.value, style: TableStyle.label),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _mode,
            items: [
              for (final mode in ['classic', 'tafweet'])
                DropdownMenuItem(value: mode, child: Text('${mode}_mode'.tr())),
            ],
            onChanged: _busy
                ? null
                : (value) => setState(() => _mode = value ?? 'classic'),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            key: const ValueKey('lan-start'),
            onPressed: _busy
                ? null
                : () async {
                    setState(() => _busy = true);
                    try {
                      await host.start(mode: _mode);
                    } catch (_) {
                      _error = 'lan_cannot_start';
                    } finally {
                      if (mounted) setState(() => _busy = false);
                    }
                  },
            icon: const Icon(Icons.play_arrow),
            label: Text('lan_start'.tr()),
          ),
          Text(
            'lan_host_foreground'.tr(),
            textAlign: TextAlign.center,
            style: TableStyle.detail,
          ),
        ] else
          Text('lan_waiting_host'.tr(), style: TableStyle.label),
        if (connection.status != 'connected') _reconnectPanel(connection),
        if (_error != null) Text(_error!.tr(), style: TableStyle.detail),
      ],
    );
  }
}

Widget _reconnectPanel(LanConnection connection) => Column(
  mainAxisSize: MainAxisSize.min,
  children: [
    Text(
      'lan_reconnecting'.tr(),
      textAlign: TextAlign.center,
      style: TableStyle.label,
    ),
    const SizedBox(height: 16),
    FilledButton(
      onPressed: () => connection.reconnect().catchError((Object _) {}),
      child: Text('retry'.tr()),
    ),
  ],
);

class _LanTable extends StatefulWidget {
  const _LanTable({
    super.key,
    required this.connection,
    required this.preferences,
    required this.player,
    required this.onExit,
    this.audioFactory,
    required this.unityEnabled,
    this.unityView,
    this.bridgeFactory,
  });
  final LanConnection connection;
  final SharedPreferences preferences;
  final AppUser player;
  final VoidCallback onExit;
  final MultimediaService Function(Ref)? audioFactory;
  final bool unityEnabled;
  final Widget? unityView;
  final UnityCommunicationService Function(Ref)? bridgeFactory;
  @override
  State<_LanTable> createState() => _LanTableState();
}

class _LanTableState extends State<_LanTable> {
  late final List<Override> _overrides = [
    ...offlinePlayOverrides(
      widget.preferences,
      widget.player,
      matchFactory: (ref) => LanReplicaNotifier(ref, widget.connection),
      audioFactory: widget.audioFactory,
    ),
    ...lanUnityOverrides(
      enabled: widget.unityEnabled,
      bridgeFactory: widget.bridgeFactory,
    ),
  ];
  @override
  Widget build(BuildContext context) => ProviderScope(
    overrides: _overrides,
    child: Consumer(
      builder: (context, ref, _) => Listener(
        onPointerDown: (_) =>
            ref.read(multimediaServiceProvider).handleInteraction(),
        child: LanUnitySurface(
          connection: widget.connection,
          unityView: widget.unityView ?? const UnityGameView(),
          child: Navigator(
            initialRoute: '/game',
            onGenerateRoute: (settings) => MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => settings.name == '/help'
                  ? const LanternHelpScreen()
                  : settings.name == '/game'
                  ? ListenableBuilder(
                      listenable: widget.connection,
                      builder: (_, child) => Stack(
                        children: [
                          ExcludeFocus(
                            excluding: widget.connection.status != 'connected',
                            child: child!,
                          ),
                          if (widget.connection.status != 'connected')
                            Positioned.fill(
                              child: BlockSemantics(
                                child: ColoredBox(
                                  color: TableStyle.ink.withValues(alpha: .95),
                                  child: Center(
                                    child: SingleChildScrollView(
                                      padding: const EdgeInsets.all(24),
                                      child: ConstrainedBox(
                                        constraints: const BoxConstraints(
                                          maxWidth: 440,
                                        ),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            _reconnectPanel(widget.connection),
                                            TextButton(
                                              onPressed: widget.onExit,
                                              child: Text(
                                                'leave_game_title'.tr(),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      child: const GameBoardScreen(),
                    )
                  : Scaffold(
                      body: Center(
                        child: FilledButton(
                          onPressed: widget.onExit,
                          child: Text('return_home'.tr()),
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ),
    ),
  );
}
