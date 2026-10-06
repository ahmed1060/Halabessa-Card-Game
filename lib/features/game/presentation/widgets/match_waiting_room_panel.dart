import 'package:flutter/material.dart';
import 'table_style.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../auth/domain/models/app_user.dart';

/// The pre-match room controls. The table stays visible behind this compact
/// panel, while a pending bot-consent request cannot be submitted twice.
class MatchWaitingRoomPanel extends StatefulWidget {
  final String roomId, currentUid, title, roomLabel, waitingLabel, youLabel;
  final String botLabel, playerLabel, readyLabel, consentLabel, fullLabel;
  final String spectatorLabel, inviteLabel, failureLabel;
  final List<String> playerIds;
  final Map<String, String> playerNames;
  final Map<String, String> playerAvatars;
  final Map<String, bool> botVotes;
  final VoidCallback? onInvite;
  final Future<void> Function()? onReady;

  const MatchWaitingRoomPanel({
    super.key,
    required this.roomId,
    required this.currentUid,
    required this.title,
    required this.roomLabel,
    required this.waitingLabel,
    required this.youLabel,
    required this.botLabel,
    required this.playerLabel,
    required this.readyLabel,
    required this.consentLabel,
    required this.fullLabel,
    required this.spectatorLabel,
    required this.inviteLabel,
    required this.failureLabel,
    required this.playerIds,
    required this.playerNames,
    this.playerAvatars = const {},
    required this.botVotes,
    this.onInvite,
    this.onReady,
  });

  @override
  State<MatchWaitingRoomPanel> createState() => _MatchWaitingRoomPanelState();
}

class _MatchWaitingRoomPanelState extends State<MatchWaitingRoomPanel> {
  bool _pending = false;
  bool _failed = false;

  Future<void> _ready() async {
    if (_pending || widget.onReady == null) return;
    setState(() {
      _pending = true;
      _failed = false;
    });
    try {
      await widget.onReady!();
      if (mounted) setState(() => _pending = false);
    } catch (_) {
      if (mounted)
        setState(() {
          _pending = false;
          _failed = true;
        });
    }
  }

  String _name(String id) {
    if (id.startsWith('waiting_')) return widget.waitingLabel;
    if (id == widget.currentUid) return widget.youLabel;
    final raw = widget.playerNames[id];
    if (id.startsWith('bot_') &&
        (raw == null ||
            raw == 'bot_name_template' ||
            raw == 'player_default_name')) {
      return '${widget.botLabel} ${id.substring(4)}';
    }
    return raw == null || raw == 'player_default_name'
        ? widget.playerLabel
        : raw;
  }

  @override
  Widget build(BuildContext context) {
    final spectator = !widget.playerIds.contains(widget.currentUid);
    final humanIds = widget.playerIds
        .where((id) => !id.startsWith('waiting_') && !id.startsWith('bot_'))
        .toList();
    final readyCount = humanIds
        .where((id) => widget.botVotes[id] == true)
        .length;
    final allSeated = widget.playerIds.every(
      (id) => !id.startsWith('waiting_'),
    );
    final alreadyReady = widget.botVotes[widget.currentUid] == true;
    final detail = spectator
        ? widget.spectatorLabel
        : allSeated
        ? widget.fullLabel
        : alreadyReady
        ? widget.consentLabel
        : null;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: TableStyle.ink.withOpacity(0.96),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: TableStyle.brass.withOpacity(0.55)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.title,
              textAlign: TextAlign.center,
              style: TableStyle.label.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: TableStyle.brass,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.tag, color: TableStyle.muted, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${widget.roomLabel} ${widget.roomId}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TableStyle.detail,
                  ),
                ),
                if (!spectator && widget.onInvite != null)
                  IconButton(
                    tooltip: widget.inviteLabel,
                    icon: const Icon(
                      Icons.person_add_alt_1,
                      color: TableStyle.brass,
                    ),
                    onPressed: widget.onInvite,
                  ),
              ],
            ),
            const Divider(color: TableStyle.muted, height: 14),
            LayoutBuilder(
              builder: (context, constraints) => Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (var i = 0; i < widget.playerIds.length; i++)
                    Container(
                      width:
                          constraints.maxWidth < 340 ||
                              MediaQuery.textScalerOf(context).scale(1) > 1.4
                          ? constraints.maxWidth
                          : (constraints.maxWidth - 10) / 2,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: TableStyle.ink,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: widget.botVotes[widget.playerIds[i]] == true
                              ? const Color(0xFF78D2AF)
                              : i.isEven
                              ? TableStyle.mint
                              : TableStyle.red,
                        ),
                      ),
                      child: Row(
                        children: [
                          if (!widget.playerIds[i].startsWith('waiting_'))
                            UserAvatar(
                              user: AppUser(
                                uid: widget.playerIds[i],
                                email: '',
                                displayName: _name(widget.playerIds[i]),
                                avatarUrl:
                                    widget.playerAvatars[widget.playerIds[i]],
                              ),
                              radius: 28,
                            )
                          else
                            CircleAvatar(
                              radius: 28,
                              backgroundColor: TableStyle.felt,
                              child: Icon(
                                widget.playerIds[i].startsWith('waiting_')
                                    ? Icons.hourglass_empty
                                    : widget.playerIds[i].startsWith('bot_')
                                    ? Icons.smart_toy_outlined
                                    : Icons.person_outline,
                                color: TableStyle.ivory,
                                size: 18,
                              ),
                            ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _name(widget.playerIds[i]),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TableStyle.label,
                            ),
                          ),
                          if (widget.botVotes[widget.playerIds[i]] == true)
                            const Icon(
                              Icons.check_circle_outline,
                              color: TableStyle.brass,
                              size: 18,
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (detail != null)
              Semantics(
                liveRegion: true,
                child: Text(
                  detail,
                  textAlign: TextAlign.center,
                  style: TableStyle.detail,
                ),
              ),
            if (_failed)
              Semantics(
                liveRegion: true,
                child: Text(
                  widget.failureLabel,
                  textAlign: TextAlign.center,
                  style: TableStyle.detail.copyWith(color: TableStyle.red),
                ),
              ),
            if (!spectator && !allSeated && !alreadyReady) ...[
              const SizedBox(height: 8),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: TableStyle.brass,
                  foregroundColor: TableStyle.ink,
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: _pending ? null : _ready,
                icon: const Icon(Icons.smart_toy_outlined),
                label: Text(widget.readyLabel, textAlign: TextAlign.center),
              ),
            ],
            if (!spectator && !allSeated)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '$readyCount/${humanIds.length}',
                  textAlign: TextAlign.center,
                  style: TableStyle.detail,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
