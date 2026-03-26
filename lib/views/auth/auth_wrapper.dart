import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../theme/growductive_chrome.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/task_viewmodel.dart';
import '../../viewmodels/scheduled_task_viewmodel.dart';
import '../../viewmodels/focus_timer_viewmodel.dart';
import '../../viewmodels/analytics_viewmodel.dart';
import '../../viewmodels/user_preferences_viewmodel.dart';
import '../main_shell.dart';
import 'login_view.dart';

/// AuthWrapper checks authentication state and routes to appropriate screen:
/// - If logged in: Shows MainShell (main app)
/// - If not logged in: Shows LoginView
/// - While checking: Shows loading indicator
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authVM = Provider.of<AuthViewModel>(context);

    return StreamBuilder<User?>(
      stream: authVM.authStateChanges,
      builder: (context, snapshot) {
        // Debug logging
        print("AuthWrapper: connectionState=${snapshot.connectionState}, hasData=${snapshot.hasData}, hasError=${snapshot.hasError}");
        if (snapshot.hasData) {
          print("AuthWrapper: User ID = ${snapshot.data?.uid}");
        }
        if (snapshot.hasError) {
          print("AuthWrapper: Error = ${snapshot.error}");
        }

        // Show loading while checking auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: context.chrome.scaffoldBackground,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Loading...',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // User is logged in - set userId on ViewModels *before* building MainShell
        // so task/category streams use the correct user from the first frame
        if (snapshot.hasData && snapshot.data != null) {
          final userId = snapshot.data!.uid;
          print("AuthWrapper: User logged in, userId=$userId");

          final taskVM = Provider.of<TaskViewModel>(context, listen: false);
          final scheduledTaskVM = Provider.of<ScheduledTaskViewModel>(context, listen: false);
          final focusTimerVM = Provider.of<FocusTimerViewModel>(context, listen: false);
          final analyticsVM = Provider.of<AnalyticsViewModel>(context, listen: false);
          final userPrefsVM = Provider.of<UserPreferencesViewModel>(context, listen: false);
          taskVM.setUserId(userId);
          scheduledTaskVM.setUserId(userId);
          focusTimerVM.setUserId(userId);
          analyticsVM.setUserId(userId);
          userPrefsVM.setUserId(userId);

          // Initialize default categories, default focus timer, and user preferences in background (async)
          WidgetsBinding.instance.addPostFrameCallback((_) {
            taskVM.initializeDefaultCategories();
            focusTimerVM.ensureDefaultTimer();
            userPrefsVM.ensureDefaults();
          });

          return const MainShell();
        }

        // User is not logged in - show login screen
        print("AuthWrapper: No user logged in, showing LoginView");
        return const LoginView();
      },
    );
  }
}
