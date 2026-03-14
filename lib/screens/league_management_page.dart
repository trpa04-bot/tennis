import 'package:flutter/material.dart';
import '../models/player.dart';
import '../services/firestore_service.dart';
import 'add_match_page.dart';

class LeagueManagementPage extends StatefulWidget {
  const LeagueManagementPage({super.key});

  @override
  State<LeagueManagementPage> createState() => _LeagueManagementPageState();
}

class _LeagueManagementPageState extends State<LeagueManagementPage> {
  final FirestoreService firestoreService = FirestoreService();

  String _normalizeLeague(String league) {
    final value = league.trim().toLowerCase();

    if (value == '1' || value == '1. liga') return '1';
    if (value == '2' || value == '2. liga') return '2';
    if (value == '3' || value == '3. liga') return '3';
    if (value == '4' || value == '4. liga') return '4';

    return league;
  }

  String _leagueLabel(String league) {
    switch (_normalizeLeague(league)) {
      case '1':
        return '1. liga';
      case '2':
        return '2. liga';
      case '3':
        return '3. liga';
      case '4':
        return '4. liga';
      default:
        return league;
    }
  }

  List<Player> _playersForLeague(List<Player> players, String league) {
    return players
        .where((p) => _normalizeLeague(p.league) == league)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  Future<void> _movePlayerToLeague(Player player, String newLeague) async {
    final updatedPlayer = Player(
      id: player.id,
      name: player.name,
      rating: player.rating,
      league: newLeague,
    );

    await firestoreService.updatePlayer(updatedPlayer);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${player.name} prebačen u ${_leagueLabel(newLeague)}.',
        ),
      ),
    );
  }

  void _openMoveDialog(Player player) {
    String selectedLeague = _normalizeLeague(player.league);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Premjesti igrača'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    player.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    value: selectedLeague,
                    decoration: const InputDecoration(
                      labelText: 'Nova liga',
                    ),
                    items: const [
                      DropdownMenuItem(value: '1', child: Text('1. liga')),
                      DropdownMenuItem(value: '2', child: Text('2. liga')),
                      DropdownMenuItem(value: '3', child: Text('3. liga')),
                      DropdownMenuItem(value: '4', child: Text('4. liga')),
                    ],
                    onChanged: (value) {
                      if (value == null) return;

                      setDialogState(() {
                        selectedLeague = value;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Odustani'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    await _movePlayerToLeague(player, selectedLeague);

                    if (!context.mounted) return;

                    Navigator.pop(context);
                  },
                  child: const Text('Spremi'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmDelete(Player player) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Obriši igrača'),
          content: Text('Želiš obrisati ${player.name} iz aplikacije?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Odustani'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (player.id != null && player.id!.isNotEmpty) {
                  await firestoreService.deletePlayer(player.id!);
                }

                if (!context.mounted) return;

                Navigator.pop(context);

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${player.name} je obrisan.'),
                  ),
                );
              },
              child: const Text('Obriši'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLeagueCard({
    required String league,
    required List<Player> players,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _leagueLabel(league),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.green.shade50,
                  ),
                  child: Text(
                    '${players.length} igrača',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (players.isEmpty)
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Nema igrača u ovoj ligi.'),
              )
            else
              ...players.map(
                (player) => Card(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  child: ListTile(
                    title: Text(player.name),
                    subtitle: Text(
                      'Rating ${player.rating} • ${_leagueLabel(player.league)}',
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'move') {
                          _openMoveDialog(player);
                        } else if (value == 'delete') {
                          _confirmDelete(player);
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: 'move',
                          child: Text('Premjesti u drugu ligu'),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Text('Obriši igrača'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'League Management',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text(
              'Ovdje možeš ručno prebacivati igrače između liga zbog odustajanja, wildcard ulaska, ozljede ili organizacijske odluke.',
            ),
            SizedBox(height: 8),
            Text(
              'Admin uvijek mora imati zadnju riječ.',
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Player>>(
      stream: firestoreService.getPlayers(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final players = snapshot.data ?? [];

        final league1 = _playersForLeague(players, '1');
        final league2 = _playersForLeague(players, '2');
        final league3 = _playersForLeague(players, '3');
        final league4 = _playersForLeague(players, '4');

        return Scaffold(
          appBar: AppBar(
            title: const Text('League Management'),
            centerTitle: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.sports_tennis),
                tooltip: "Add Match",
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AddMatchPage(),
                    ),
                  );
                },
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildInfoCard(),
              const SizedBox(height: 12),
              _buildLeagueCard(league: '1', players: league1),
              const SizedBox(height: 12),
              _buildLeagueCard(league: '2', players: league2),
              const SizedBox(height: 12),
              _buildLeagueCard(league: '3', players: league3),
              const SizedBox(height: 12),
              _buildLeagueCard(league: '4', players: league4),
            ],
          ),
        );
      },
    );
  }
}