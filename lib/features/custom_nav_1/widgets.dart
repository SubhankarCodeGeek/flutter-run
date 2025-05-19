
import 'package:fultter_run/features/custom_nav_1/pages/info_screen.dart';
import 'package:fultter_run/features/custom_nav_1/pages/location_screen.dart';
import 'package:fultter_run/features/custom_nav_1/pages/lock_screen.dart';
import 'package:fultter_run/features/custom_nav_1/pages/notification_screen.dart';
import 'package:fultter_run/features/custom_nav_1/pages/weight_screen.dart';
import 'package:go_router/go_router.dart';

import '../../main.dart';

class NavigationService {
  static final GoRouter router = GoRouter(
    initialLocation: '/lock', // or any default tab
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, child) {
          return MainScreen(child: child);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/location',
                builder: (context, state) => const LocationScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/info',
                builder: (context, state) => const InfoScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/lock',
                builder: (context, state) => const LockScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/scale',
                builder: (context, state) => const WeightScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/notifications',
                builder: (context, state) => const NotificationScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
