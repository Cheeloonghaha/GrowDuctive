import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_profile_model.dart';
import '../navigation/app_page_routes.dart';
import '../theme/app_colors.dart';
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
      backgroundColor: AppColors.base,
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
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            fadeSlideRoute(const ProfileEditView()),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: BorderSide(color: Colors.grey[400]!),
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.edit_outlined, size: 20, color: Colors.black87),
                            SizedBox(width: 8),
                            Text(
                              'Edit profile',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
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
                        Material(
                          elevation: 8,
                          shadowColor: Colors.black.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(28),
                          color: Colors.white,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: _profileNavyMid,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(Icons.tune_rounded,
                                          color: Colors.white, size: 20),
                                    ),
                                    const SizedBox(width: 12),
                                    const Text(
                                      'User preferences',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: _profileNavyTop,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                const _ProfilePreferencesForm(embedded: true),
                              ],
                            ),
                          ),
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
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 300),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
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
                    const Icon(Icons.logout, color: Colors.white, size: 24),
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
                      onTap: () => Navigator.pop(context, false),
                      child: const Icon(Icons.close, color: Colors.white, size: 24),
                    ),
                  ],
                ),
              ),
              // Content
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
                    // Actions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: () => Navigator.pop(context, false),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.grey[400]!),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
                          onPressed: () => Navigator.pop(context, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red[600],
                            foregroundColor: Colors.white,
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
      ),
    );

    if (shouldLogout == true) {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
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
  String _theme = 'system'; // 'light' | 'dark' | 'system'
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
        _theme = prefs.theme;
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

  Widget _sectionCard({
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: Colors.black87),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Divider(height: 1, color: Colors.grey.shade200),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prefsVM = Provider.of<UserPreferencesViewModel>(context, listen: false);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
            _loading
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: CircularProgressIndicator(),
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionCard(
                        icon: Icons.auto_awesome,
                        title: 'Smart Task Organizer',
                        children: [
                          TextField(
                            controller: _breakDurationController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Break duration (minutes)',
                              hintText: 'e.g. 10',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (value) {
                              final parsed = int.tryParse(value);
                              if (parsed != null && parsed > 0) {
                                _breakDuration = parsed;
                              }
                            },
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _breakAfterController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Insert a break after (minutes of tasks)',
                              hintText: 'Leave empty for every task',
                              border: OutlineInputBorder(),
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
                      _sectionCard(
                        icon: Icons.schedule_outlined,
                        title: 'Reminders & quiet hours',
                        children: [
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Task reminders'),
                            subtitle: const Text('Enable reminders for upcoming tasks'),
                            value: _remindersEnabled,
                            onChanged: (v) => setState(() => _remindersEnabled = v),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _defaultReminderController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Default reminder (minutes before)',
                              hintText: 'e.g. 15',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (v) {
                              final parsed = int.tryParse(v);
                              if (parsed != null && parsed > 0) {
                                _defaultReminderMinutesBefore = parsed;
                              }
                            },
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _quietHoursStartController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Quiet hours start',
                                    hintText: 'Optional (minutes)',
                                    border: OutlineInputBorder(),
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
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: _quietHoursEndController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Quiet hours end',
                                    hintText: 'Optional (minutes)',
                                    border: OutlineInputBorder(),
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
                      _sectionCard(
                        icon: Icons.calendar_month_outlined,
                        title: 'Calendar',
                        children: [
                          DropdownButtonFormField<int>(
                            value: _weekStartsOn,
                            decoration: const InputDecoration(
                              labelText: 'Week starts on',
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(value: 1, child: Text('Monday')),
                              DropdownMenuItem(value: 7, child: Text('Sunday')),
                            ],
                            onChanged: (v) {
                              if (v == null) return;
                              setState(() => _weekStartsOn = v);
                            },
                          ),
                        ],
                      ),
                      _sectionCard(
                        icon: Icons.palette_outlined,
                        title: 'Appearance',
                        children: [
                          DropdownButtonFormField<String>(
                            value: _theme,
                            decoration: const InputDecoration(
                              labelText: 'Theme',
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'system',
                                child: Text('System default'),
                              ),
                              DropdownMenuItem(value: 'light', child: Text('Light')),
                              DropdownMenuItem(value: 'dark', child: Text('Dark')),
                            ],
                            onChanged: (v) {
                              if (v == null) return;
                              setState(() => _theme = v);
                            },
                          ),
                        ],
                      ),
                      _sectionCard(
                        icon: Icons.timer_outlined,
                        title: 'Focus timer',
                        children: [
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Sound'),
                            subtitle: const Text('Play sound when a session ends'),
                            value: _timerSoundEnabled,
                            onChanged: (v) => setState(() => _timerSoundEnabled = v),
                          ),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Vibration'),
                            subtitle: const Text('Vibrate when a session ends (mobile only)'),
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
                              child: const Text('Cancel'),
                            ),
                            const SizedBox(width: 8),
                          ],
                          FilledButton(
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
                                      await prefsVM.updateTheme(_theme);
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
