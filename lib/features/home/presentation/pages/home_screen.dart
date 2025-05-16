// HomeScreen
import 'package:flutter/material.dart';
import 'package:fultter_run/core/utils/utils.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("home".translate(context)),
        leading: IconButton(
            onPressed: () {
              Scaffold.of(context).openDrawer();
            },
            icon: const Icon(Icons.menu)),
      ),
      body: Center(child: Text("home_screen_welcome".translate(context))),
    );
  }
}
