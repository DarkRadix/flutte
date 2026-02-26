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

      // BUSCA DE PERFIL: Agora focada em pegar o 'username' que salvamos no cadastro
      final data = await _supabase.from('profiles').select().eq('id', user.id).maybeSingle();

      if (mounted) {
        setState(() {
          _isAdmin = data?['is_admin'] ?? false;
          
          // LÓGICA DE NOME: 
          // 1. Tenta o username do banco (profiles)
          // 2. Tenta o display_name dos metadados do Auth
          // 3. Se tudo falhar, usa "Jogador"
          _meuUsername = data?['username'] ?? 
                         user.userMetadata?['display_name'] ?? 
                         "Jogador";
          
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
      // Inserimos o nome correto que buscamos no _inicializarPagina
      await _supabase.from('participants').insert({
        'game_id': gameId,
        'user_id': _supabase.auth.currentUser!.id,
        'user_name': _meuUsername, 
      });
      _notificar('Você entrou na lista!', Colors.green);
    } catch (e) {
      _notificar('Erro ao entrar na lista.', Colors.orange);
    }
  }

  Future<void> _sairDoJogo(String gameId) async {
    try {
      await _supabase.from('participants').delete().match({
        'game_id': gameId,
        'user_id': _supabase.auth.currentUser!.id,
      });
      _notificar('Você saiu da lista.', Colors.grey);
    } catch (e) {
      _notificar('Erro ao sair.', Colors.red);
    }
  }

  // --- MODAL DA SALA (DETALHES) ---

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
              const Text("Confirmados:", style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold)),
              
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _supabase.from('participants').select().eq('game_id', game['id']),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    
                    final lista = snapshot.data ?? [];
                    bool euJaEstouNaLista = lista.any((p) => p['user_id'] == meuId);

                    return Column(
                      children: [
                        Expanded(
                          child: lista.isEmpty 
                            ? const Center(child: Text("Ninguém confirmou ainda."))
                            : ListView.builder(
                                itemCount: lista.length,
                                itemBuilder: (context, i) {
                                  final isMe = lista[i]['user_id'] == meuId;
                                  return ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: isMe ? Colors.blue : Colors.grey[200],
                                      child: Icon(Icons.person, size: 20, color: isMe ? Colors.white : Colors.grey),
                                    ),
                                    title: Text(
                                      lista[i]['user_name'] ?? 'Anônimo',
                                      style: TextStyle(fontWeight: isMe ? FontWeight.bold : FontWeight.normal),
                                    ),
                                    trailing: isMe ? const Icon(Icons.check_circle, color: Colors.green) : null,
                                  );
                                },
                              ),
                        ),
                        
                        const SizedBox(height: 20),
                        
                        if (!euJaEstouNaLista) 
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.all(15)),
                              onPressed: () => _entrarNoJogo(game['id'].toString()).then((_) => Navigator.pop(context)),
                              icon: const Icon(Icons.add_task, color: Colors.white),
                              label: const Text("CONFIRMAR MINHA PRESENÇA", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ),
                          )
                        else
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red), padding: const EdgeInsets.all(15)),
                              onPressed: () => _sairDoJogo(game['id'].toString()).then((_) => Navigator.pop(context)),
                              icon: const Icon(Icons.exit_to_app, color: Colors.red),
                              label: const Text("RETIRAR MEU NOME", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
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

  // --- INTERFACE PRINCIPAL ---

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
        elevation: 0,
        title: Text(_isAdmin ? 'Painel Administrativo' : 'Partidas Disponíveis', 
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Olá, $_meuUsername!", style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 5),
            const Text("Organize ou participe de partidas hoje.", style: TextStyle(color: Colors.white60, fontSize: 14)),
            const SizedBox(height: 25),
            if (_isAdmin) ...[
              const Text("CRIAR NOVA PARTIDA", style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 10),
              _buildFormulario(),
              const SizedBox(height: 30),
            ],
            const Text("PARTIDAS ATIVAS", style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 12)),
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
            height: 50,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _salvarJogo,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D47A1), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("PUBLICAR JOGO", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrop(String label, IconData icon, String value, List<String> items, Function(String?) onChanged) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon, color: Colors.blue)),
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
        if (games.isEmpty) return const Center(child: Text("Nenhum jogo disponível no momento.", style: TextStyle(color: Colors.white54)));

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: games.length,
          itemBuilder: (context, index) {
            final g = games[index];
            final bool isFutebol = g['name'].toString().contains('Futebol');
            return Card(
              elevation: 3,
              margin: const EdgeInsets.symmetric(vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                onTap: () => _abrirSala(g),
                leading: CircleAvatar(
                  backgroundColor: Colors.blue[50],
                  child: Icon(isFutebol ? Icons.sports_soccer : Icons.sports_basketball, color: Colors.blue),
                ),
                title: Text(g['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text("Toque para ver quem vai"),
                trailing: _isAdmin 
                  ? IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => _supabase.from('games').delete().match({'id': g['id']}))
                  : const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
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
      _notificar('Partida criada com sucesso!', Colors.green);
    } catch (e) {
      _notificar('Erro ao criar partida.', Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _notificar(String msg, Color cor) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: cor, behavior: SnackBarBehavior.floating));
  }
}