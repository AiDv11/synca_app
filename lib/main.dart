import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'firebase_options.dart';
import 'src/modules/common/auth/ui/page/auth_gate.dart';

void main() async {
  // The binding is Flutter's connection to the OS. It has to exist before any
  // plugin is touched, which is why it is created first and then handed to
  // preserve() below.
  final binding = WidgetsFlutterBinding.ensureInitialized();

  // Holds the native splash on screen instead of letting it disappear the
  // instant Flutter is ready to draw. Without this the splash clears while
  // Firebase is still starting up, leaving a blank screen in the gap.
  //
  // On web it does more than that: the web "splash" is ordinary HTML sitting in
  // web/index.html, and remove() below is the only thing that ever takes it off
  // the page.
  FlutterNativeSplash.preserve(widgetsBinding: binding);

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const MyApp());

  // Hands the screen over to the app. AuthGate is now mounted and will show its
  // own loading state while it works out who is signed in.
  FlutterNativeSplash.remove();
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Synca',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a purple toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
        colorScheme: .fromSeed(seedColor: Colors.deepPurple),
      ),
      // AuthGate decides what is actually shown: the login page when nobody is
      // signed in, or the dashboard matching the signed-in user's role.
      home: const AuthGate(),
    );
  }
}
