import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'providers/auth_provider.dart';
import 'screens/activities_screen.dart';
import 'screens/admin_screen.dart';
import 'screens/agenda_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/growth_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/reports_screen.dart';
import 'screens/tasks_screen.dart';
import 'screens/team_member_screen.dart';
import 'screens/team_screen.dart';
import 'screens/tour_plan_screen.dart';
import 'widgets/app_shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  // Rebuilds the router (and re-runs redirects) whenever auth state flips.
  final signedIn = ref.watch(
    sessionControllerProvider.select((session) => session != null),
  );

  return GoRouter(
    initialLocation: signedIn ? '/dashboard' : '/auth',
    redirect: (context, state) {
      final atAuth = state.uri.path == '/auth';
      if (!signedIn && !atAuth) return '/auth';
      if (signedIn && atAuth) return '/dashboard';
      return null;
    },
    routes: [
      GoRoute(path: '/auth', builder: (_, __) => const AuthScreen()),
      ShellRoute(
        builder: (_, __, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (_, __) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/activities',
            builder: (_, __) => const ActivitiesScreen(),
          ),
          GoRoute(path: '/tasks', builder: (_, __) => const TasksScreen()),
          GoRoute(
            path: '/team',
            builder: (_, __) => const TeamScreen(),
            routes: [
              GoRoute(
                path: ':userId',
                builder: (_, s) =>
                    TeamMemberScreen(userId: s.pathParameters['userId']!),
              ),
            ],
          ),
          GoRoute(path: '/reports', builder: (_, __) => const RatingsScreen()),
          GoRoute(path: '/growth', builder: (_, __) => const GrowthScreen()),
          GoRoute(path: '/admin', builder: (_, __) => const AdminScreen()),
          GoRoute(path: '/agenda', builder: (_, __) => const AgendaScreen()),
          GoRoute(
            path: '/tour-plan',
            builder: (_, __) => const TourPlanScreen(),
          ),
          GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
        ],
      ),
    ],
  );
});
