import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CadastroPage extends StatefulWidget {
  const CadastroPage({super.key});

  @override
  State<CadastroPage> createState() => _CadastroPageState();
}

class _CadastroPageState extends State<CadastroPage> {
  final nomeController = TextEditingController();
  final emailController = TextEditingController();
  final senhaController = TextEditingController();
  bool loading = false;
  bool _senhaVisivel = false;

  final Color azulEscuro = const Color(0xFF0D47A1);
  final Color azulMedio = const Color(0xFF1976D2);

  Future<void> cadastrar() async {
    FocusScope.of(context).unfocus();

    final nome = nomeController.text.trim();
    final email = emailController.text.trim();
    final senha = senhaController.text.trim();

    if (nome.isEmpty || email.isEmpty || senha.isEmpty) {
      _notificar('Preencha todos os campos!', Colors.orange);
      return;
    }

    setState(() => loading = true);

    try {

      final AuthResponse res = await Supabase.instance.client.auth.signUp(
        email: email,
        password: senha,
        data: {'full_name': nome},
      );

      final user = res.user;

     
      if (user != null) {
        await Supabase.instance.client.from('profiles').upsert({
          'id': user.id,
          'username': nome, 
          'is_admin': false,
        });

        if (!mounted) return;

        if (res.session == null) {
          _notificar(
            'Cadastro realizado! Verifique seu e-mail para confirmar.',
            Colors.blue,
          );
        } else {
          _notificar('Bem-vindo, $nome!', Colors.green);
        }

        Navigator.pop(context);
      }
    } on AuthException catch (e) {
      _notificar(e.message, Colors.redAccent);
    } catch (e) {
      _notificar('Erro ao realizar cadastro: $e', Colors.redAccent);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _notificar(String msg, Color cor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: cor,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [azulEscuro, azulMedio],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Icon(
                  Icons.person_add_alt_1_rounded,
                  size: 80,
                  color: Colors.white,
                ),
                const SizedBox(height: 10),
                const Text(
                  "Criar Conta",
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1.2,
                  ),
                ),
                const Text(
                  "Preencha os dados abaixo",
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
                const SizedBox(height: 30),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 15,
                        offset: Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      TextField(
                        controller: nomeController,
                        textCapitalization: TextCapitalization
                            .words, 
                        decoration: InputDecoration(
                          labelText: "Nome Completo",
                          prefixIcon: Icon(
                            Icons.person_outline,
                            color: azulMedio,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: "E-mail",
                          prefixIcon: Icon(
                            Icons.email_outlined,
                            color: azulMedio,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: senhaController,
                        obscureText: !_senhaVisivel,
                        decoration: InputDecoration(
                          labelText: "Senha",
                          prefixIcon: Icon(
                            Icons.lock_outline,
                            color: azulMedio,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _senhaVisivel
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                            onPressed: () =>
                                setState(() => _senhaVisivel = !_senhaVisivel),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          onPressed: loading ? null : cadastrar,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: azulEscuro,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: loading
                              ? const CircularProgressIndicator(
                                  color: Colors.white,
                                )
                              : const Text(
                                  "FINALIZAR CADASTRO",
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    "Já tem uma conta? Faça login",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
