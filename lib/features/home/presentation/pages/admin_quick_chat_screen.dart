import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import '../../../../core/widgets/lantern_page_frame.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../game/domain/models/quick_chat_phrase.dart';
import '../../../game/presentation/providers/quick_chat_providers.dart';
import '../../../game/presentation/widgets/table_style.dart';

class AdminQuickChatScreen extends ConsumerWidget {
  const AdminQuickChatScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(quickChatAdminProvider);
    return LanternPageFrame(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: Text('quick_chat_manage'.tr()),
        ),
        body: access.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => _failure(context, ref),
          data: (allowed) => !allowed
              ? Center(child: Text('quick_chat_superadmin'.tr()))
              : ref
                    .watch(quickChatCatalogProvider)
                    .when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (_, _) => _failure(context, ref),
                      data: (catalog) => QuickChatManager(
                        catalog: catalog,
                        onChange: (body) async {
                          final updated = await ref.read(backendCallProvider)(
                            'updateQuickChatPhrase',
                            data: body,
                          );
                          ref.invalidate(quickChatCatalogProvider);
                          return QuickChatCatalog.fromJson(updated);
                        },
                      ),
                    ),
        ),
      ),
    );
  }

  Widget _failure(BuildContext context, WidgetRef ref) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('table_chat_unavailable'.tr()),
        TextButton(
          onPressed: () {
            ref.invalidate(quickChatAdminProvider);
            ref.invalidate(quickChatCatalogProvider);
          },
          child: Text('retry'.tr()),
        ),
      ],
    ),
  );
}

class QuickChatManager extends StatefulWidget {
  const QuickChatManager({
    super.key,
    required this.catalog,
    required this.onChange,
  });
  final QuickChatCatalog catalog;
  final Future<QuickChatCatalog> Function(Map<String, dynamic> body) onChange;
  @override
  State<QuickChatManager> createState() => _QuickChatManagerState();
}

