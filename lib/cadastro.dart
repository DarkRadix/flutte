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

  // Mesma paleta de cores do Login
  final Color azulEscuro = const Color(0xFF0D47A1);
  final Color azulMedio = const Color(0xFF1976D2);

  Future<void> cadastrar() async {
    FocusScope.of(context).unfocus(); // Fecha o teclado

    // Validação básica
    if (nomeController.text.isEmpty || emailController.text.isEmpty || senhaController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha todos os campos!'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => loading = true);
    try {
      // Cadastro no Supabase
      await Supabase.instance.client.auth.signUp(
        email: emailController.text.trim(),
        password: senhaController.text.trim(),
        data: {'display_name': nomeController.text.trim()}, // Salva o nome nos metadados
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cadastro realizado! Verifique seu e-mail.'),
          backgroundColor: Colors.green,
        ),
      );
      
      Navigator.pop(context); // Volta para a tela de login
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao cadastrar: ${e.toString()}'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Estendemos o corpo para trás da AppBar para o gradiente ficar perfeito
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
                const Icon(Icons.person_add_alt_1_rounded, size: 80, color: Colors.white),
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

                // Card do Formulário
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
                      )
                    ],
                  ),
                  child: Column(
                    children: [
                      // Campo Nome
                      TextField(
                        controller: nomeController,
                        decoration: InputDecoration(
                          labelText: "Nome Completo",
                          prefixIcon: Icon(Icons.person_outline, color: azulMedio),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.black12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Campo Email
                      TextField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: "E-mail",
                          prefixIcon: Icon(Icons.email_outlined, color: azulMedio),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.black12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Campo Senha
                      TextField(
                        controller: senhaController,
                        obscureText: !_senhaVisivel,
                        decoration: InputDecoration(
                          labelText: "Senha",
                          prefixIcon: Icon(Icons.lock_outline, color: azulMedio),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _senhaVisivel ? Icons.visibility : Icons.visibility_off,
                              color: Colors.grey,
                            ),
                            onPressed: () => setState(() => _senhaVisivel = !_senhaVisivel),
                          ),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.black12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),

                      // Botão Cadastrar
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
                            elevation: 2,
                          ),
                          child: loading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Text(
                                  "FINALIZAR CADASTRO",
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Link para voltar ao login
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    "Já tem uma conta? Faça login",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
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