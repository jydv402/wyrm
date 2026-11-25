import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:wyrm_desk/features/calendar/milestone_editor_screen.dart';
import 'package:wyrm_desk/features/habits/habit_editor_screen.dart';
import 'package:wyrm_desk/features/habits/habit_model.dart';
import 'package:wyrm_desk/features/home/homepage.dart';
import 'package:wyrm_desk/features/settings/settings_page.dart';
import 'package:wyrm_desk/features/tasks/task_editor_screen.dart';
import 'package:wyrm_desk/theme/theme.dart';

/// App-wide typed route names and paths.
abstract final class AppRoutes {
  static const home = '/';
  static const settings = '/settings';
  static const taskEditor = '/tasks/editor';
  static const habitEditor = '/habits/editor';
  static const milestoneEditor = '/calendar/milestones/editor';
}

Widget _fadeTransition(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  if (MediaQuery.disableAnimationsOf(context)) return child;
  return FadeTransition(opacity: animation, child: child);
}

/// Singleton GoRouter provider for Wyrm Desk.
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.home,
    errorBuilder: (context, state) => Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Text(
          'Page not found: ${state.uri}',
          style: const TextStyle(color: AppColors.textPrimary),
        ),
      ),
    ),
    routes: [
      GoRoute(
        path: AppRoutes.home,
        name: 'home',
        pageBuilder: (context, state) => CustomTransitionPage<void>(
          key: state.pageKey,
          child: const HomePage(),
          transitionsBuilder: _fadeTransition,
        ),
      ),
      GoRoute(
        path: AppRoutes.settings,
        name: 'settings',
        pageBuilder: (context, state) => CustomTransitionPage<void>(
          key: state.pageKey,
          child: const SettingsPage(),
          transitionsBuilder: _fadeTransition,
        ),
      ),
      GoRoute(
        path: AppRoutes.taskEditor,
        name: 'taskEditor',
        pageBuilder: (context, state) => CustomTransitionPage<void>(
          key: state.pageKey,
          child: const TaskEditorScreen(),
          transitionsBuilder: _fadeTransition,
        ),
      ),
      GoRoute(
        path: AppRoutes.habitEditor,
        name: 'habitEditor',
        pageBuilder: (context, state) => CustomTransitionPage<void>(
          key: state.pageKey,
          child: HabitEditorScreen(habitToEdit: state.extra as HabitItem?),
          transitionsBuilder: _fadeTransition,
        ),
      ),
      GoRoute(
        path: AppRoutes.milestoneEditor,
        name: 'milestoneEditor',
        pageBuilder: (context, state) => CustomTransitionPage<void>(
          key: state.pageKey,
          child: MilestoneEditorScreen(initialDate: state.extra as DateTime?),
          transitionsBuilder: _fadeTransition,
        ),
      ),
    ],
  );
});
