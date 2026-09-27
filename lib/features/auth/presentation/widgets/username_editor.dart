import 'dart:async';
import 'package:flutter/material.dart';
import '../../../game/presentation/widgets/table_style.dart';

/// Availability responses are tied to the exact input revision. A successful
/// check for an earlier name must never enable saving the current name.
class UsernameEditor extends StatefulWidget {
  final String title, description, fieldLabel, saveLabel, invalidMessage;
  final String takenMessage, failureMessage, retryLabel;
  final Future<bool> Function(String) onCheck;
  final Future<void> Function(String) onSave;
  final VoidCallback onSaved, onClose;
  const UsernameEditor({super.key, required this.title, required this.description,
    required this.fieldLabel, required this.saveLabel, required this.invalidMessage,
    required this.takenMessage, required this.failureMessage, required this.retryLabel,
    required this.onCheck, required this.onSave, required this.onSaved, required this.onClose});
  @override
  State<UsernameEditor> createState() => _UsernameEditorState();
}

class _UsernameEditorState extends State<UsernameEditor> {
  final _text = TextEditingController();
  Timer? _debounce;
  int _revision = 0;
  bool _available = false, _checking = false, _saving = false, _checkFailed = false;
  String? _error;

  @override
  void dispose() { _debounce?.cancel(); _text.dispose(); super.dispose(); }

  void _changed(String raw) {
    _debounce?.cancel();
    final revision = ++_revision;
    final value = raw.trim();
    final valid = value.length >= 3 && value.length <= 20 &&
        RegExp(r'^[a-zA-Z0-9_\u0600-\u06FF]+$').hasMatch(value);
    setState(() {
      _available = false;
      _checking = valid;
      _checkFailed = false;
      _error = value.isEmpty || valid ? null : widget.invalidMessage;
    });
    if (valid) _debounce = Timer(const Duration(milliseconds: 350), () => _check(value, revision));
  }

  Future<void> _check(String value, int revision) async {
    try {
      final available = await widget.onCheck(value);
      if (!mounted || revision != _revision) return;
      setState(() {
        _available = available;
        _checking = false;
        _error = available ? null : widget.takenMessage;
      });
    } catch (_) {
      if (!mounted || revision != _revision) return;
      setState(() { _checking = false; _checkFailed = true; _error = widget.failureMessage; });
    }
  }

  Future<void> _save() async {
    if (!_available || _checking || _saving) return;
    final value = _text.text.trim();
    setState(() { _saving = true; _error = null; });
    try {
      await widget.onSave(value);
      if (mounted) widget.onSaved();
    } catch (_) {
      if (mounted) setState(() { _saving = false; _error = widget.failureMessage; });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: Material(
      color: TableStyle.ink,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: SafeArea(child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(24, 12, 24, 24 + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(alignment: AlignmentDirectional.centerEnd, child: IconButton(
              tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              onPressed: _saving ? null : widget.onClose,
              icon: const Icon(Icons.close, color: TableStyle.ivory))),
            Text(widget.title, style: TableStyle.label.copyWith(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text(widget.description, style: TableStyle.label),
            const SizedBox(height: 24),
            TextField(controller: _text, onChanged: _changed, enabled: !_saving,
              maxLength: 20, textInputAction: TextInputAction.done,
              onSubmitted: (_) => _save(), style: TableStyle.label,
              decoration: InputDecoration(
                labelText: widget.fieldLabel, labelStyle: TableStyle.detail,
                prefixIcon: const Icon(Icons.alternate_email, color: TableStyle.brass),
                border: const OutlineInputBorder(), errorText: _error, errorMaxLines: 4,
                suffixIcon: _checking ? const Padding(padding: EdgeInsets.all(14),
                  child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))) :
                  _available ? const Icon(Icons.check, color: TableStyle.brass) : null,
              )),
            if (_checkFailed) TextButton(onPressed: () => _changed(_text.text), child: Text(widget.retryLabel)),
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: TableStyle.brass, foregroundColor: TableStyle.ink,
                minimumSize: const Size(48, 52)),
              onPressed: _available && !_saving && !_checking ? _save : null,
              child: _saving ? const SizedBox(width: 22, height: 22,
                child: CircularProgressIndicator(strokeWidth: 2)) : Text(widget.saveLabel),
            ),
          ],
        ),
      )),
    ),
  );
}
