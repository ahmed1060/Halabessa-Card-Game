import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/account_deletion_service.dart';
import '../services/supabase_backend_service.dart';
import '../../features/game/presentation/widgets/table_style.dart';
import 'lantern_page_frame.dart';
import 'lantern_panel.dart';
import '../../features/auth/presentation/pages/auth_screen.dart';

class AccountDeletionScreen extends StatefulWidget {
  final User? Function()? currentUser;
  final Future<Map<String, dynamic>> Function(DeletionReceipt)? loadStatus;
  const AccountDeletionScreen({super.key, this.currentUser, this.loadStatus});
  @override
  State<AccountDeletionScreen> createState() => _AccountDeletionScreenState();
}

class _AccountDeletionScreenState extends State<AccountDeletionScreen> {
  final _password = TextEditingController();
  bool _confirmed = false;
  bool _busy = false;
  bool _canClose = false;
  String _status = 'loading';
  String? _error;
  String? _provider;
  Timer? _poll;
  User? get _user => widget.currentUser == null
      ? FirebaseAuth.instance.currentUser
      : widget.currentUser!();
  String _text(String en, String ar) =>
      Localizations.localeOf(context).languageCode == 'ar' ? ar : en;
  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
  }

  @override
  void dispose() {
    _poll?.cancel();
    _password.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (_busy) return;
    _poll?.cancel();
    try {
      final receipt = await DeletionReceipt.load();
      final result = receipt == null
          ? {'status': 'not_found'}
          : await (widget.loadStatus ?? AccountDeletionService.status)(receipt);
      if (!mounted || _busy) return;
      final status = result['status'] as String?;
      if (![
        'not_found',
        'pending',
        'complete',
        'needs_apple_authorization',
      ].contains(status)) {
        throw const SupabaseBackendException('backend_unavailable');
      }
      setState(() {
        _status = status!;
        _error = null;
        _canClose =
            status == 'complete' || (status == 'not_found' && receipt == null);
      });
      if (status == 'pending') {
        _poll = Timer(const Duration(seconds: 30), () => unawaited(_refresh()));
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = _text(
            'Could not check the request. Retry when you are online.',
            'مش قادرين نراجع الطلب. حاول تاني لما الاتصال يرجع.',
          ),
        );
      }
    }
  }

  Future<void> _submit() async {
    final user = _user;
    if (user == null) return;
    setState(() {
      _busy = true;
      _canClose = false;
      _error = null;
    });
    try {
      final providers = user.providerData.map((p) => p.providerId).toList();
      // Any linked Apple account must revoke Apple, even if Google/password is
      // also linked. An unrelated provider must not bypass that requirement.
      final provider = providers.contains('apple.com')
          ? 'apple.com'
          : _provider ?? (user.isAnonymous ? 'guest' : providers.first);
      final apple = await AccountDeletionService.reauthenticate(
        user,
        provider,
        password: _password.text,
      );
      final result = await AccountDeletionService.submit(user, apple);
      _password.clear();
      final status = result['status'];
      if (status == 'pending' || status == 'complete') {
        // A local sign-out error cannot undo a durable deletion request or
        // hide its status. The server independently revokes the identity.
        if (FirebaseAuth.instance.currentUser?.uid == user.uid) {
          try {
            await FirebaseAuth.instance.signOut();
          } catch (_) {
            /* Status remains available. */
          }
        }
        if (!mounted) return;
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/account/delete', (_) => false);
        return;
      }
      if (!mounted) return;
      setState(() => _status = 'needs_apple_authorization');
    } catch (error) {
      _password.clear();
      if (mounted) {
        final code = error is SupabaseBackendException
            ? error.code
            : error is FirebaseAuthException
            ? error.code
            : '';
        setState(
          () => _error = code == 'protected_account'
              ? _text(
                  'The primary publisher/admin account cannot be deleted here.',
                  'حساب المسؤول أو الناشر الأساسي مش ممكن يتحذف من هنا.',
                )
              : code == 'deletion_receipt_conflict' ||
                    code == 'deletion_account_changed'
              ? _text(
                  'This request belongs to a different account. No other account was deleted.',
                  'الطلب ده يخص حساب مختلف. مفيش حساب تاني اتحذف.',
                )
              : code == 'apple_authorization_unavailable' ||
                    code == 'unsupported_reauthentication'
              ? _text(
                  'This provider could not verify deletion on this device. Contact weirdpuzz@gmail.com for help.',
                  'مش قادرين نأكد الحذف من وسيلة الدخول دي على الجهاز. تواصل مع weirdpuzz@gmail.com.',
                )
              : _text(
                  'Verification or submission failed. Any saved receipt is retained; check status before retrying.',
                  'تأكيد الهوية أو إرسال الطلب فشل. بنحتفظ بأي إيصال محفوظ؛ راجع الحالة قبل المحاولة تاني.',
                ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _close() async {
    // Only an unaccepted request or completed deletion can be forgotten. Do not
    // strand a pending request just because the user's Firebase session ended.
    if (!_canClose) return;
    final receipt = await DeletionReceipt.load();
    if (_status == 'complete' && _user?.uid == receipt?.uid && _user != null) {
      try {
        await FirebaseAuth.instance.signOut();
      } catch (_) {
        if (mounted) {
          setState(
            () => _error = _text(
              'Could not sign out. Try again.',
              'مش قادرين نسجل الخروج. حاول تاني.',
            ),
          );
        }
        return;
      }
    }
    await DeletionReceipt.forget();
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    final providers =
        user?.providerData.map((p) => p.providerId).toList() ?? [];
    final requiresApple = providers.contains('apple.com');
    final canSubmit =
        (_status == 'not_found' || _status == 'needs_apple_authorization') &&
        user != null;
    final title = _text('Delete my account', 'حذف حسابي');
    final detail = switch (_status) {
      'pending' => _text(
        'Request received. Your session will be blocked. Cleanup continues securely on the server, even if you close the app. This is not yet a completion confirmation.',
        'استلمنا طلبك وجلسة حسابك هتتوقف. تنظيف بياناتك بيكمل على الخادم حتى لو قفلت اللعبة. الحذف لسه ما اكتملش.',
      ),
      'complete' => _text(
        'Account deletion is complete. Your identity, profile, avatar and owned data were removed. Shared match history was anonymized. Security tombstones and de-identified reward receipts remain; operational logs/backups follow service retention.',
        'حذف الحساب اكتمل. هويتك وملفك وصورتك وبياناتك الشخصية اتحذفوا، وسجل المباريات المشتركة بقى من غير هويتك. بنحتفظ بعلامة أمان تمنع الجلسات القديمة وإيصالات مكافآت بدون هويتك؛ السجلات والنسخ الاحتياطية بتتبع مدة احتفاظ الخدمات.',
      ),
      'needs_apple_authorization' => _text(
        'Your request is saved, but Apple authorization still needs revocation. Verify with Apple again. Deletion will not be called complete before this succeeds.',
        'طلبك محفوظ، لكن لسه لازم نلغي تصريح Apple. أكد هويتك بـ Apple تاني. مش هنعتبر الحذف مكتمل قبل نجاح الخطوة دي.',
      ),
      'loading' => _text('Checking saved request…', 'بنراجع الطلب المحفوظ…'),
      _ => _text(
        'Permanently remove your login, profile, coins, inventory, avatar and authored messages. You will leave your matches; other players and their balances will be preserved. This cannot be undone.',
        'هتحذف تسجيل دخولك وملفك والعملات والمقتنيات والصورة ورسائلك نهائيًا. هتخرج من مبارياتك مع الحفاظ على اللاعبين التانيين وأرصدتهم. مش ممكن نرجّع بياناتك بعد الحذف.',
      ),
    };
    return PopScope(
      canPop: _canClose && !_busy,
      child: LanternPageFrame(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            toolbarHeight: 110,
            automaticallyImplyLeading: _canClose && !_busy,
            centerTitle: true,
            title: LanternPageTitle(title: title),
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  LanternPanel(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Icon(
                          _status == 'complete'
                              ? Icons.check_circle_outline
                              : Icons.person_remove_outlined,
                          color: TableStyle.ink,
                          size: 44,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          detail,
                          style: TableStyle.label.copyWith(
                            color: TableStyle.ink,
                          ),
                        ),
                        if (canSubmit) ...[
                          const SizedBox(height: 20),
                          if (!requiresApple && providers.length > 1)
                            DropdownButtonFormField<String>(
                              initialValue: _provider ?? providers.first,
                              style: TableStyle.label.copyWith(
                                color: TableStyle.ink,
                              ),
                              dropdownColor: TableStyle.ivory,
                              iconEnabledColor: TableStyle.ink,
                              decoration: InputDecoration(
                                labelStyle: TableStyle.label.copyWith(
                                  color: TableStyle.ink,
                                ),
                                labelText: _text(
                                  'Verify with',
                                  'تأكيد الهوية بـ',
                                ),
                              ),
                              items: providers
                                  .map(
                                    (p) => DropdownMenuItem(
                                      value: p,
                                      child: Text(p),
                                    ),
                                  )
                                  .toList(),
                              onChanged: _busy
                                  ? null
                                  : (value) =>
                                        setState(() => _provider = value),
                            ),
                          if (!requiresApple &&
                              (_provider ??
                                      (providers.isEmpty
                                          ? 'guest'
                                          : providers.first)) ==
                                  'password')
                            TextField(
                              controller: _password,
                              style: TableStyle.label.copyWith(
                                color: TableStyle.ink,
                              ),
                              cursorColor: TableStyle.ink,
                              obscureText: true,
                              enableSuggestions: false,
                              autocorrect: false,
                              decoration: InputDecoration(
                                labelStyle: TableStyle.label.copyWith(
                                  color: TableStyle.ink,
                                ),
                                labelText: _text(
                                  'Current password',
                                  'كلمة السر الحالية',
                                ),
                              ),
                            ),
                          Material(
                            color: Colors.transparent,
                            child: CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              activeColor: TableStyle.ink,
                              checkColor: TableStyle.ivory,
                              side: const BorderSide(
                                color: TableStyle.ink,
                                width: 1.5,
                              ),
                              value: _confirmed,
                              title: Text(
                                _text(
                                  'I understand this permanently deletes my account.',
                                  'أنا فاهم إن حسابي هيتحذف نهائيًا.',
                                ),
                                style: TableStyle.label.copyWith(
                                  color: TableStyle.ink,
                                ),
                              ),
                              onChanged: _busy
                                  ? null
                                  : (value) => setState(
                                      () => _confirmed = value == true,
                                    ),
                            ),
                          ),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: TableStyle.ink,
                              foregroundColor: TableStyle.ivory,
                              disabledBackgroundColor: TableStyle.ink
                                  .withValues(alpha: 0.10),
                              disabledForegroundColor: TableStyle.ink
                                  .withValues(alpha: 0.75),
                              minimumSize: const Size(48, 52),
                            ),
                            onPressed: _confirmed && !_busy ? _submit : null,
                            icon: const Icon(Icons.person_remove_outlined),
                            label: Text(
                              _busy
                                  ? _text('Verifying…', 'بنأكد الهوية…')
                                  : requiresApple
                                  ? _text(
                                      'Verify with Apple and delete',
                                      'تأكيد بـ Apple وحذف الحساب',
                                    )
                                  : title,
                            ),
                          ),
                        ],
                        if ((_status == 'not_found' ||
                                _status == 'needs_apple_authorization') &&
                            user == null) ...[
                          Text(
                            _text(
                              'Sign in to the account you want to delete first. You can also contact weirdpuzz@gmail.com.',
                              'سجّل الدخول للحساب اللي عايز تحذفه الأول، أو تواصل مع weirdpuzz@gmail.com.',
                            ),
                            style: TableStyle.label.copyWith(
                              color: TableStyle.ink,
                            ),
                          ),
                          TextButton(
                            style: TextButton.styleFrom(
                              foregroundColor: TableStyle.ink,
                            ),
                            onPressed: _busy
                                ? null
                                : () async {
                                    await Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) => const AuthScreen(),
                                      ),
                                    );
                                    if (mounted) await _refresh();
                                  },
                            child: Text(
                              _text(
                                'Sign in to recover this request',
                                'تسجيل الدخول لاستكمال الطلب',
                              ),
                            ),
                          ),
                        ],
                        if (_error != null) ...[
                          const SizedBox(height: 16),
                          Text(
                            _error!,
                            style: TableStyle.label.copyWith(
                              color: TableStyle.ink,
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        OutlinedButton(
                          onPressed: _busy ? null : _refresh,
                          child: Text(_text('Check status', 'مراجعة الحالة')),
                        ),
                        if (_canClose)
                          TextButton(
                            style: TextButton.styleFrom(
                              foregroundColor: TableStyle.ink,
                            ),
                            onPressed: _busy ? null : _close,
                            child: Text(
                              _status == 'complete'
                                  ? _text(
                                      'Back to sign-in',
                                      'رجوع لتسجيل الدخول',
                                    )
                                  : _text('Cancel', 'إلغاء'),
                            ),
                          ),
                        const SizedBox(height: 16),
                        const SelectableText(
                          'WeirdPuzz · weirdpuzz@gmail.com',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: TableStyle.ink),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
