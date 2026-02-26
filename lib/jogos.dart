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
  
  bool _isLoading = false;
  bool _isAdmin = false;
  bool _initialized = false; 
  String _meuUsername = ""; 

  // --- SELETORES ---
  String _esporteSelecionado = 'Futebol';
  String _localSelecionado = 'Ginásio';
  String _horarioSelecionado = '09:00';

  final List<String> _esportes = ['Futebol', 'Vôlei', 'Basquete'];
  final List<String> _locais = ['Ginásio', 'Campo 1', 'Campo 2', 'Quadra Poliesportiva'];
  final List<String> _horarios = List.generate(14, (i) => '${(i + 9).toString().padLeft(2, '0')}:00');

  Stream<List<Map<String, dynamic>>>? _gamesStream;

  @override
  void initState() {
    super.initState();
    _inicializarPagina();
  }

  Future<void> _inicializarPagina() async {
    try {
      await Future.delayed(const Duration(milliseconds: 800));
      final user = _supabase.auth.currentUser;

      if (user == null) {
        if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginPage()));
        return;
      }

      final data = await _supabase.from('profiles').select().eq('id', user.id).maybeSingle();

      if (mounted) {
        setState(() {
          _isAdmin = data?['is_admin'] ?? false;
          _meuUsername = data?['username'] ?? data?['full_name'] ?? "Jogador";
          _gamesStream = _supabase.from('games').stream(primaryKey: ['id']).order('created_at', ascending: false);
          _initialized = true; 
        });
      }
    } catch (e) {
      if (mounted) setState(() => _initialized = true);
    }
  }

  // --- AÇÕES DO BANCO ---

  Future<void> _entrarNoJogo(String gameId) async {
    try {
      await _supabase.from('participants').insert({
        'game_id': gameId,
        'user_id': _supabase.auth.currentUser!.id,
        'user_name': _meuUsername,
      });
      _notificar('Você entrou no jogo!', Colors.green);
    } catch (e) {
      _notificar('Erro ao entrar ou você já está na lista.', Colors.orange);
    }
  }

  Future<void> _sairDoJogo(String gameId) async {
    try {
      await _supabase.from('participants').delete().match({
        'game_id': gameId,
        'user_id': _supabase.auth.currentUser!.id,
      });
      _notificar('Você saiu do jogo.', Colors.grey);
    } catch (e) {
      _notificar('Erro ao sair.', Colors.red);
    }
  }

  // --- MODAL DA SALA COM LÓGICA DE BOTÃO DINÂMICO ---

  void _abrirSala(Map<String, dynamic> game) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) {
        final meuId = _supabase.auth.currentUser?.id;

        return Container(
          padding: const EdgeInsets.all(24),
          height: MediaQuery.of(context).size.height * 0.6,
          child: Column(
            children: [
              Text(game['name'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0D47A1))),
              const Divider(),
              const SizedBox(height: 10),
              const Text("Jogadores Confirmados:", style: TextStyle(color: Colors.grey, fontSize: 13)),
              
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _supabase.from('participants').select().eq('game_id', game['id']),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    
                    final lista = snapshot.data ?? [];
                    
                    // LÓGICA: Verifica se o meu ID está na lista que veio do banco
                    bool euJaEstouNaLista = lista.any((p) => p['user_id'] == meuId);

                    return Column(
                      children: [
                        Expanded(
                          child: lista.isEmpty 
                            ? const Center(child: Text("Ninguém na lista ainda."))
                            : ListView.builder(
                                itemCount: lista.length,
                                itemBuilder: (context, i) => ListTile(
                                  leading: const CircleAvatar(child: Icon(Icons.person, size: 20)),
                                  title: Text(lista[i]['user_name'] ?? 'Anônimo'),
                                  trailing: lista[i]['user_id'] == meuId 
                                    ? const Icon(Icons.check_circle, color: Colors.green) 
                                    : null,
                                ),
                              ),
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // EXIBIÇÃO CONDICIONAL DOS BOTÕES
                        if (!euJaEstouNaLista) 
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                              onPressed: () => _entrarNoJogo(game['id'].toString()).then((_) => Navigator.pop(context)),
                              child: const Text("PARTICIPAR DO JOGO", style: TextStyle(color: Colors.white)),
                            ),
                          )
                        else
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)),
                              onPressed: () => _sairDoJogo(game['id'].toString()).then((_) => Navigator.pop(context)),
                              icon: const Icon(Icons.exit_to_app, color: Colors.red),
                              label: const Text("SAIR DA LISTA", style: TextStyle(color: Colors.red)),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- RESTANTE DA INTERFACE ---

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Scaffold(
        backgroundColor: Color(0xFF1B263B),
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF1B263B),
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(_isAdmin ? 'Gestão de Reservas' : 'Partidas de Hoje', 
          style: const TextStyle(color: Color(0xFF0D47A1), fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            onPressed: () => _supabase.auth.signOut().then((_) => 
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginPage()))),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            if (_isAdmin) _buildFormulario(),
            const SizedBox(height: 25),
            const Text("Toque no jogo para entrar na lista", style: TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 10),
            _buildListaRealtime(),
          ],
        ),
      ),
    );
  }

  Widget _buildFormulario() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
      child: Column(
        children: [
          _buildDrop("Esporte", Icons.sports_soccer, _esporteSelecionado, _esportes, (v) => setState(() => _esporteSelecionado = v!)),
          const SizedBox(height: 10),
          _buildDrop("Local", Icons.location_on, _localSelecionado, _locais, (v) => setState(() => _localSelecionado = v!)),
          const SizedBox(height: 10),
          _buildDrop("Horário", Icons.access_time, _horarioSelecionado, _horarios, (v) => setState(() => _horarioSelecionado = v!)),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 45,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _salvarJogo,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1976D2)),
              child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("CRIAR JOGO", style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrop(String label, IconData icon, String value, List<String> items, Function(String?) onChanged) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildListaRealtime() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _gamesStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.white));
        final games = snapshot.data!;
        if (games.isEmpty) return const Text("Nenhum jogo criado.", style: TextStyle(color: Colors.white54));

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: games.length,
          itemBuilder: (context, index) {
            final g = games[index];
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 6),
              child: ListTile(
                onTap: () => _abrirSala(g),
                leading: Icon(g['name'].contains('Futebol') ? Icons.sports_soccer : Icons.sports_basketball, color: Colors.blue),
                title: Text(g['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                trailing: _isAdmin 
                  ? IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _supabase.from('games').delete().match({'id': g['id']}))
                  : const Icon(Icons.chevron_right),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _salvarJogo() async {
    final nomeFinal = "$_esporteSelecionado - $_localSelecionado - $_horarioSelecionado";
    setState(() => _isLoading = true);
    try {
      await _supabase.from('games').insert({'name': nomeFinal});
      _notificar('Jogo criado!', Colors.green);
    } catch (e) {
      _notificar('Erro: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _notificar(String msg, Color cor) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: cor));
  }
}