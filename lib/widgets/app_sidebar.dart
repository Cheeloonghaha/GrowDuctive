import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../theme/app_colors.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/user_preferences_viewmodel.dart';
import '../models/user_profile_model.dart';

typedef SidebarNavigateCallback = void Function(int index);

class AppSidebar extends StatelessWidget {
  const AppSidebar({
    super.key,
    required this.selectedIndex,
    required this.onNavigate,
  });

  final int selectedIndex;
  final SidebarNavigateCallback onNavigate;

  static const _navBlue = Color(0xFF103A8A);
  static const _navBg = Color(0xFFEAF3FF);

  bool _isDarkTheme(String? theme) => theme == 'dark';

  @override
  Widget build(BuildContext context) {
    final authVM = Provider.of<AuthViewModel>(context, listen: false);
    final prefsVM = Provider.of<UserPreferencesViewModel>(context, listen: false);

    return Drawer(
      width: 320,
      child: SafeArea(
        child: StreamBuilder<UserProfileModel?>(
          stream: authVM.currentUserProfileStream,
          builder: (context, profileSnap) {
            final profile = profileSnap.data;
            final avatarUrl =
                profile?.profileImageUrl ?? authVM.currentUser?.photoURL;
            final username = profile?.username ?? authVM.currentUser?.displayName ?? 'User';
            final bio = profile?.bio;

            return StreamBuilder(
              stream: prefsVM.preferencesStream,
              builder: (context, prefsSnap) {
                final prefs = prefsSnap.data;
                final isDark = _isDarkTheme(prefs?.theme);

                final bg = isDark ? const Color(0xFF0B0F19) : Colors.white;
                final fg = isDark ? Colors.white : Colors.black87;
                final subFg = isDark ? Colors.white.withValues(alpha: 0.65) : Colors.grey.shade700;
                final cardBorder = isDark ? Colors.white.withValues(alpha: 0.10) : Colors.grey.shade200;
                final logoutBg = isDark ? Colors.white.withValues(alpha: 0.06) : Colors.grey.shade200;
                final logoutFg = isDark ? Colors.white : Colors.black87;
                final logoutBorder = isDark ? Colors.white.withValues(alpha: 0.18) : Colors.grey.shade300;

                return Container(
                  width: double.infinity,
                  color: Colors.transparent,
                  child: Container(
                    margin: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Top row: avatar (left) + close (right)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 22,
                                backgroundColor: Colors.grey.shade300,
                                backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                                    ? NetworkImage(avatarUrl)
                                    : null,
                                child: (avatarUrl == null || avatarUrl.isEmpty)
                                    ? const Icon(Icons.person, size: 22)
                                    : null,
                              ),
                              const Spacer(),
                              IconButton(
                                onPressed: () => Navigator.of(context).pop(),
                                icon: Icon(Icons.close, color: fg),
                              ),
                            ],
                          ),
                        ),

                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            username,
                            style: TextStyle(
                              color: fg,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (bio != null && bio.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              bio,
                              style: TextStyle(
                                color: subFg,
                                fontSize: 13,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],

                        const SizedBox(height: 16),

                        // Theme card
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.06)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: cardBorder),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Theme',
                                  style: TextStyle(
                                    color: subFg,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _themeButton(
                                        context: context,
                                        isDark: isDark,
                                        label: 'Light',
                                        selected: prefs?.theme == 'light' || prefs?.theme == 'system',
                                        icon: Icons.wb_sunny_rounded,
                                        onTap: () => prefsVM.updateTheme('light'),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _themeButton(
                                        context: context,
                                        isDark: isDark,
                                        label: 'Dark',
                                        selected: prefs?.theme == 'dark',
                                        icon: Icons.nightlight_round_rounded,
                                        onTap: () => prefsVM.updateTheme('dark'),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 18),

                        // Navigation
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Column(
                            children: [
                              _navItem(
                                context: context,
                                title: 'Calendar',
                                icon: Icons.calendar_month_rounded,
                                index: 0,
                                isSelected: selectedIndex == 0,
                                fg: fg,
                                onTap: () => _handleNav(context, 0),
                              ),
                              _navItem(
                                context: context,
                                title: 'Tasks',
                                icon: Icons.task_alt_rounded,
                                index: 1,
                                isSelected: selectedIndex == 1,
                                fg: fg,
                                onTap: () => _handleNav(context, 1),
                              ),
                              _navItem(
                                context: context,
                                title: 'Focus Timer',
                                icon: Icons.timer_rounded,
                                index: 2,
                                isSelected: selectedIndex == 2,
                                fg: fg,
                                onTap: () => _handleNav(context, 2),
                              ),
                              _navItem(
                                context: context,
                                title: 'Analytics',
                                icon: Icons.bar_chart_rounded,
                                index: 3,
                                isSelected: selectedIndex == 3,
                                fg: fg,
                                onTap: () => _handleNav(context, 3),
                              ),
                              _navItem(
                                context: context,
                                title: 'Profile/User Preference',
                                icon: Icons.person_rounded,
                                index: 4,
                                isSelected: selectedIndex == 4,
                                fg: fg,
                                onTap: () => _handleNav(context, 4),
                              ),
                            ],
                          ),
                        ),

                        const Spacer(),

                        // Logout button
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                              backgroundColor: logoutBg,
                              foregroundColor: logoutFg,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                elevation: 0,
                                side: BorderSide(
                                color: logoutBorder,
                                ),
                              ),
                              icon: const Icon(Icons.logout),
                              label: const Text('Log out'),
                              onPressed: () async {
                                final shouldLogout = await showDialog<bool>(
                                  context: context,
                                  barrierColor: Colors.black.withOpacity(0.5),
                                  builder: (ctx) => Dialog(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Container(
                                      constraints: const BoxConstraints(
                                        maxWidth: 300,
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(20),
                                            decoration: const BoxDecoration(
                                              color: Colors.black,
                                              borderRadius: BorderRadius.only(
                                                topLeft: Radius.circular(16),
                                                topRight: Radius.circular(16),
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                const Icon(
                                                  Icons.logout,
                                                  color: Colors.white,
                                                  size: 24,
                                                ),
                                                const SizedBox(width: 12),
                                                const Expanded(
                                                  child: Text(
                                                    "Logout",
                                                    style: TextStyle(
                                                      fontSize: 20,
                                                      fontWeight: FontWeight.bold,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ),
                                                GestureDetector(
                                                  onTap: () =>
                                                      Navigator.pop(ctx, false),
                                                  child: const Icon(
                                                    Icons.close,
                                                    color: Colors.white,
                                                    size: 24,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.all(20),
                                            child: Column(
                                              children: [
                                                Text(
                                                  "Are you sure you want to logout?",
                                                  style: TextStyle(
                                                    fontSize: 15,
                                                    color: Colors.grey[800],
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                  textAlign: TextAlign.center,
                                                ),
                                                const SizedBox(height: 20),
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.end,
                                                  children: [
                                                    OutlinedButton(
                                                      onPressed: () =>
                                                          Navigator.pop(ctx, false),
                                                      style: OutlinedButton.styleFrom(
                                                        side: BorderSide(
                                                          color: Colors.grey[400]!,
                                                        ),
                                                        shape: RoundedRectangleBorder(
                                                          borderRadius: BorderRadius.circular(8),
                                                        ),
                                                        padding: const EdgeInsets.symmetric(
                                                          horizontal: 20,
                                                          vertical: 12,
                                                        ),
                                                      ),
                                                      child: Text(
                                                        "Cancel",
                                                        style: TextStyle(
                                                          color: Colors.grey[700],
                                                          fontWeight: FontWeight.w600,
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 12),
                                                    ElevatedButton(
                                                      onPressed: () =>
                                                          Navigator.pop(ctx, true),
                                                      style: ElevatedButton.styleFrom(
                                                        backgroundColor: Colors.red[600],
                                                        foregroundColor: Colors.white,
                                                        shape: RoundedRectangleBorder(
                                                          borderRadius:
                                                              BorderRadius.circular(8),
                                                        ),
                                                        padding: const EdgeInsets.symmetric(
                                                          horizontal: 20,
                                                          vertical: 12,
                                                        ),
                                                      ),
                                                      child: const Text(
                                                        "Logout",
                                                        style: TextStyle(
                                                          fontWeight: FontWeight.w600,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );

                                if (shouldLogout != true) return;

                                Navigator.of(context).pop(); // close drawer
                                await authVM.signOut();
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  void _handleNav(BuildContext context, int index) {
    Navigator.of(context).pop();
    onNavigate(index);
  }

  Widget _navItem({
    required BuildContext context,
    required String title,
    required IconData icon,
    required int index,
    required bool isSelected,
    required Color fg,
    required VoidCallback onTap,
  }) {
    final textColor = isSelected ? _navBlue : fg.withValues(alpha: 0.85);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: isSelected
                ? BoxDecoration(
                    color: AppColors.interactive.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  )
                : null,
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: textColor,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      height: 1.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _themeButton({
    required BuildContext context,
    required bool isDark,
    required String label,
    required bool selected,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final active = selected;
    final bg = active
        ? (_navBg)
        : (isDark ? Colors.white.withValues(alpha: 0.06) : Colors.grey.withValues(alpha: 0.08));
    final fg = active ? _navBlue : (isDark ? Colors.white.withValues(alpha: 0.82) : Colors.black87);

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active ? Colors.transparent : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade300),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: fg),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: fg,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

