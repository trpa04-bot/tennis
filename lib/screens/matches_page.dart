import 'package:flutter/material.dart';
import '../models/match_model.dart';
import '../models/player.dart';
import '../services/firestore_service.dart';
import 'add_match_page.dart';

class MatchesPage extends StatefulWidget {
  const MatchesPage({super.key});

  @override
  State<MatchesPage> createState() => _MatchesPageState();
}

class _MatchesPageState extends State<MatchesPage> {
    void _editMatchDialog(MatchModel match) {
      final set1Controller = TextEditingController(text: match.set1);
      final set2Controller = TextEditingController(text: match.set2);
      final stbController = TextEditingController(text: match.superTieBreak);
      DateTime selectedDate = match.playedAt;

      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Uredi meč'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: set1Controller,
                    decoration: const InputDecoration(labelText: 'Set 1 (npr. 6:2)'),
                  ),
                  TextField(
                    controller: set2Controller,
                    decoration: const InputDecoration(labelText: 'Set 2 (npr. 3:6)'),
                  ),
                  TextField(
                    controller: stbController,
                    decoration: const InputDecoration(labelText: 'Super Tie Break (npr. 10:8)'),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Text('Datum: '),
                      Text('${selectedDate.day}.${selectedDate.month}.${selectedDate.year}'),
                      IconButton(
                        icon: const Icon(Icons.calendar_today),
                        onPressed: () async {
                          final now = DateTime.now();
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime(now.year - 5),
                            lastDate: DateTime(now.year + 1),
                          );
                          if (picked != null) {
                            selectedDate = picked;
                            setState(() {});
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Odustani'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final updatedMatch = MatchModel(
                    id: match.id,
                    player1Id: match.player1Id,
                    player2Id: match.player2Id,
                    player1Name: match.player1Name,
                    player2Name: match.player2Name,
                    set1: set1Controller.text,
                    set2: set2Controller.text,
                    superTieBreak: stbController.text,
                    season: match.season,
                    playedAt: selectedDate,
                    winnerId: match.winnerId,
                  );
                  await firestoreService.updateMatch(updatedMatch);
                  if (context.mounted) Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Meč ažuriran')),
                  );
                },
                child: const Text('Spremi'),
              ),
            ],
          );
        },
      );
    }
  final FirestoreService firestoreService = FirestoreService();

  final List<String> seasons = const [
    'Winter 2026',
    'Summer 2026',
  ];

  String selectedSeason = 'Winter 2026';
  String selectedLeague = '1';

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

  List<Player> _playersForSelectedLeague(List<Player> players) {
    return players
        .where((player) => _normalizeLeague(player.league) == selectedLeague)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  bool _matchBelongsToSelectedLeague(MatchModel match, List<Player> allPlayers) {
    final leaguePlayers = _playersForSelectedLeague(allPlayers);

    final ids = leaguePlayers
        .map((p) => p.id ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();

    final names = leaguePlayers.map((p) => p.name).toSet();

    final hasIds = match.player1Id.isNotEmpty &&
        match.player2Id.isNotEmpty &&
        ids.contains(match.player1Id) &&
        ids.contains(match.player2Id);

    if (hasIds) return true;

    final hasNames = names.contains(match.player1Name) &&
        names.contains(match.player2Name);

    return hasNames;
  }

  /// 🔥 ATP STYLE SCORE FORMAT
  String _buildScore(MatchModel match) {
    final set1 = match.set1.replaceAll(':', '–');
    final set2 = match.set2.replaceAll(':', '–');

    if (match.superTieBreak.isNotEmpty) {
      final stb = match.superTieBreak.replaceAll(':', '–');
      return '${match.season} • $set1 $set2 $stb';
    }

    return '${match.season} • $set1 $set2';
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.'
        '${date.year}';
  }

  void _confirmDeleteMatch(MatchModel match) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Match'),
          content: Text(
            'Delete match ${match.player1Name} vs ${match.player2Name}?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (match.id != null) {
                  await firestoreService.deleteMatch(match.id!);
                }
                if (context.mounted) {
                  Navigator.pop(context);
                }
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Player>>(
      stream: firestoreService.getPlayers(),
      builder: (context, playersSnapshot) {
        final allPlayers = playersSnapshot.data ?? [];
        final playersInLeague = _playersForSelectedLeague(allPlayers);

        return Scaffold(
          appBar: AppBar(
            title: const Text('Matches'),
            centerTitle: true,
          ),
          body: StreamBuilder<List<MatchModel>>(
            stream: firestoreService.getMatches(),
            builder: (context, matchesSnapshot) {
              if (matchesSnapshot.connectionState ==
                      ConnectionState.waiting ||
                  playersSnapshot.connectionState ==
                      ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final allMatches = matchesSnapshot.data ?? [];

              final matches = allMatches.where((match) {
                if (match.season != selectedSeason) return false;
                return _matchBelongsToSelectedLeague(match, allPlayers);
              }).toList()
                ..sort((a, b) => b.playedAt.compareTo(a.playedAt));

              return Column(
                children: [
                  const SizedBox(height: 10),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Season: '),
                      const SizedBox(width: 10),
                      DropdownButton<String>(
                        value: selectedSeason,
                        items: seasons.map((season) {
                          return DropdownMenuItem<String>(
                            value: season,
                            child: Text(season),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() {
                            selectedSeason = value;
                          });
                        },
                      ),
                    ],
                  ),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('League: '),
                      const SizedBox(width: 10),
                      DropdownButton<String>(
                        value: selectedLeague,
                        items: const [
                          DropdownMenuItem(value: '1', child: Text('1. liga')),
                          DropdownMenuItem(value: '2', child: Text('2. liga')),
                          DropdownMenuItem(value: '3', child: Text('3. liga')),
                          DropdownMenuItem(value: '4', child: Text('4. liga')),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() {
                            selectedLeague = value;
                          });
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  Expanded(
                    child: matches.isEmpty
                        ? const Center(
                            child: Text(
                              'Nema mečeva za odabranu ligu i sezonu.',
                            ),
                          )
                        : ListView.builder(
                            itemCount: matches.length,
                            itemBuilder: (context, index) {
                              final match = matches[index];

                              return Card(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                child: ListTile(
                                  title: Text(
                                    '${match.player1Name} vs ${match.player2Name}',
                                  ),
                                  subtitle: Text(
                                    '${_buildScore(match)}\n${_formatDate(match.playedAt)}\n${_leagueLabel(selectedLeague)}',
                                  ),
                                  isThreeLine: true,
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit),
                                        tooltip: 'Uredi meč',
                                        onPressed: () => _editMatchDialog(match),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete),
                                        tooltip: 'Obriši meč',
                                        onPressed: () => _confirmDeleteMatch(match),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () {
              if (playersInLeague.length < 2) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Trebaš barem 2 igrača u odabranoj ligi.',
                    ),
                  ),
                );
                return;
              }

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AddMatchPage(),
                ),
              );
            },
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }
}