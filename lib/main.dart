import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'viewmodels/auth_viewmodel.dart';
import 'viewmodels/task_viewmodel.dart';
import 'viewmodels/scheduled_task_viewmodel.dart';
import 'viewmodels/focus_timer_viewmodel.dart';
import 'viewmodels/analytics_viewmodel.dart';
import 'viewmodels/user_preferences_viewmodel.dart';
import 'views/auth/auth_wrapper.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (e) {
    print("Firebase initialization error: $e");
  }

  // Local notifications (task reminders).
  await NotificationService.instance.init();

  // Initialize ViewModels
  final authViewModel = AuthViewModel();
  final taskViewModel = TaskViewModel();
  final scheduledTaskViewModel = ScheduledTaskViewModel();
  final focusTimerViewModel = FocusTimerViewModel();
  final analyticsViewModel = AnalyticsViewModel();
  final userPreferencesViewModel = UserPreferencesViewModel();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authViewModel),
        ChangeNotifierProvider.value(value: taskViewModel),
        ChangeNotifierProvider.value(value: scheduledTaskViewModel),
        ChangeNotifierProvider.value(value: focusTimerViewModel),
        ChangeNotifierProvider.value(value: analyticsViewModel),
        ChangeNotifierProvider.value(value: userPreferencesViewModel),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme(),
        home: const AuthWrapper(), // Start with AuthWrapper instead of MainShell
        debugShowCheckedModeBanner: false,
        builder: (context, child) {
          final mq = MediaQuery.of(context);
          final platform = defaultTargetPlatform;
          final isPhoneLike = !kIsWeb &&
              (platform == TargetPlatform.android ||
                  platform == TargetPlatform.iOS);

          // Keep system accessibility scaling, but clamp extremes and make
          // phone UI slightly more compact to match web sizing.
          final sysScale = mq.textScaleFactor;
          final clampedSysScale = sysScale.clamp(0.90, 1.10);
          final effectiveScale =
              isPhoneLike ? (clampedSysScale * 0.92) : clampedSysScale;

          final base = Theme.of(context);
          final themedChild = Theme(
            data: base.copyWith(
              visualDensity:
                  isPhoneLike ? VisualDensity.compact : VisualDensity.standard,
              materialTapTargetSize: isPhoneLike
                  ? MaterialTapTargetSize.shrinkWrap
                  : MaterialTapTargetSize.padded,
            ),
            child: child ?? const SizedBox.shrink(),
          );

          return MediaQuery(
            data: mq.copyWith(
              textScaler: TextScaler.linear(effectiveScale.toDouble()),
            ),
            child: themedChild,
          );
        },
      ),
    ),
  );
}