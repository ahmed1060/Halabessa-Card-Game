import 'package:halabessa/features/game/presentation/widgets/match_table_layout.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:halabessa/features/game/domain/models/match_state.dart';
import 'package:halabessa/features/game/presentation/widgets/table_style.dart';
import 'room_entry_errors.dart';
import '../../../../core/widgets/lantern_card_fan.dart';

class RoomCreationConfig {
  final GameMode mode;
  final int maxPoints, timerSeconds;
  final bool isPublic;
  const RoomCreationConfig({
    required this.mode,
    required this.maxPoints,
    required this.timerSeconds,
    required this.isPublic,
  });
}

/// Keeps room entry scrollable above the keyboard on short phones and landscape.
class RoomEntrySheet extends StatelessWidget {
  final Widget child;
  const RoomEntrySheet({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final available = math.max(
      0.0,
      MediaQuery.sizeOf(context).height - bottomInset - 12,
    );
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: available),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            color: TableStyle.ink,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const LanternWordmark(),
                      const SizedBox(height: 20),
                      child,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class RoomCreationForm extends StatefulWidget {
  final String Function(String) text;
  final Future<void> Function(RoomCreationConfig) onCreate;
  final VoidCallback onCreated;
  const RoomCreationForm({
    super.key,
    required this.text,
    required this.onCreate,
    required this.onCreated,
  });

  @override
  State<RoomCreationForm> createState() => _RoomCreationFormState();
}

class _RoomCreationFormState extends State<RoomCreationForm> {
  GameMode _mode = GameMode.classic;
  int _score = 41, _timer = 10;
  bool _public = false, _pending = false;
  String? _errorKey;

  Future<void> _create() async {
    if (_pending) return;
    setState(() {
      _pending = true;
      _errorKey = null;
    });
    try {
      await widget.onCreate(
        RoomCreationConfig(
          mode: _mode,
          maxPoints: _score,
          timerSeconds: _timer,
          isPublic: _public,
        ),
      );
    } catch (error) {
      if (mounted)
        setState(() {
          _pending = false;
          _errorKey = createRoomErrorKey(error);
        });
      return;
    }
    if (mounted) widget.onCreated();
  }

  Widget _choice<T>({
    required Key key,
    required T value,
    required T current,
    required String label,
    required ValueChanged<T> onSelected,
  }) {
    final selected = value == current;
    return ChoiceChip(
      key: key,
      selected: selected,
      selectedColor: TableStyle.brass,
      backgroundColor: TableStyle.felt,
      side: BorderSide(color: selected ? TableStyle.brass : TableStyle.muted),
      labelStyle: TableStyle.label.copyWith(
        color: selected ? TableStyle.ink : TableStyle.ivory,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      label: Text(label),
      onSelected: _pending ? null : (_) => setState(() => onSelected(value)),
    );
  }

  Widget _illustratedChoice({
    required Key key,
    required String label,
    required String detail,
    required bool selected,
    required VoidCallback onSelect,
    IconData? icon,
  }) => Semantics(
    button: true,
    selected: selected,
    enabled: !_pending,
    child: Material(
      key: key,
      color: TableStyle.ink,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: _pending ? null : onSelect,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? TableStyle.mint : TableStyle.muted,
              width: selected ? 2.5 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: Icon(
                  selected ? Icons.check_circle : Icons.circle_outlined,
                  color: selected ? TableStyle.mint : TableStyle.muted,
                  size: 22,
                ),
              ),
              if (icon == null)
                const SizedBox(
                  width: 112,
                  height: 70,
                  child: FittedBox(child: LanternCardFan()),
                )
              else
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(icon, color: TableStyle.mint, size: 30),
                ),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TableStyle.label.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                detail,
                textAlign: TextAlign.center,
                style: TableStyle.detail,
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _choicePair(List<Widget> choices) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth < 280 ||
          MediaQuery.textScalerOf(context).scale(14) > 21) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [choices[0], const SizedBox(height: 10), choices[1]],
        );
      }
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: choices[0]),
            const SizedBox(width: 10),
            Expanded(child: choices[1]),
          ],
        ),
      );
    },
  );

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        widget.text('create_room'),
        textAlign: TextAlign.center,
        style: TableStyle.label.copyWith(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: TableStyle.brass,
        ),
      ),
      const SizedBox(height: 24),
      Text(widget.text('select_game_mode'), style: TableStyle.label),
      const SizedBox(height: 8),
      _choicePair([
        _illustratedChoice(
          key: const ValueKey('mode_classic'),
          label: widget.text('classic_mode'),
          detail: widget.text('ui_mode_classic'),
          selected: _mode == GameMode.classic,
          onSelect: () => setState(() => _mode = GameMode.classic),
        ),
        _illustratedChoice(
          key: const ValueKey('mode_tafweet'),
          label: widget.text('tafweet_mode'),
          detail: widget.text('ui_mode_tafweet'),
          selected: _mode == GameMode.tafweet,
          onSelect: () => setState(() => _mode = GameMode.tafweet),
        ),
      ]),
      const SizedBox(height: 20),
      Text(widget.text('select_target_score'), style: TableStyle.label),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final score in [21, 41, 61])
            _choice(
              key: ValueKey('score_$score'),
              value: score,
              current: _score,
              label: score.toString(),
              onSelected: (value) => _score = value,
            ),
        ],
      ),
      const SizedBox(height: 20),
      Text(widget.text('select_timer'), style: TableStyle.label),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final timer in [5, 10, 15, 0])
            _choice(
              key: ValueKey('timer_$timer'),
              value: timer,
              current: _timer,
              label: timer == 0 ? '∞' : '${timer}s',
              onSelected: (value) => _timer = value,
            ),
        ],
      ),
      const SizedBox(height: 20),
      _choicePair([
        _illustratedChoice(
          key: const ValueKey('visibility_public'),
          label: widget.text('public_room'),
          detail: widget.text('public_room_desc'),
          selected: _public,
          icon: Icons.public,
          onSelect: () => setState(() => _public = true),
        ),
        _illustratedChoice(
          key: const ValueKey('visibility_private'),
          label: widget.text('ui_private'),
          detail: widget.text('ui_private_detail'),
          selected: !_public,
          icon: Icons.lock_outline,
          onSelect: () => setState(() => _public = false),
        ),
      ]),
      if (_errorKey != null) ...[
        const SizedBox(height: 12),
        Semantics(
          liveRegion: true,
          child: Text(
            widget.text(_errorKey!),
            key: const ValueKey('create_room_error'),
            style: TableStyle.label.copyWith(color: TableStyle.red),
          ),
        ),
      ],
      const SizedBox(height: 22),
      FilledButton(
        key: const ValueKey('create_room_submit'),
        style: FilledButton.styleFrom(
          backgroundColor: TableStyle.brass,
          foregroundColor: TableStyle.ink,
          minimumSize: const Size.fromHeight(52),
        ),
        onPressed: _pending ? null : _create,
        child: Text(widget.text(_pending ? 'room_creating' : 'create_room')),
      ),
    ],
  );
}

