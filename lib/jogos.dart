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

  List<Map<String, dynamic>> _meusConvites = [];

  String _esporteSelecionado = 'Futebol';
  String _localSelecionado = 'Ginásio';
  String _horarioSelecionado = '09:00';
  DateTime _dataSelecionada = DateTime.now();

  final List<String> _esportes = ['Futebol', 'Vôlei', 'Basquete'];
  final List<String> _locais = [
    'Ginásio',
    'Campo 1',
    'Campo 2',
    'Quadra Poliesportiva',
  ];
  final List<String> _horarios = List.generate(
    14,
    (i) => '${(i + 9).toString().padLeft(2, '0')}:00',
  );

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
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const LoginPage()),
          );
        }
        return;
      }

      final String? nomeAuth =
          user.userMetadata?['full_name'] ?? user.userMetadata?['name'];
      final data = await _supabase
          .from('profiles')
          .select('username, is_admin')
          .eq('id', user.id)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _isAdmin = data?['is_admin'] ?? false;
          _meuUsername =
              nomeAuth ?? data?['username'] ?? user.email ?? "Jogador";
          _gamesStream = _supabase
              .from('games')
              .stream(primaryKey: ['id'])
              .order('created_at', ascending: false);
          _initialized = true;
        });
        _buscarConvites();
      }
    } catch (e) {
      if (mounted) setState(() => _initialized = true);
    }
  }

  Future<void> _buscarConvites() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    final data = await _supabase
        .from('invites')
        .select()
        .eq('receiver_id', user.id)
        .eq('status', 'pending');

    if (mounted) {
      setState(() {
        _meusConvites = List<Map<String, dynamic>>.from(data);
      });
    }
  }
  Future<void> _selecionarData() async {
    if (!mounted) return;
    FocusScope.of(context).unfocus();
    final DateTime hoje = DateTime.now();
    final DateTime? colhida = await showDatePicker(
      context: context,
      initialDate: _dataSelecionada.isBefore(hoje) ? hoje : _dataSelecionada,
      firstDate: hoje,
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF0D47A1),
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (colhida != null && mounted) {
      setState(() => _dataSelecionada = colhida);
    }
  }

  void _abrirPainelConvites() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "MEUS CONVITES",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0D47A1),
                    ),
                  ),
                  const Divider(),
                  if (_meusConvites.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(20.0),
                      child: Text("Nenhum convite novo."),
                    ),
                  ..._meusConvites.map(
                    (inv) => ListTile(
                      leading: const Icon(
                        Icons.mail_outline,
                        color: Colors.blue,
                      ),
                      title: Text(inv['game_name']),
                      subtitle: Text("De: ${inv['sender_name']}"),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.check_circle,
                              color: Colors.green,
                            ),
                            onPressed: () async {
                              await _entrarNoJogo(inv['game_id'].toString());
                              await _supabase
                                  .from('invites')
                                  .delete()
                                  .eq('id', inv['id']);
                              await _buscarConvites();
                              if (mounted) Navigator.pop(context);
                              _notificar("Convite aceito!", Colors.green);
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.cancel, color: Colors.red),
                            onPressed: () async {
                              await _supabase
                                  .from('invites')
                                  .delete()
                                  .eq('id', inv['id']);
                              await _buscarConvites();
                              if (mounted) Navigator.pop(context);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _abrirListaParaConvidar(Map<String, dynamic> game) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Text(
                "CONVIDAR JOGADORES",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0D47A1),
                ),
              ),
              const Divider(),
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _supabase.from('profiles').select('id, username'),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting)
                      return const Center(child: CircularProgressIndicator());
                    final usuarios = snapshot.data ?? [];
                    final meuId = _supabase.auth.currentUser?.id;
                    final outrosJogadores = usuarios
                        .where((u) => u['id'] != meuId)
                        .toList();
                    return ListView.builder(
                      itemCount: outrosJogadores.length,
                      itemBuilder: (context, i) {
                        final userRow = outrosJogadores[i];
                        return ListTile(
                          leading: const CircleAvatar(
                            child: Icon(Icons.person),
                          ),
                          title: Text(userRow['username'] ?? "Jogador"),
                          trailing: const Icon(Icons.send, color: Colors.blue),
                          onTap: () async {
                            try {
                              await _supabase.from('invites').insert({
                                'game_id': game['id'],
                                'sender_id': _supabase.auth.currentUser!.id,
                                'receiver_id': userRow['id'],
                                'game_name': game['name'],
                                'sender_name': _meuUsername,
                              });
                              if (mounted) Navigator.pop(context);
                              _notificar("Convite enviado!", Colors.green);
                            } catch (e) {
                              _notificar("Erro ao enviar.", Colors.red);
                            }
                          },
                        );
                      },
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

  Future<void> _entrarNoJogo(String gameId) async {
    try {
      await _supabase.from('participants').insert({
        'game_id': gameId,
        'user_id': _supabase.auth.currentUser!.id,
        'user_name': _meuUsername,
      });
    } catch (e) {
      _notificar('Você já está na lista!', Colors.orange);
    }
  }

  void _abrirSala(Map<String, dynamic> game) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        final meuId = _supabase.auth.currentUser?.id;
        return Container(
          padding: const EdgeInsets.all(24),
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      game['name'],
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0D47A1),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.person_add_alt_1,
                      color: Colors.blue,
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      _abrirListaParaConvidar(game);
                    },
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _supabase
                      .from('participants')
                      .select()
                      .eq('game_id', game['id']),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting)
                      return const Center(child: CircularProgressIndicator());
                    final lista = snapshot.data ?? [];
                    bool euJaEstouNaLista = lista.any(
                      (p) => p['user_id'] == meuId,
                    );
                    return Column(
                      children: [
                        Expanded(
                          child: lista.isEmpty
                              ? const Center(
                                  child: Text("Ninguém confirmou ainda."),
                                )
                              : ListView.builder(
                                  itemCount: lista.length,
                                  itemBuilder: (context, i) {
                                    final isMe = lista[i]['user_id'] == meuId;
                                    return ListTile(
                                      leading: Icon(
                                        Icons.check_circle,
                                        color: isMe
                                            ? Colors.blue
                                            : Colors.green,
                                      ),
                                      title: Text(lista[i]['user_name']),
                                    );
                                  },
                                ),
                        ),
                        const SizedBox(height: 20),
                        if (!euJaEstouNaLista)
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              minimumSize: const Size(double.infinity, 50),
                            ),
                            onPressed: () => _entrarNoJogo(
                              game['id'].toString(),
                            ).then((_) => Navigator.pop(context)),
                            child: const Text(
                              "CONFIRMAR PRESENÇA",
                              style: TextStyle(color: Colors.white),
                            ),
                          )
                        else
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.red),
                              minimumSize: const Size(double.infinity, 50),
                            ),
                            onPressed: () => _sairDoJogo(
                              game['id'].toString(),
                            ).then((_) => Navigator.pop(context)),
                            child: const Text(
                              "SAIR DA LISTA",
                              style: TextStyle(color: Colors.red),
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
  Future<void> _salvarJogo() async {
    final nomeFinal =
        "$_esporteSelecionado - ${_dataSelecionada.day}/${_dataSelecionada.month} - $_horarioSelecionado";
    setState(() => _isLoading = true);
    try {
      await _supabase.from('games').insert({'name': nomeFinal});
      _notificar('Partida criada!', Colors.green);
    } catch (e) {
      _notificar('Erro ao criar.', Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  void _notificar(String msg, Color cor) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: cor));
  }
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
        title: const Text(
          'Arena de Jogos',
          style: TextStyle(
            color: Color(0xFF0D47A1),
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications, color: Colors.blue),
                onPressed: _abrirPainelConvites,
              ),
              if (_meusConvites.isNotEmpty)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      '${_meusConvites.length}',
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            onPressed: () => _supabase.auth.signOut().then(
              (_) => Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginPage()),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _buscarConvites,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Olá, $_meuUsername!",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 25),
              const Text(
                "CRIAR NOVA PARTIDA",
                style: TextStyle(
                  color: Colors.blueAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 10),
              _buildFormulario(),
              const SizedBox(height: 30),
              const Text(
                "PARTIDAS ATIVAS",
                style: TextStyle(
                  color: Colors.blueAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 10),
              _buildListaRealtime(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormulario() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          _buildDrop(
            "Esporte",
            Icons.sports_soccer,
            _esporteSelecionado,
            _esportes,
            (v) => setState(() => _esporteSelecionado = v!),
          ),
          const SizedBox(height: 10),
          _buildDrop(
            "Local",
            Icons.location_on,
            _localSelecionado,
            _locais,
            (v) => setState(() => _localSelecionado = v!),
          ),
          const SizedBox(height: 10),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.calendar_today, color: Colors.blue),
            title: Text(
              "Data: ${_dataSelecionada.day}/${_dataSelecionada.month}",
            ),
            trailing: const Icon(Icons.edit, size: 16),
            onTap: _selecionarData,
          ),
          _buildDrop(
            "Horário",
            Icons.access_time,
            _horarioSelecionado,
            _horarios,
            (v) => setState(() => _horarioSelecionado = v!),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _isLoading ? null : _salvarJogo,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D47A1),
              minimumSize: const Size(double.infinity, 50),
            ),
            child: _isLoading
                ? const CircularProgressIndicator()
                : const Text(
                    "PUBLICAR JOGO",
                    style: TextStyle(color: Colors.white),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrop(
    String label,
    IconData icon,
    String value,
    List<String> items,
    Function(String?) onChanged,
  ) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.blue),
      ),
      items: items
          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
          .toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildListaRealtime() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _gamesStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        final games = snapshot.data!;
        if (games.isEmpty)
          return const Center(
            child: Text(
              "Nenhuma partida ativa.",
              style: TextStyle(color: Colors.white54),
            ),
          );
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: games.length,
          itemBuilder: (context, index) {
            final g = games[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                onTap: () => _abrirSala(g),
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFE3F2FD),
                  child: Icon(Icons.sports_soccer, color: Colors.blue),
                ),
                title: Text(
                  g['name'],
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text("Toque para ver detalhes"),
                trailing: _isAdmin
                    ? IconButton(
                        icon: const Icon(Icons.delete, color: Colors.redAccent),
                        onPressed: () =>
                            _supabase.from('games').delete().eq('id', g['id']),
                      )
                    : const Icon(Icons.arrow_forward_ios, size: 14),
              ),
            );
          },
        );
      },
    );
  }
}
