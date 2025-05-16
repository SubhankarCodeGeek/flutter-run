// SettingsScreen
import 'package:flutter/material.dart';
import 'package:fultter_run/core/utils/utils.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("settings".translate(context))),
      body: Center(child: Text("home_screen_welcome".translate(context))),
    );
  }
}
