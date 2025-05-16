import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../features/bluetooth_connection/presentation/pages/bluetooth_discovery.dart';
import '../features/home/presentation/pages/home_screen.dart';
import '../features/settings/presentation/pages/settings_screen.dart';
import '../main.dart';
import 'local_service.dart';
import 'localization_service.dart';

// Navigation Service using go_router with StatefulShellRoute
class NavigationService {
  static final GoRouter router = GoRouter(
    initialLocation: '/home',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, child) {
          return MainScreen(child: child);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                  path: '/home',
                  builder: (context, state) => const HomeScreen())
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                  path: '/settings',
                  builder: (context, state) => const SettingsScreen())
            ],
          ),
        ],
      ),
    ],
  );
}

// Helper functions for navigation
extension NavigationServiceExtension on NavigationService {
  static int getCurrentIndex(BuildContext context) {
    final location = GoRouter.of(context).location;
    return location == '/home' ? 0 : 1;
  }

  static void onTabSelected(BuildContext context, int index) {
    final route = index == 0 ? '/home' : '/settings';
    context.go(route);
  }

  static Widget buildDrawer(BuildContext context) {
    return Drawer(
      child: ListView(
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(color: Colors.blue),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(children: [
                  Text('data', style: TextStyle(fontSize: 12)),
                  Text('data')
                ])
              ],
            ),
          ),
          ListTile(
            title: const Text('Change Language'),
            onTap: () {
              Navigator.pop(context);
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Select Language'),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children:
                          LocalizationService.supportedLocales.map((locale) {
                        return ListTile(
                          title: Text(locale.languageCode),
                          onTap: () {
                            BlocProvider.of<LocaleService>(context)
                                .changeLocale(locale);
                            Navigator.pop(context);
                          },
                        );
                      }).toList(),
                    ),
                  ),
                ),
              );
            },
          ),
          ListTile(
            title: const Text('Scan Devices'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const DeviceScanScreen(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _profileSection() {
    return Container();
  }
}
