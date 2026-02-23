import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login.dart';
import 'principal.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://bwlyksmpkhjmwbtpncnw.supabase.co',
    anonKey: 'sb_publishable_7qOO2vmXJ-HG61fQJc5uSw_5BFMoEUS',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Supabase.instance.client.auth.currentUser == null
          ? const LoginPage()
          : const PrincipalPage(),
    );
  }
}