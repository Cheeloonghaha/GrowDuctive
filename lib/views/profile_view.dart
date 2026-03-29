import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_profile_model.dart';
import '../navigation/app_page_routes.dart';
import '../theme/growductive_chrome.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/user_preferences_viewmodel.dart';
import 'profile_edit_view.dart';

/// Deep navy header + gold accents (reference mockup).
const Color _profileNavyTop = Color(0xFF0F2347);
const Color _profileNavyMid = Color(0xFF152B55);
const Color _profileGold = Color(0xFFD4AF37);
const Color _profileGoldInner = Color(0xFFE8C76A);

class ProfileView extends StatelessWidget {
  const ProfileView({super.key, this.onQuit});

  /// When embedded in [MainShell], switches back to the first tab (e.g. Calendar).
  final VoidCallback? onQuit;

  @override
  Widget build(BuildContext context) {
    final authVM = Provider.of<AuthViewModel>(context);

    return Scaffold(
      backgroundColor: context.chrome.scaffoldBackground,
      body: StreamBuilder<UserProfileModel?>(
        stream: authVM.currentUserProfileStream,
        builder: (context, snapshot) {
          final profile = snapshot.data;
          final username = profile?.username ?? authVM.currentUser?.displayName ?? 'User';
          final email = profile?.email ?? authVM.currentUser?.email ?? '';
          final bio = profile?.bio;
          final profileImageUrl = profile?.profileImageUrl ?? authVM.currentUser?.photoURL;
          final subtitle = (bio != null && bio.trim().isNotEmpty)
              ? bio.trim()
              : (email.isNotEmpty ? email : '@$username');

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      height: 320,
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [_profileNavyTop, _profileNavyMid],
                        ),
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          CustomPaint(painter: _ProfileWavePainter()),
                          Positioned(
                            right: -40,
                            top: 40,
                            child: CircleAvatar(
                              radius: 80,
                              backgroundColor: Colors.white.withValues(alpha: 0.04),
                            ),
                          ),
                          Positioned(
                            left: -30,
                            bottom: 60,
                            child: CircleAvatar(
                              radius: 55,
                              backgroundColor: Colors.white.withValues(alpha: 0.03),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                IconButton(
                                  onPressed: () {
                                    if (onQuit != null) {
                                      onQuit!();
                                    } else {
                                      Navigator.maybePop(context);
                                    }
                                  },
                                  style: IconButton.styleFrom(
                                    foregroundColor: Colors.white,
                                  ),
                                  tooltip: 'Quit',
                                  icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                                ),
                                const Expanded(
                                  child: Text(
                                    'Your Profile',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 48),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _GoldRingAvatar(
                              radius: 48,
                              profileImageUrl: profileImageUrl,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              username,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 32),
                              child: Text(
                                subtitle,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400,
                                  color: Colors.white.withValues(alpha: 0.75),
                                  height: 1.35,
                                ),
                              ),
                            ),
                            const SizedBox(height: 100),
                          ],
                        ),
                      ),
                    ),
                    // In the header Stack so taps aren’t swallowed by the first sliver
                    // when the next sliver is translated upward (overlap).
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 12,
                      child: Builder(
                        builder: (ctx) {
                          final scheme = Theme.of(ctx).colorScheme;
                          final isDark = scheme.brightness == Brightness.dark;
                          final fg = scheme.onSurface;
                          return OutlinedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                fadeSlideRoute(const ProfileEditView()),
                              );
                            },
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              side: BorderSide(
                                color: isDark
                                    ? scheme.outline.withValues(alpha: 0.55)
                                    : Colors.grey[400]!,
                              ),
                              backgroundColor:
                                  isDark ? scheme.surfaceContainerHigh : Colors.white,
                              foregroundColor: fg,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.edit_outlined, size: 20, color: fg),
                                const SizedBox(width: 8),
                                Text(
                                  'Edit profile',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: fg,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              SliverToBoxAdapter(
                child: Transform.translate(
                  offset: const Offset(0, -72),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 84),
                        const SizedBox(height: 16),
                        Builder(
                          builder: (ctx) {
                            final scheme = Theme.of(ctx).colorScheme;
                            final isDark = scheme.brightness == Brightness.dark;
                            final titleColor = context.chrome.navBlue;
                            return Material(
                              elevation: 8,
                              shadowColor:
                                  Colors.black.withValues(alpha: isDark ? 0.38 : 0.12),
                              color: isDark ? scheme.surfaceContainerHigh : Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(28),
                                side: isDark
                                    ? BorderSide(
                                        color: scheme.outline.withValues(alpha: 0.38),
                                      )
                                    : BorderSide.none,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 34,
                                          height: 34,
                                          decoration: BoxDecoration(
                                            color: _profileNavyMid,
                                            borderRadius: BorderRadius.circular(11),
                                          ),
                                          child: const Icon(Icons.tune_rounded,
                                              color: Colors.white, size: 19),
                                        ),
                                        const SizedBox(width: 11),
                                        Text(
                                          'User preferences',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: titleColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 14),
                                    const _ProfilePreferencesForm(embedded: true),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: () => _handleLogout(context, authVM),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red[600],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 0,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.logout, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Logout',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _handleLogout(BuildContext context, AuthViewModel authVM) async {
    // Show confirmation dialog
    final shouldLogout = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (dialogContext) {
        final scheme = Theme.of(dialogContext).colorScheme;
        return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 300),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: scheme.inverseSurface,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.logout, color: scheme.onInverseSurface, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "Logout",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: scheme.onInverseSurface,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(dialogContext, false),
                      child: Icon(Icons.close, color: scheme.onInverseSurface, size: 24),
                    ),
                  ],
                ),
              ),
              // Content
              Container(
                width: double.infinity,
                color: scheme.surfaceContainerHigh,
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(
                      "Are you sure you want to logout?",
                      style: TextStyle(
                        fontSize: 15,
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    // Actions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: () => Navigator.pop(dialogContext, false),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: scheme.outline.withValues(alpha: 0.65),
                            ),
                            foregroundColor: scheme.onSurface,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          ),
                          child: const Text(
                            "Cancel",
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(dialogContext, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: scheme.error,
                            foregroundColor: scheme.onError,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
      );
      },
    );

    if (shouldLogout == true) {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (loadingCtx) => Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(
              Theme.of(loadingCtx).colorScheme.primary,
            ),
          ),
        ),
      );

      // Perform logout
      await authVM.signOut();

      // Close loading dialog
      if (context.mounted) {
        Navigator.pop(context);
      }

      // Show success message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Logged out successfully"),
            backgroundColor: Colors.black,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }

      // AuthWrapper will automatically detect logout and show LoginView
    }
  }
}

