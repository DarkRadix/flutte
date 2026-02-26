import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login.dart';
import 'jogos.dart';
import 'cadastro.dart'; // Assumindo que sua página de cadastro chama assim

void main() async {
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
      title: 'Meu App de Quadras',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue),
      
      // CONFIGURAÇÃO DE ROTAS: Isso ajuda o navegador a saber onde você está
      initialRoute: '/',
      routes: {
        '/': (context) => const AuthCheck(), // Tela que decide para onde ir
        '/login': (context) => const LoginPage(),
        '/jogos': (context) => const JogosPage(),
        '/cadastro': (context) => const CadastroPage(),
      },
    );
  }
}

// ESTA CLASSE É O "CÉREBRO" DO F5
class AuthCheck extends StatelessWidget {
  const AuthCheck({super.key});

  @override
  Widget build(BuildContext context) {
    // O StreamBuilder fica "vigiando" se existe um usuário logado
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        // Enquanto o Supabase checa a sessão no F5...
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF1B263B),
            body: Center(child: CircularProgressIndicator(color: Colors.white)),
          );
        }

        final session = snapshot.data?.session;

        // Se tiver sessão (logado), ele mantém/vai para Jogos
        if (session != null) {
          return const JogosPage();
        }

        // Se não tiver sessão, ele fica na Login
        return const LoginPage();
      },
    );
  }
}