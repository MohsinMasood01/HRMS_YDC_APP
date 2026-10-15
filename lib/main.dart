import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tracelet/tracelet.dart' as tl;

import 'app.dart';
import 'core/background/tracelet_headless.dart';
import 'di/service_locator.dart';
import 'shared/bloc/app_bloc_observer.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureDependencies();
  Bloc.observer = AppBlocObserver();

  // Register Tracelet's headless entry point before runApp() so it is
  // reachable when the app process is not running. It queues fixes recorded
  // while the app is killed and uploads them (Tracelet's own HTTP sync is not
  // used -- see TraceletService).
  //
  // Wrapped: nothing on this path may stop the app from launching.
  try {
    await tl.Tracelet.registerHeadlessTask(traceletHeadlessTask);
  } catch (e) {
    debugPrint('[main] Tracelet headless registration failed (non-fatal): $e');
  }

  runApp(const LmsApp());
}