class _ProfilePreferencesForm extends StatefulWidget {
  const _ProfilePreferencesForm({this.embedded = true});

  /// When true, preferences are shown in the profile page (no sheet [Navigator.pop] after save).
  final bool embedded;

  @override
  State<_ProfilePreferencesForm> createState() => _ProfilePreferencesFormState();
}

class _ProfilePreferencesFormState extends State<_ProfilePreferencesForm> {
  int _breakDuration = 10;
  int _breakAfter = 0; // 0 = after every task
  late final TextEditingController _breakDurationController;
  late final TextEditingController _breakAfterController;
  late final TextEditingController _defaultReminderController;
  late final TextEditingController _quietHoursStartController;
  late final TextEditingController _quietHoursEndController;
  bool _remindersEnabled = true;
  int _defaultReminderMinutesBefore = 15;
  int? _quietHoursStartMinutes;
  int? _quietHoursEndMinutes;
  int _weekStartsOn = 1; // 1 = Monday, 7 = Sunday
  String _theme = 'light'; // 'light' | 'dark'
  bool _timerSoundEnabled = true;
  bool _timerVibrationEnabled = true;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _breakDurationController = TextEditingController(text: _breakDuration.toString());
    _breakAfterController = TextEditingController(text: '');
    _defaultReminderController =
        TextEditingController(text: _defaultReminderMinutesBefore.toString());
    _quietHoursStartController = TextEditingController(text: '');
    _quietHoursEndController = TextEditingController(text: '');
    final prefsVM = Provider.of<UserPreferencesViewModel>(context, listen: false);
    prefsVM.fetchPreferences().then((prefs) {
      if (!mounted || prefs == null) {
        if (mounted) {
          setState(() => _loading = false);
        }
        return;
      }
      setState(() {
        _breakDuration = prefs.breakDurationMinutes;
        _breakAfter = prefs.breakAfterTaskMinutes;
        _breakDurationController.text = _breakDuration.toString();
        _breakAfterController.text = _breakAfter <= 0 ? '' : _breakAfter.toString();
        _remindersEnabled = prefs.remindersEnabled;
        _defaultReminderMinutesBefore = prefs.defaultReminderMinutesBefore;
        _quietHoursStartMinutes = prefs.quietHoursStartMinutes;
        _quietHoursEndMinutes = prefs.quietHoursEndMinutes;
        _defaultReminderController.text = _defaultReminderMinutesBefore.toString();
        _quietHoursStartController.text = _quietHoursStartMinutes?.toString() ?? '';
        _quietHoursEndController.text = _quietHoursEndMinutes?.toString() ?? '';
        _weekStartsOn = prefs.weekStartsOn;
        _theme = _normalizeThemeChoice(prefs.theme);
        _timerSoundEnabled = prefs.timerSoundEnabled;
        _timerVibrationEnabled = prefs.timerVibrationEnabled;
        _loading = false;
      });
    });
  }

  @override
  void dispose() {
    _breakDurationController.dispose();
    _breakAfterController.dispose();
    _defaultReminderController.dispose();
    _quietHoursStartController.dispose();
    _quietHoursEndController.dispose();
    super.dispose();
  }

  /// Maps stored values (e.g. legacy `system`) to a valid light/dark choice for the UI.
  String _normalizeThemeChoice(String theme) =>
      theme == 'dark' ? 'dark' : 'light';

  InputDecoration _fieldDecoration(
    BuildContext context, {
    required String labelText,
    String? hintText,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;
    final radius = BorderRadius.circular(9);
    OutlineInputBorder outline(Color color, [double w = 1]) => OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: color, width: w),
        );
    return InputDecoration(
      isDense: true,
      filled: isDark,
      fillColor: isDark ? scheme.surfaceContainerHighest : null,
      labelText: labelText,
      hintText: hintText,
      labelStyle: TextStyle(
        fontSize: 14,
        color: isDark ? scheme.onSurfaceVariant : Colors.grey.shade800,
      ),
      floatingLabelStyle: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: scheme.primary,
      ),
      hintStyle: TextStyle(
        fontSize: 13,
        color: scheme.onSurfaceVariant.withValues(alpha: 0.9),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      enabledBorder: outline(
        isDark ? scheme.outline.withValues(alpha: 0.5) : Colors.grey.shade400,
      ),
      focusedBorder: outline(scheme.primary, 2),
      border: outline(
        isDark ? scheme.outline.withValues(alpha: 0.5) : Colors.grey.shade400,
      ),
    );
  }

  Widget _sectionCard(BuildContext context, {
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;
    final onText = scheme.onSurface;
    return Container(
      margin: const EdgeInsets.only(bottom: 22),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? scheme.surfaceContainerHighest : Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: isDark
              ? scheme.outline.withValues(alpha: 0.38)
              : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: isDark
                      ? scheme.surfaceContainerHigh
                      : Colors.black.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, size: 17, color: onText),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: onText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Divider(
            height: 1,
            color: scheme.outline.withValues(alpha: isDark ? 0.35 : 0.2),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prefsVM = Provider.of<UserPreferencesViewModel>(context, listen: false);
    final scheme = Theme.of(context).colorScheme;
    final fieldStyle = TextStyle(fontSize: 14, color: scheme.onSurface);
    final subStyle = TextStyle(fontSize: 12, color: scheme.onSurfaceVariant);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
            _loading
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      child: SizedBox(
                        width: 26,
                        height: 26,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: scheme.primary,
                        ),
                      ),
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionCard(context,
                        icon: Icons.auto_awesome,
                        title: 'Smart Task Organizer',
                        children: [
                          TextField(
                            controller: _breakDurationController,
                            keyboardType: TextInputType.number,
                            style: fieldStyle,
                            decoration: _fieldDecoration(context,
                              labelText: 'Break duration (minutes)',
                              hintText: 'e.g. 10',
                            ),
                            onChanged: (value) {
                              final parsed = int.tryParse(value);
                              if (parsed != null && parsed > 0) {
                                _breakDuration = parsed;
                              }
                            },
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _breakAfterController,
                            keyboardType: TextInputType.number,
                            style: fieldStyle,
                            decoration: _fieldDecoration(context,
                              labelText: 'Insert a break after (minutes of tasks)',
                              hintText: 'Leave empty for every task',
                            ),
                            onChanged: (value) {
                              if (value.trim().isEmpty) {
                                _breakAfter = 0;
                              } else {
                                final parsed = int.tryParse(value);
                                if (parsed != null && parsed >= 0) {
                                  _breakAfter = parsed;
                                }
                              }
                            },
                          ),
                        ],
                      ),
                      _sectionCard(context,
                        icon: Icons.schedule_outlined,
                        title: 'Reminders & quiet hours',
                        children: [
                          SwitchListTile(
                            visualDensity: VisualDensity.standard,
                            contentPadding: const EdgeInsets.symmetric(vertical: 2),
                            title: Text(
                              'Task reminders',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: scheme.onSurface,
                              ),
                            ),
                            subtitle: Text(
                              'Enable reminders for upcoming tasks',
                              style: subStyle,
                            ),
                            value: _remindersEnabled,
                            onChanged: (v) => setState(() => _remindersEnabled = v),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _defaultReminderController,
                            keyboardType: TextInputType.number,
                            style: fieldStyle,
                            decoration: _fieldDecoration(context,
                              labelText: 'Default reminder (minutes before)',
                              hintText: 'e.g. 15',
                            ),
                            onChanged: (v) {
                              final parsed = int.tryParse(v);
                              if (parsed != null && parsed > 0) {
                                _defaultReminderMinutesBefore = parsed;
                              }
                            },
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _quietHoursStartController,
                                  keyboardType: TextInputType.number,
                                  style: fieldStyle,
                                  decoration: _fieldDecoration(context,
                                    labelText: 'Quiet hours start',
                                    hintText: 'Optional (minutes)',
                                  ),
                                  onChanged: (v) {
                                    if (v.trim().isEmpty) {
                                      _quietHoursStartMinutes = null;
                                    } else {
                                      final parsed = int.tryParse(v);
                                      if (parsed != null && parsed >= 0) {
                                        _quietHoursStartMinutes = parsed;
                                      }
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: _quietHoursEndController,
                                  keyboardType: TextInputType.number,
                                  style: fieldStyle,
                                  decoration: _fieldDecoration(context,
                                    labelText: 'Quiet hours end',
                                    hintText: 'Optional (minutes)',
                                  ),
                                  onChanged: (v) {
                                    if (v.trim().isEmpty) {
                                      _quietHoursEndMinutes = null;
                                    } else {
                                      final parsed = int.tryParse(v);
                                      if (parsed != null && parsed >= 0) {
                                        _quietHoursEndMinutes = parsed;
                                      }
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      _sectionCard(context,
                        icon: Icons.calendar_month_outlined,
                        title: 'Calendar',
                        children: [
                          DropdownButtonFormField<int>(
                            value: _weekStartsOn,
                            style: fieldStyle,
                            decoration: _fieldDecoration(context,
                              labelText: 'Week starts on',
                            ),
                            items: [
                              DropdownMenuItem(
                                value: 1,
                                child: Text('Monday', style: fieldStyle),
                              ),
                              DropdownMenuItem(
                                value: 7,
                                child: Text('Sunday', style: fieldStyle),
                              ),
                            ],
                            onChanged: (v) {
                              if (v == null) return;
                              setState(() => _weekStartsOn = v);
                            },
                          ),
                        ],
                      ),
                      _sectionCard(context,
                        icon: Icons.palette_outlined,
                        title: 'Appearance',
                        children: [
                          DropdownButtonFormField<String>(
                            value: _theme,
                            style: fieldStyle,
                            decoration: _fieldDecoration(context,
                              labelText: 'Theme',
                            ),
                            items: [
                              DropdownMenuItem(
                                value: 'light',
                                child: Text('Light', style: fieldStyle),
                              ),
                              DropdownMenuItem(
                                value: 'dark',
                                child: Text('Dark', style: fieldStyle),
                              ),
                            ],
                            onChanged: (v) {
                              if (v == null) return;
                              setState(() => _theme = v);
                              prefsVM.updateTheme(v).catchError((Object e, StackTrace st) {
                                debugPrint('updateTheme failed: $e');
                              });
                            },
                          ),
                        ],
                      ),
                      _sectionCard(context,
                        icon: Icons.timer_outlined,
                        title: 'Focus timer',
                        children: [
                          SwitchListTile(
                            visualDensity: VisualDensity.standard,
                            contentPadding: const EdgeInsets.symmetric(vertical: 2),
                            title: Text(
                              'Sound',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: scheme.onSurface,
                              ),
                            ),
                            subtitle: Text(
                              'Play sound when a session ends',
                              style: subStyle,
                            ),
                            value: _timerSoundEnabled,
                            onChanged: (v) => setState(() => _timerSoundEnabled = v),
                          ),
                          SwitchListTile(
                            visualDensity: VisualDensity.standard,
                            contentPadding: const EdgeInsets.symmetric(vertical: 2),
                            title: Text(
                              'Vibration',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: scheme.onSurface,
                              ),
                            ),
                            subtitle: Text(
                              'Vibrate when a session ends (mobile only)',
                              style: subStyle,
                            ),
                            value: _timerVibrationEnabled,
                            onChanged: (v) => setState(() => _timerVibrationEnabled = v),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (!widget.embedded) ...[
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                textStyle: const TextStyle(fontSize: 14),
                              ),
                              child: const Text('Cancel'),
                            ),
                            const SizedBox(width: 6),
                          ],
                          FilledButton(
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                              textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                            onPressed: _saving
                                ? null
                                : () async {
                                    final parsedDuration =
                                        int.tryParse(_breakDurationController.text);
                                    if (parsedDuration == null || parsedDuration <= 0) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                              'Please enter a valid break duration in minutes'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                      return;
                                    }
                                    _breakDuration = parsedDuration;

                                    final breakAfterText =
                                        _breakAfterController.text.trim();
                                    if (breakAfterText.isEmpty) {
                                      _breakAfter = 0; // every task
                                    } else {
                                      final parsedAfter = int.tryParse(breakAfterText);
                                      if (parsedAfter == null || parsedAfter < 0) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                                'Please enter a valid "insert a break after" value'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                        return;
                                      }
                                      _breakAfter = parsedAfter;
                                    }

                                    setState(() {
                                      _saving = true;
                                    });
                                    try {
                                      await prefsVM.updateScheduleBreakPreferences(
                                        breakDurationMinutes: _breakDuration,
                                        breakAfterTaskMinutes: _breakAfter,
                                      );
                                      await prefsVM.updateReminderPreferences(
                                        remindersEnabled: _remindersEnabled,
                                        defaultReminderMinutesBefore:
                                            _defaultReminderMinutesBefore,
                                        quietHoursStartMinutes: _quietHoursStartMinutes,
                                        quietHoursEndMinutes: _quietHoursEndMinutes,
                                      );
                                      await prefsVM.updateWeekStartsOn(_weekStartsOn);
                                      await prefsVM.updateFocusTimerPreferences(
                                        timerSoundEnabled: _timerSoundEnabled,
                                        timerVibrationEnabled: _timerVibrationEnabled,
                                      );
                                      if (mounted) {
                                        if (!widget.embedded) {
                                          Navigator.pop(context);
                                        }
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('User preferences saved'),
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                                'Failed to save preferences: $e'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    } finally {
                                      if (mounted) {
                                        setState(() {
                                          _saving = false;
                                        });
                                      }
                                    }
                                  },
                            child: _saving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child:
                                        CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Text('Save'),
                          ),
                        ],
                      ),
                    ],
                  ),
        ],
      ),
    );
  }
}

