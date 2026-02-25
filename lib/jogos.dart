import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login.dart';

class JogosPage extends StatefulWidget {
  const JogosPage({super.key});

  @override
  State<JogosPage> createState() => _JogosPageState();
}

class _JogosPageState extends State<JogosPage> {
  final _supabase = Supabase.instance.client;
  final _nomeController = TextEditingController();
  bool _isLoading = false;

  // 1. Mudamos a forma de declarar a Stream para evitar o erro de carregamento infinito
  late Stream<List<Map<String, dynamic>>> _gamesStream;

  @override
  void initState() {
    super.initState();
    _inicializarStream();
  }

  // 2. Criamos uma função separada para a Stream para facilitar o controle
  void _inicializarStream() {
    _gamesStream = _supabase
        .from('games')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false);
  }

  Future<void> _salvarJogo() async {
    final nome = _nomeController.text.trim();
    if (nome.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      await _supabase.from('games').insert({'name': nome});
      _nomeController.clear();
      FocusScope.of(context).unfocus();
    } catch (e) {
      _mostrarErro('Erro ao cadastrar: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 3. Função de exclusão otimizada
  Future<void> _excluirJogo(String id) async {
    try {
      // O StreamBuilder vai detectar a remoção no banco e atualizar a UI sozinho
      await _supabase.from('games').delete().match({'id': id});

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Removido com sucesso!'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      _mostrarErro('Erro ao deletar: $e');
    }
  }

  void _mostrarErro(String mensagem) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensagem), backgroundColor: Colors.redAccent),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1B263B),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Admin Dashboard',
          style: TextStyle(
            color: Color(0xFF0D47A1),
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () => _supabase.auth.signOut().then(
              (_) => Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginPage()),
              ),
            ),
            icon: const Icon(Icons.logout, color: Colors.redAccent),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // Formulário de Cadastro
            _buildCadastroCard(),
            const SizedBox(height: 30),

            // LISTA COM TRATAMENTO DE ERRO (Evita o carregamento infinito)
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: _gamesStream,
              builder: (context, snapshot) {
                // Caso aconteça um erro (o que causa a tela azul infinita)
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      children: [
                        const Text(
                          "Erro de conexão com o banco.",
                          style: TextStyle(color: Colors.white),
                        ),
                        TextButton(
                          onPressed: () => setState(() => _inicializarStream()),
                          child: const Text("Tentar Novamente"),
                        ),
                      ],
                    ),
                  );
                }

                // Enquanto espera os dados
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  );
                }

                final games = snapshot.data ?? [];

                if (games.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.only(top: 20),
                    child: Text(
                      "Nenhum jogo cadastrado.",
                      style: TextStyle(color: Colors.white54),
                    ),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: games.length,
                  itemBuilder: (context, index) {
                    final game = games[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: ListTile(
                        leading: const Icon(
                          Icons.gamepad,
                          color: Color(0xFF1976D2),
                        ),
                        title: Text(
                          game['name'] ?? 'N/A',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        trailing: IconButton(
                          icon: const Icon(
                            Icons.delete_sweep,
                            color: Colors.redAccent,
                          ),
                          onPressed: () => _excluirJogo(game['id'].toString()),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCadastroCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          TextField(
            controller: _nomeController,
            decoration: const InputDecoration(
              labelText: "Nome da Sala/Jogo",
              prefixIcon: Icon(Icons.add),
            ),
          ),
          const SizedBox(height: 15),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _salvarJogo,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1976D2),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      "CADASTRAR",
                      style: TextStyle(color: Colors.white),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