class RoomJoinForm extends StatefulWidget {
  final String Function(String) text;
  final Future<void> Function(String) onJoin;
  final VoidCallback onJoined;
  const RoomJoinForm({
    super.key,
    required this.text,
    required this.onJoin,
    required this.onJoined,
  });

  @override
  State<RoomJoinForm> createState() => _RoomJoinFormState();
}

class _RoomJoinFormState extends State<RoomJoinForm> {
  final _controller = TextEditingController();
  bool _pending = false;
  String? _errorKey;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    if (_pending) return;
    final code = normalizeRoomCode(_controller.text);
    if (!isValidRoomCode(code)) {
      setState(() => _errorKey = 'room_code_format');
      return;
    }
    setState(() {
      _pending = true;
      _errorKey = null;
    });
    try {
      await widget.onJoin(code);
    } catch (error) {
      if (mounted)
        setState(() {
          _pending = false;
          _errorKey = joinRoomErrorKey(error);
        });
      return;
    }
    if (mounted) widget.onJoined();
  }

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        widget.text('join_room'),
        textAlign: TextAlign.center,
        style: TableStyle.label.copyWith(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: TableStyle.brass,
        ),
      ),
      const SizedBox(height: 22),
      TextField(
        key: const ValueKey('room_code_input'),
        controller: _controller,
        enabled: !_pending,
        textCapitalization: TextCapitalization.characters,
        textInputAction: TextInputAction.done,
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
        maxLength: 8,
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
          _UppercaseFormatter(),
        ],
        cursorColor: TableStyle.brass,
        style: TableStyle.label.copyWith(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          letterSpacing: 2,
        ),
        decoration: InputDecoration(
          labelText: widget.text('enter_code'),
          labelStyle: TableStyle.detail,
          hintText: 'ABC12345',
          hintStyle: TableStyle.detail,
          helperText: _errorKey == null
              ? widget.text('room_code_format')
              : null,
          helperStyle: TableStyle.detail,
          counterText: '',
          filled: true,
          fillColor: TableStyle.felt,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: TableStyle.muted),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: TableStyle.brass, width: 2),
          ),
        ),
        onChanged: (_) {
          if (_errorKey != null) setState(() => _errorKey = null);
        },
        onSubmitted: (_) => _join(),
      ),
      if (_errorKey != null) ...[
        const SizedBox(height: 12),
        Semantics(
          liveRegion: true,
          child: Text(
            widget.text(_errorKey!),
            key: const ValueKey('join_room_error'),
            style: TableStyle.label.copyWith(color: TableStyle.red),
          ),
        ),
      ],
      const SizedBox(height: 22),
      FilledButton(
        key: const ValueKey('join_room_submit'),
        style: FilledButton.styleFrom(
          backgroundColor: TableStyle.brass,
          foregroundColor: TableStyle.ink,
          minimumSize: const Size.fromHeight(52),
        ),
        onPressed: _pending ? null : _join,
        child: Text(widget.text(_pending ? 'room_joining' : 'join_room')),
      ),
    ],
  );
}

class _UppercaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) => newValue.copyWith(text: newValue.text.toUpperCase());
}
