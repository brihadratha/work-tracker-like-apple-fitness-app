import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'screens/root_shell.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
  // Every screen is laid out as a single portrait column.
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  final state = AppState();
  await state.load();

  runApp(WorkRingsApp(state: state));
}

class WorkRingsApp extends StatelessWidget {
  const WorkRingsApp({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: state,
      child: MaterialApp(
        title: 'Work Rings',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        home: const RootShell(),
      ),
    );
  }
}
