import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fultter_run/features/wifi_provisioning/presentation/bloc/wifi_bloc.dart';
import 'package:fultter_run/services/feature_toggle_service.dart';
import 'package:fultter_run/services/local_service.dart';
import 'package:fultter_run/services/localization_service.dart';
import 'package:fultter_run/services/navigation_services.dart' as main_nav;

import 'core/config/config.dart';
import 'features/bluetooth_connection/presentation/bloc/bluetooth_bloc.dart';
import 'features/custom_nav_1/widgets.dart' as feature_nav;
import 'features/home/presentation/widgets.dart';

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
        BlocProvider(create: (_) => BluetoothBloc()),
        BlocProvider(create: (_) => WifiBloc()),
      ],
      child: BlocBuilder<LocaleService, Locale>(
        builder: (context, locale) {
          return BlocBuilder<FeatureToggleService, Map<String, bool>>(
              builder: (context, feature) {
            final isNewNavEnabled = feature['new_nav_enabled'] ?? false;
            return MaterialApp.router(
              title: config.appName,
              theme: config.themeData,
              locale: locale,
              supportedLocales: LocalizationService.supportedLocales,
              localizationsDelegates: LocalizationService.delegates,
              routerConfig: !isNewNavEnabled
                  ? main_nav.NavigationService.router
                  : feature_nav.NavigationService.router,
            );
          });
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
    final featureToggle = context.watch<FeatureToggleService>();
    final isNewNavEnabled = featureToggle.isFeatureEnabled("new_nav_enabled");

    return Scaffold(
      drawer: main_nav.NavigationServiceExtension.buildDrawer(context),
      body: GestureDetector(
        onHorizontalDragEnd: isNewNavEnabled
            ? (details) {
                final velocity = details.primaryVelocity ?? 0;
                final currentIndex = context.currentTabIndex;
                final newIndex = velocity < 0
                    ? currentIndex + 1
                    : velocity > 0
                        ? currentIndex - 1
                        : currentIndex;
                context.goToTab(newIndex);
              }
            : null,
        child: child,
      ),
      bottomNavigationBar: isNewNavEnabled
          ? CustomBottomNavBar(
              currentIndex: context.currentTabIndex,
              onTap: context.goToTab,
              items: [
                CustomNavBarItem(icon: Icons.location_on, label: 'Location'),
                CustomNavBarItem(icon: Icons.info_outline, label: 'Info'),
                CustomNavBarItem(icon: Icons.lock_outline, label: 'Lock'),
                CustomNavBarItem(icon: Icons.scale, label: 'Scale'),
                CustomNavBarItem(
                    icon: Icons.notifications_none, label: 'Alerts'),
              ],
            )
          : BottomNavigationBar(
              currentIndex:
                  main_nav.NavigationServiceExtension.getCurrentIndex(context),
              onTap: (index) =>
                  main_nav.NavigationServiceExtension.onTabSelected(
                      context, index),
              items: [
                BottomNavigationBarItem(
                    icon: Icon(Icons.home),
                    label: context.watch<LocaleService>().translate("home")),
                BottomNavigationBarItem(
                    icon: Icon(Icons.settings),
                    label:
                        context.watch<LocaleService>().translate("settings")),
              ],
            ),
    );
  }
}
