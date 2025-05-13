// App Config
import 'package:flutter/material.dart';

class AppConfig {
  final String appName;
  final ThemeData themeData;

  AppConfig({required this.appName, required this.themeData});

  static Future<AppConfig> load() async {
    // Load configuration dynamically
    return AppConfig(
      appName: 'WhiteLabelApp',
      themeData: ThemeData.dark(),
    );
  }
}