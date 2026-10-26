import 'package:flutter/material.dart';

import 'app_state.dart';
import 'screens/auth_screens.dart';
import 'screens/dashboard_screen.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppState.instance.init(); // opens the SQLite file, restores session
  runApp(const SmartBinApp());
}

class SmartBinApp extends StatelessWidget {
  const SmartBinApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Bin',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      // Logged in -> dashboard, logged out -> login. Switches automatically.
      home: ListenableBuilder(
        listenable: AppState.instance,
        builder: (context, _) => AppState.instance.user == null
            ? const LoginScreen()
            : const DashboardScreen(),
      ),
    );
  }
}