class _QuickChatManagerState extends State<QuickChatManager> {
  late QuickChatCatalog _catalog = widget.catalog;
  bool _busy = false;
  String? _error;
  @override
  void didUpdateWidget(QuickChatManager oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.catalog != widget.catalog) _catalog = widget.catalog;
  }

  Future<void> _change(Map<String, dynamic> body) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await widget.onChange({
        ...body,
        'revision': _catalog.revision,
      });
      if (mounted) setState(() => _catalog = result);
    } catch (_) {
      if (mounted) setState(() => _error = 'quick_chat_save_failed'.tr());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit([QuickChatPhrase? phrase]) async {
    final value = await showDialog<QuickChatPhrase>(
      context: context,
      builder: (_) => _PhraseEditor(phrase: phrase),
    );
    if (value == null || !mounted) return;
    await _change({
      'operation': 'save',
      'presetId': value.id,
      'phrase': {'en': value.en, 'ar': value.ar},
    });
  }

  Future<void> _delete(QuickChatPhrase phrase) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF10283A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: TableStyle.brass),
        ),
        title: Text('quick_chat_delete_title'.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              phrase.label(context.locale.languageCode),
              style: TableStyle.label,
            ),
            const SizedBox(height: 14),
            Text('quick_chat_delete_hint'.tr(), style: TableStyle.detail),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('quick_chat_keep'.tr()),
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(context, true),
            style: OutlinedButton.styleFrom(
              foregroundColor: TableStyle.red,
              side: const BorderSide(color: TableStyle.red),
            ),
            child: Text('delete'.tr()),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted)
      await _change({'operation': 'delete', 'presetId': phrase.id});
  }

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1000),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xF2091E2C),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: TableStyle.brass, width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 16,
                  runSpacing: 12,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'quick_chat_manage'.tr(),
                          style: TableStyle.label.copyWith(
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'quick_chat_superadmin'.tr(),
                          style: TableStyle.detail.copyWith(
                            color: TableStyle.brass,
                          ),
                        ),
                      ],
                    ),
                    FilledButton.icon(
                      onPressed: _busy || _catalog.items.length >= 32
                          ? null
                          : () => _edit(),
                      style: FilledButton.styleFrom(
                        backgroundColor: TableStyle.mint,
                        foregroundColor: TableStyle.ink,
                        minimumSize: const Size(140, 48),
                      ),
                      icon: const Icon(Icons.add),
                      label: Text('quick_chat_add'.tr()),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text('quick_chat_manage_hint'.tr(), style: TableStyle.detail),
                const SizedBox(height: 20),
                if (_busy) const LinearProgressIndicator(),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      _error!,
                      style: TableStyle.label.copyWith(color: TableStyle.red),
                    ),
                  ),
                if (_catalog.items.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'quick_chat_no_phrases'.tr(),
                      style: TableStyle.label,
                    ),
                  ),
                for (final (index, phrase) in _catalog.items.indexed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: LayoutBuilder(
                        builder: (context, bounds) {
                          final wide =
                              bounds.maxWidth >= 600 &&
                              MediaQuery.textScalerOf(context).scale(14) <= 20;
                          final text = wide
                              ? Row(
                                  children: [
                                    SizedBox(
                                      width: 28,
                                      child: Text(
                                        '${index + 1}',
                                        style: TableStyle.detail,
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        phrase.en,
                                        textDirection: TextDirection.ltr,
                                        style: TableStyle.label.copyWith(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        phrase.ar,
                                        textDirection: TextDirection.rtl,
                                        style: TableStyle.label,
                                      ),
                                    ),
                                  ],
                                )
                              : Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Text(
                                      '${index + 1}   ${phrase.en}',
                                      textDirection: TextDirection.ltr,
                                      style: TableStyle.label.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      phrase.ar,
                                      textDirection: TextDirection.rtl,
                                      style: TableStyle.label,
                                    ),
                                  ],
                                );
                          final buttons = Wrap(
                            spacing: 10,
                            runSpacing: 6,
                            children: [
                              OutlinedButton.icon(
                                onPressed: _busy ? null : () => _edit(phrase),
                                icon: const Icon(Icons.edit_outlined, size: 18),
                                label: Text('edit'.tr()),
                              ),
                              OutlinedButton.icon(
                                onPressed: _busy ? null : () => _delete(phrase),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: TableStyle.red,
                                  side: const BorderSide(color: TableStyle.red),
                                ),
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 18,
                                ),
                                label: Text('delete'.tr()),
                              ),
                            ],
                          );
                          return !wide
                              ? Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    text,
                                    const SizedBox(height: 12),
                                    buttons,
                                  ],
                                )
                              : Row(
                                  children: [
                                    Expanded(child: text),
                                    const SizedBox(width: 20),
                                    buttons,
                                  ],
                                );
                        },
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                const Divider(color: Colors.white12),
                Text(
                  'quick_chat_player_preview'.tr(),
                  style: TableStyle.label.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 8),
                Text('quick_chat_preview_hint'.tr(), style: TableStyle.detail),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final phrase in _catalog.items)
                      Chip(
                        label: Text(phrase.label(context.locale.languageCode)),
                        labelStyle: TableStyle.label,
                        backgroundColor: TableStyle.ink,
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'quick_chat_available_locked'.tr(),
                  style: TableStyle.detail.copyWith(color: TableStyle.brass),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _PhraseEditor extends StatefulWidget {
  const _PhraseEditor({this.phrase});
  final QuickChatPhrase? phrase;
  @override
  State<_PhraseEditor> createState() => _PhraseEditorState();
}

class _PhraseEditorState extends State<_PhraseEditor> {
  late final _english = TextEditingController(text: widget.phrase?.en);
  late final _arabic = TextEditingController(text: widget.phrase?.ar);
  final _form = GlobalKey<FormState>();
  @override
  void dispose() {
    _english.dispose();
    _arabic.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: const Color(0xFF10283A),
    scrollable: true,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: const BorderSide(color: TableStyle.brass),
    ),
    title: Text(
      (widget.phrase == null ? 'quick_chat_add' : 'quick_chat_edit').tr(),
    ),
    content: SizedBox(
      width: 400,
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (controller, label, direction) in [
              (_english, 'quick_chat_english', TextDirection.ltr),
              (_arabic, 'quick_chat_arabic', TextDirection.rtl),
            ]) ...[
              TextFormField(
                controller: controller,
                maxLength: 60,
                textDirection: direction,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: label.tr(),
                  border: const OutlineInputBorder(),
                ),
                validator: (value) =>
                    value == null ||
                        value.trim().isEmpty ||
                        value.trim().length > 60 ||
                        RegExp(r'[\x00-\x1f\x7f]').hasMatch(value)
                    ? 'quick_chat_required'.tr()
                    : null,
              ),
              const SizedBox(height: 10),
            ],
            Text('quick_chat_player_preview'.tr(), style: TableStyle.detail),
            Wrap(
              spacing: 8,
              children: [
                Chip(label: Text(_english.text)),
                Chip(label: Text(_arabic.text)),
              ],
            ),
            const SizedBox(height: 12),
            Text('quick_chat_edit_hint'.tr(), style: TableStyle.detail),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text('cancel'.tr()),
      ),
      FilledButton(
        onPressed: () {
          if (!_form.currentState!.validate()) return;
          Navigator.pop(
            context,
            QuickChatPhrase(
              id:
                  widget.phrase?.id ??
                  'phrase_${DateTime.now().microsecondsSinceEpoch}_${Random.secure().nextInt(1 << 30)}',
              en: _english.text.trim(),
              ar: _arabic.text.trim(),
            ),
          );
        },
        child: Text('save_changes'.tr()),
      ),
    ],
  );
}
