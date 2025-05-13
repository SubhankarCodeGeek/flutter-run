// Navigation Service
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../features/home_screen.dart';
import '../features/settings_screen.dart';
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
            routes: [GoRoute(path: '/home', builder: (context, state) => HomeScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/settings', builder: (context, state) => SettingsScreen())],
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
                Text("data",style: TextStyle(fontSize: 12), ),
                Text("data", )
              ],
            ),
          ),
          ListTile(
            title: const Text("Change Language"),
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text("Select Language"),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: LocalizationService.supportedLocales.map((locale) {
                      return ListTile(
                        title: Text(locale.languageCode),
                        onTap: () {
                          BlocProvider.of<LocaleService>(context).changeLocale(locale);
                          Navigator.pop(context);
                        },
                      );
                    }).toList(),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
