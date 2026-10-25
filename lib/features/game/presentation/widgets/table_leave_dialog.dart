import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'table_style.dart';

class TableLeaveDialog extends StatefulWidget {
  const TableLeaveDialog({
    super.key,
    required this.offline,
    required this.onLeave,
  });
  final bool offline;
  final Future<bool> Function() onLeave;
  @override
  State<TableLeaveDialog> createState() => _TableLeaveDialogState();
}

class _TableLeaveDialogState extends State<TableLeaveDialog> {
  bool _leaving = false, _failed = false;
  Future<void> _leave() async {
    if (_leaving) return;
    setState(() {
      _leaving = true;
      _failed = false;
    });
    var left = false;
    try {
      left = await widget.onLeave();
    } catch (_) {
      /* Keep the dialog retryable. */
    }
    if (!mounted) return;
    setState(() {
      _leaving = false;
      _failed = !left;
    });
    if (left) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_leaving,
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
      child: Dialog(
        insetPadding: const EdgeInsets.all(20),
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF10283A), Color(0xFF091724)],
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: TableStyle.brass, width: 1.5),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black54,
                  blurRadius: 24,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.logout_rounded,
                        color: TableStyle.red,
                        size: 30,
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          (widget.offline
                                  ? 'table_leave_practice'
                                  : 'leave_game_title')
                              .tr(),
                          style: TableStyle.label.copyWith(
                            fontSize: 23,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    (widget.offline
                            ? 'offline_leave_warning'
                            : 'leave_game_warning')
                        .tr(),
                    textAlign: TextAlign.center,
                    style: TableStyle.label,
                  ),
                  if (_failed)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        'table_leave_failed'.tr(),
                        style: TableStyle.label.copyWith(color: TableStyle.red),
                      ),
                    ),
                  const SizedBox(height: 24),
                  LayoutBuilder(
                    builder: (context, bounds) {
                      final stay = FilledButton(
                        onPressed: _leaving
                            ? null
                            : () => Navigator.pop(context, false),
                        style: FilledButton.styleFrom(
                          backgroundColor: TableStyle.mint,
                          foregroundColor: TableStyle.ink,
                          minimumSize: const Size(0, 48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'table_stay'.tr(),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      );
                      final leave = OutlinedButton(
                        onPressed: _leaving ? null : _leave,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: TableStyle.red,
                          side: const BorderSide(
                            color: TableStyle.red,
                            width: 1.5,
                          ),
                          minimumSize: const Size(0, 48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _leaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                (widget.offline
                                        ? 'table_leave_practice_button'
                                        : 'leave')
                                    .tr(),
                              ),
                      );
                      if (bounds.maxWidth < 320 ||
                          MediaQuery.textScalerOf(context).scale(14) > 20) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [stay, const SizedBox(height: 10), leave],
                        );
                      }
                      return Row(
                        children: [
                          Expanded(child: stay),
                          const SizedBox(width: 12),
                          Expanded(child: leave),
                        ],
                      );
                    },
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
