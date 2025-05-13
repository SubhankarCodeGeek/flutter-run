import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fultter_run/services/feature_toggle_service.dart';
import 'package:fultter_run/services/local_service.dart';
import 'package:fultter_run/services/localization_service.dart';
import 'package:fultter_run/services/navigation_services.dart';

import 'core/config/config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final AppConfig config = await AppConfig.load();
  runApp(MyApp(config: config));
}

class MyApp extends StatelessWidget {
  final AppConfig config;

  const MyApp({Key? key, required this.config}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => LocaleService()),
        BlocProvider(create: (_) => FeatureToggleService()),
      ],
      child: BlocBuilder<LocaleService, Locale>(
        builder: (context, locale) {
          return MaterialApp.router(
            title: config.appName,
            theme: config.themeData,
            locale: locale,
            supportedLocales: LocalizationService.supportedLocales,
            localizationsDelegates: LocalizationService.delegates,
            routerConfig: NavigationService.router,
          );
        },
      ),
    );
  }
}

// MainScreen with BottomNavigation and Drawer
class MainScreen extends StatelessWidget {
  final Widget child;

  const MainScreen({Key? key, required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: NavigationServiceExtension.buildDrawer(context),
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: NavigationServiceExtension.getCurrentIndex(context),
        onTap: (index) =>
            NavigationServiceExtension.onTabSelected(context, index),
        items: [
          BottomNavigationBarItem(
              icon: const Icon(Icons.home),
              label: context.watch<LocaleService>().translate("home")),
          BottomNavigationBarItem(
              icon: const Icon(Icons.settings),
              label: context.watch<LocaleService>().translate("settings")),
        ],
      ),
    );
  }
}
