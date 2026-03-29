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
import 'models/user_preferences_model.dart';

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
      child: const GrowductiveApp(),
    ),
  );
}

/// Root [MaterialApp] with light/dark/system theme from [UserPreferencesViewModel].
class GrowductiveApp extends StatelessWidget {
  const GrowductiveApp({super.key});

  @override
  Widget build(BuildContext context) {
    final prefsVM = context.watch<UserPreferencesViewModel>();

    return StreamBuilder<UserPreferencesModel?>(
      stream: prefsVM.preferencesStream,
      builder: (context, snapshot) {
        final themeStr = prefsVM.themeResolved(snapshot.data?.theme);
        final ThemeMode mode;
        if (themeStr == 'dark') {
          mode = ThemeMode.dark;
        } else if (themeStr == 'light') {
          mode = ThemeMode.light;
        } else {
          mode = ThemeMode.system;
        }

        return MaterialApp(
          theme: AppTheme.lightTheme(),
          darkTheme: AppTheme.darkTheme(),
          themeMode: mode,
          themeAnimationDuration: const Duration(milliseconds: 260),
          themeAnimationCurve: Curves.easeInOutCubic,
          home: const AuthWrapper(),
          debugShowCheckedModeBanner: false,
          builder: (context, child) {
            final mq = MediaQuery.of(context);
            final platform = defaultTargetPlatform;
            final isPhoneLike = !kIsWeb &&
                (platform == TargetPlatform.android ||
                    platform == TargetPlatform.iOS);

            final sysScale = mq.textScaleFactor;
            final clampedSysScale = sysScale.clamp(0.90, 1.10);
            final effectiveScale =
                isPhoneLike ? (clampedSysScale * 0.92) : clampedSysScale;

            final base = Theme.of(context);
            final themedChild = Theme(
              data: base.copyWith(
                visualDensity: isPhoneLike
                    ? VisualDensity.compact
                    : VisualDensity.standard,
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
        );
      },
    );
  }
}