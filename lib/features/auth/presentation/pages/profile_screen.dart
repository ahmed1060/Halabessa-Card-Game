import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:halabessa/core/theme/theme_config.dart';
import 'package:halabessa/core/widgets/user_avatar.dart';
import '../providers/auth_providers.dart';
import '../widgets/avatar_picker.dart';
import '../widgets/username_onboarding_overlay.dart';
import '../../domain/models/app_user.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);

    if (user == null) {
      return Scaffold(
        backgroundColor: ThemeConfig.darkBg,
        body: Center(child: Text('not_logged_in'.tr(), style: const TextStyle(color: Colors.white))),
      );
    }

    final winRate = user.gamesPlayed > 0 ? (user.wins / user.gamesPlayed * 100).toStringAsFixed(1) : "0.0";
    const nextLevelXP = 100; // Simplified for now
    final currentXP = user.points % 100;
    final level = (user.points / 100).floor() + 1;

    // Mandatory Username Check
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (user.username == null) {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          isDismissible: false,
          enableDrag: false,
          backgroundColor: Colors.transparent,
          builder: (context) => const UsernameOnboardingOverlay(),
        );
      }
    });

    return Scaffold(
      backgroundColor: ThemeConfig.darkBg,
      appBar: AppBar(
        title: Text('player_profile'.tr()),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              ThemeConfig.darkBg,
              Colors.black.withOpacity(0.8),
            ],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Section: Avatar & Level
              Center(
                child: Column(
                  children: [
                    Stack(
                      children: [
                        UserAvatar(user: user, radius: 60, onTap: () => _showAvatarPicker(context)),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: ThemeConfig.primaryTeal,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.edit, color: Colors.white, size: 20),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          user.displayName,
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        if (user.isAdmin)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.redAccent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'admin_badge'.tr(),
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                      ],
                    ),
                    if (user.username != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '@${user.username}',
                          style: TextStyle(
                            color: ThemeConfig.primaryTeal.withOpacity(0.9),
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: ThemeConfig.goldAccent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: ThemeConfig.goldAccent.withOpacity(0.3)),
                      ),
                      child: Text(
                        user.isAdmin ? 'admin_badge'.tr() : 'level_label'.tr(args: [level.toString()]),
                        style: const TextStyle(color: ThemeConfig.goldAccent, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (!user.isAdmin) _buildXPBar(context, currentXP, nextLevelXP),
                  ],
                ),
              ),
              const SizedBox(height: 40),

              // Statistics Section
              _buildSectionHeader(context, 'career_stats'.tr()),
              const SizedBox(height: 16),
              Row(
                children: [
                   Expanded(child: _buildStatCard(context, 'win_rate'.tr(), "$winRate%", Icons.trending_up, Colors.green)),
                   const SizedBox(width: 16),
                   Expanded(child: _buildStatCard(context, 'games_played'.tr(), user.gamesPlayed.toString(), Icons.play_circle_outline, Colors.blue)),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                   Expanded(child: _buildStatCard(context, 'best_score'.tr(), user.bestScore.toString(), Icons.emoji_events, Colors.orange)),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                   Expanded(child: _buildStatCard(context, 'stars'.tr(), user.isAdmin ? 'status_infinity'.tr() : user.points.toString(), Icons.stars, ThemeConfig.goldAccent)),
                   const SizedBox(width: 16),
                   Expanded(child: _buildStatCard(context, 'coins'.tr(), user.isAdmin ? 'status_infinity'.tr() : user.coins.toString(), Icons.monetization_on, Colors.orange)),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                   Expanded(child: _buildStatCard(context, 'diamonds'.tr(), user.isAdmin ? 'status_infinity'.tr() : user.diamonds.toString(), Icons.diamond, ThemeConfig.primaryTeal)),
                ],
              ),
              const SizedBox(height: 40),

              // Achievements Section
              _buildSectionHeader(context, 'achievements_title'.tr()),
              const SizedBox(height: 16),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildAchievementBadge(context, "achievement_welcome".tr(), Icons.handshake, Colors.blue),
                    _buildAchievementBadge(context, "achievement_winner".tr(), Icons.workspace_premium, Colors.amber),
                    _buildAchievementBadge(context, "tafweet_king".tr(), Icons.auto_awesome, Colors.purple),
                    if (user.points > 1000) _buildAchievementBadge(context, "achievement_pro".tr(), Icons.star, Colors.red),
                  ],
                ),
              ),
              const SizedBox(height: 40),

              // Auth Actions
              const Divider(color: Colors.white10),
              
              // Change Profile Actions
              ListTile(
                leading: const Icon(Icons.password, color: Colors.blueAccent),
                title: Text('change_password_btn'.tr()),
                onTap: () => _showChangePasswordDialog(context),
              ),
              ListTile(
                leading: const Icon(Icons.edit, color: Colors.blueAccent),
                title: Text('edit_display_name'.tr()),
                subtitle: Text('free_anytime'.tr(), style: const TextStyle(color: Colors.white24, fontSize: 11)),
                onTap: () => _handleDisplayNameChange(context, user),
              ),
              ListTile(
                leading: const Icon(Icons.alternate_email, color: ThemeConfig.goldAccent),
                title: Text('change_username_btn'.tr()),
                subtitle: Text(
                  user.isAdmin 
                    ? 'free_for_admin'.tr()
                    : (user.username == null 
                      ? 'first_time_free'.tr()
                      : ((user.inventory['username_change_ticket'] ?? 0) > 0 
                        ? 'use_ticket_btn'.tr() 
                        : 'no_tickets_message'.tr())),
                  style: TextStyle(
                    color: (user.isAdmin || user.username == null || (user.inventory['username_change_ticket'] ?? 0) > 0) 
                      ? ThemeConfig.goldAccent 
                      : Colors.white30,
                    fontSize: 12,
                  ),
                ),
                onTap: () => _handleUsernameChange(context, user),
              ),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.redAccent),
                title: Text('log_out'.tr(), style: const TextStyle(color: Colors.redAccent)),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: ThemeConfig.darkBg,
                      title: Text('log_out'.tr(), style: const TextStyle(color: Colors.white)),
                      content: Text('log_out_confirm'.tr(), style: const TextStyle(color: Colors.white70)),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx), child: Text('cancel'.tr())),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                          onPressed: () {
                            ref.read(authRepositoryProvider).signOut();
                            Navigator.pop(ctx);
                            Navigator.pop(context);
                          },
                          child: Text('log_out'.tr()),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  void _showAvatarPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AvatarPicker(),
    );
  }

  void _showChangePasswordDialog(BuildContext context) {
    final passwordController = TextEditingController();
    final confirmController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: ThemeConfig.darkBg,
        title: Text('change_password_btn'.tr(), style: const TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: passwordController,
              decoration: InputDecoration(labelText: 'new_password_label'.tr()),
              obscureText: true,
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: confirmController,
              decoration: InputDecoration(labelText: 'confirm_password_label'.tr()),
              obscureText: true,
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('cancel'.tr())),
          ElevatedButton(
            onPressed: () async {
              if (passwordController.text != confirmController.text) {
                 ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('passwords_no_match'.tr())));
                 return;
              }
              try {
                await ref.read(authRepositoryProvider).updatePassword(passwordController.text);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('password_updated_success'.tr())));
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                }
              }
            },
            child: Text('update'.tr()),
          ),
        ],
      ),
    );
  }

  Future<void> _handleDisplayNameChange(BuildContext context, AppUser user) async {
    final nameController = TextEditingController(text: user.displayName);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: ThemeConfig.darkBg,
        title: Text('edit_display_name'.tr(), style: const TextStyle(color: Colors.white)),
        content: TextField(
          controller: nameController,
          maxLength: 20,
          decoration: InputDecoration(
            labelText: 'display_name_label'.tr(),
            counterText: "", // Hide counter for cleaner feel if preferred, or keep it.
          ),
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('cancel'.tr())),
          ElevatedButton(
            onPressed: () async {
              final newName = nameController.text.trim();
              if (newName.isEmpty || newName == user.displayName) return;
              try {
                await ref.read(authRepositoryProvider).updateProfile(displayName: newName);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('profile_updated_success'.tr())));
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                }
              }
            },
            child: Text('update'.tr()),
          ),
        ],
      ),
    );
  }

  Future<void> _handleUsernameChange(BuildContext context, AppUser user) async {
    final hasTicket = user.isAdmin || user.username == null || (user.inventory['username_change_ticket'] ?? 0) > 0;
    
    if (!hasTicket) {
      _showTicketRequiredDialog(context);
      return;
    }

    final usernameController = TextEditingController(text: user.username);
    String? errorText;

    showDialog(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: ThemeConfig.darkBg,
          title: Text('change_username_btn'.tr(), style: const TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: usernameController,
                maxLength: 20,
                decoration: InputDecoration(
                  labelText: 'username_label'.tr(),
                  hintText: 'e.g. ahmed123',
                  prefixText: '@',
                  errorText: errorText,
                  counterText: "",
                ),
                style: const TextStyle(color: Colors.white),
                onChanged: (val) async {
                  if (val.length < 3) {
                    setDialogState(() => errorText = 'min_3_chars'.tr());
                    return;
                  }
                  if (!RegExp(r'^[a-zA-Z0-9_.]+$').hasMatch(val)) {
                    setDialogState(() => errorText = 'invalid_chars'.tr());
                    return;
                  }
                  final available = await ref.read(authRepositoryProvider).isUsernameAvailable(val, currentUid: user.uid);
                  setDialogState(() => errorText = available ? null : 'username_taken'.tr());
                },
              ),
              const SizedBox(height: 12),
              Text(
                user.isAdmin ? 'free_for_admin'.tr() : 'consumes_ticket_warning'.tr(),
                style: const TextStyle(color: Colors.white30, fontSize: 11),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text('cancel'.tr())),
            ElevatedButton(
              onPressed: errorText != null || usernameController.text.trim() == user.username ? null : () async {
                try {
                  await ref.read(authRepositoryProvider).updateProfile(username: usernameController.text.trim());
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('username_updated_success'.tr())));
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                  }
                }
              },
              child: Text('update'.tr()),
            ),
          ],
        ),
      ),
    );
  }

  void _showTicketRequiredDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: ThemeConfig.darkBg,
        title: Text('username_change_ticket'.tr(), style: const TextStyle(color: Colors.white)),
        content: Text('no_tickets_message'.tr(), style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('cancel'.tr())),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/store');
            },
            child: Text('buy_ticket_btn'.tr()),
          ),
        ],
      ),
    );
  }

  Widget _buildXPBar(BuildContext context, int current, int total) {
    double progress = (current / total).clamp(0.0, 1.0);
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.white10,
            valueColor: const AlwaysStoppedAnimation<Color>(ThemeConfig.goldAccent),
            minHeight: 10,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'xp_to_next_level'.tr(args: [current.toString(), total.toString()]),
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color.withOpacity(0.7), size: 28),
          const SizedBox(height: 16),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementBadge(BuildContext context, String title, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 16),
      width: 100,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [color.withOpacity(0.2), color.withOpacity(0.05)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: color.withOpacity(0.5)),
            ),
            child: Icon(icon, color: color, size: 32),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