/// Subtle wave lines on the navy header.
class _ProfileWavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final w = size.width;
    final h = size.height;
    for (var i = 0; i < 6; i++) {
      final path = Path();
      final y = h * (0.05 + i * 0.16);
      path.moveTo(0, y);
      for (var x = 0.0; x < w; x += 24) {
        path.quadraticBezierTo(x + 12, y + (i.isEven ? 5.0 : -5.0), x + 24, y);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _GoldRingAvatar extends StatelessWidget {
  const _GoldRingAvatar({
    required this.radius,
    required this.profileImageUrl,
  });

  final double radius;
  final String? profileImageUrl;

  @override
  Widget build(BuildContext context) {
    final hasImage = profileImageUrl != null && profileImageUrl!.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: _profileGold, width: 2),
        boxShadow: [
          BoxShadow(
            color: _profileGold.withValues(alpha: 0.35),
            blurRadius: 12,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: _profileGoldInner.withValues(alpha: 0.85), width: 1),
        ),
        child: CircleAvatar(
          radius: radius,
          backgroundColor: Colors.white.withValues(alpha: 0.15),
          backgroundImage: hasImage ? NetworkImage(profileImageUrl!) : null,
          child: !hasImage
              ? Icon(Icons.person_rounded, size: radius * 0.95, color: Colors.white70)
              : null,
        ),
      ),
    );
  }
}
