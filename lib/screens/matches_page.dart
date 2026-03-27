import 'package:flutter/material.dart';
import '../utils/league_utils.dart';
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
  String _winnerIdFromScores({
    required MatchModel match,
    required String set1,
    required String set2,
    required String superTieBreak,
  }) {
    int player1Sets = 0;
    int player2Sets = 0;

    for (final raw in [set1, set2]) {
      final parsed = _parseSetScore(raw);
      if (parsed == null) continue;
      if (parsed[0] > parsed[1]) player1Sets++;
      if (parsed[1] > parsed[0]) player2Sets++;
    }

    final parsedStb = _parseSetScore(superTieBreak);
    if (parsedStb != null && player1Sets == player2Sets) {
      if (parsedStb[0] > parsedStb[1]) player1Sets++;
      if (parsedStb[1] > parsedStb[0]) player2Sets++;
    }

    if (player1Sets == player2Sets) return '';
    return player1Sets > player2Sets ? match.player1Id : match.player2Id;
  }

  void _editMatchDialog(MatchModel match) {
    final pageContext = context;
    final set1Controller = TextEditingController(text: match.set1);
    final set2Controller = TextEditingController(text: match.set2);
    final stbController = TextEditingController(text: match.superTieBreak);
    DateTime selectedDate = match.playedAt;
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Uredi meč'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: set1Controller,
                      decoration: const InputDecoration(
                        labelText: 'Set 1 (npr. 6:2)',
                      ),
                    ),
                    TextField(
                      controller: set2Controller,
                      decoration: const InputDecoration(
                        labelText: 'Set 2 (npr. 3:6)',
                      ),
                    ),
                    TextField(
                      controller: stbController,
                      decoration: const InputDecoration(
                        labelText: 'Super Tie Break (npr. 10:8)',
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Text('Datum: '),
                        Expanded(
                          child: Text(
                            '${selectedDate.day}.${selectedDate.month}.${selectedDate.year}',
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.calendar_today),
                          onPressed: isSaving
                              ? null
                              : () async {
                                  final now = DateTime.now();
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: selectedDate,
                                    firstDate: DateTime(now.year - 5),
                                    lastDate: DateTime(now.year + 1),
                                  );
                                  if (picked != null) {
                                    setDialogState(() {
                                      selectedDate = picked;
                                    });
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
                  onPressed: isSaving ? null : () => Navigator.pop(context),
                  child: const Text('Odustani'),
                ),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          final set1 = set1Controller.text.trim();
                          final set2 = set2Controller.text.trim();
                          final superTieBreak = stbController.text.trim();
                          final winnerId = _winnerIdFromScores(
                            match: match,
                            set1: set1,
                            set2: set2,
                            superTieBreak: superTieBreak,
                          );

                          if (winnerId.isEmpty) {
                            ScaffoldMessenger.of(pageContext).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Rezultat nije valjan. Provjeri setove i tie-break.',
                                ),
                              ),
                            );
                            return;
                          }

                          setDialogState(() {
                            isSaving = true;
                          });

                          final updatedMatch = MatchModel(
                            id: match.id,
                            player1Id: match.player1Id,
                            player2Id: match.player2Id,
                            player1Name: match.player1Name,
                            player2Name: match.player2Name,
                            league: match.league,
                            set1: set1,
                            set2: set2,
                            superTieBreak: superTieBreak,
                            season: match.season,
                            playedAt: selectedDate,
                            winnerId: winnerId,
                            simpleMode: match.simpleMode,
                            resultLabel: match.resultLabel,
                          );
                          try {
                            await firestoreService.updateMatch(updatedMatch);
                            await firestoreService
                                .rebuildDerivedDataFromMatches();

                            if (!pageContext.mounted) return;
                            Navigator.pop(pageContext);
                            ScaffoldMessenger.of(pageContext).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Meč ažuriran i statistike su usklađene',
                                ),
                              ),
                            );
                          } catch (_) {
                            if (!pageContext.mounted) return;
                            ScaffoldMessenger.of(pageContext).showSnackBar(
                              const SnackBar(
                                content: Text('Greška pri ažuriranju meča.'),
                              ),
                            );
                          } finally {
                            if (context.mounted) {
                              setDialogState(() {
                                isSaving = false;
                              });
                            }
                          }
                        },
                  child: Text(isSaving ? 'Spremanje...' : 'Spremi'),
                ),
              ],
            );
          },
        );
      },
    ).whenComplete(() {
      set1Controller.dispose();
      set2Controller.dispose();
      stbController.dispose();
    });
  }

  final FirestoreService firestoreService = FirestoreService();

  final List<String> seasons = const ['Winter 2026', 'Summer 2026'];

  String selectedSeason = 'Winter 2026';
  String selectedLeague = '1';

  String _normalizeLeague(String league) => LeagueUtils.normalize(league);
  String _leagueLabel(String league) => LeagueUtils.label(league);

  List<Player> _playersForSelectedLeague(List<Player> players) {
    return players
        .where((player) => _normalizeLeague(player.league) == selectedLeague)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  bool _matchBelongsToSelectedLeague(
    MatchModel match,
    List<Player> allPlayers,
  ) {
    if (_normalizeLeague(match.league) == selectedLeague) {
      return true;
    }

    final leaguePlayers = _playersForSelectedLeague(allPlayers);

    final ids = leaguePlayers
        .map((p) => p.id ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();

    final names = leaguePlayers.map((p) => p.name).toSet();

    final hasIds =
        match.player1Id.isNotEmpty &&
        match.player2Id.isNotEmpty &&
        ids.contains(match.player1Id) &&
        ids.contains(match.player2Id);

    if (hasIds) return true;

    final hasNames =
        names.contains(match.player1Name) && names.contains(match.player2Name);

    return hasNames;
  }

  /// 🔥 ATP STYLE SCORE FORMAT
  String _buildScore(MatchModel match) {
    if (match.simpleMode && match.resultLabel.trim().isNotEmpty) {
      return '${match.season} • ${match.resultLabel}';
    }

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

  List<int>? _parseSetScore(String score) {
    final cleaned = score.trim().replaceAll(' ', '');
    if (cleaned.isEmpty) return null;

    final normalized = cleaned.replaceAll('-', ':').replaceAll('/', ':');
    final parts = normalized.split(':');
    if (parts.length != 2) return null;

    final a = int.tryParse(parts[0]);
    final b = int.tryParse(parts[1]);
    if (a == null || b == null) return null;

    return [a, b];
  }

  String? _winnerName(MatchModel match) {
    if (match.winnerId.isNotEmpty) {
      if (match.winnerId == match.player1Id) return match.player1Name;
      if (match.winnerId == match.player2Id) return match.player2Name;
    }

    int p1Sets = 0;
    int p2Sets = 0;

    for (final raw in [match.set1, match.set2]) {
      final set = _parseSetScore(raw);
      if (set == null) continue;
      if (set[0] > set[1]) p1Sets++;
      if (set[1] > set[0]) p2Sets++;
    }

    final stb = _parseSetScore(match.superTieBreak);
    if (stb != null && p1Sets == p2Sets) {
      if (stb[0] > stb[1]) p1Sets++;
      if (stb[1] > stb[0]) p2Sets++;
    }

    if (p1Sets == p2Sets) return null;
    return p1Sets > p2Sets ? match.player1Name : match.player2Name;
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

  List<int>? _parseScore(String score) {
    final cleaned = score.trim().replaceAll(' ', '');
    if (cleaned.isEmpty) return null;

    final normalized = cleaned.replaceAll('-', ':').replaceAll('/', ':');
    final parts = normalized.split(':');
    if (parts.length != 2) return null;

    final a = int.tryParse(parts[0]);
    final b = int.tryParse(parts[1]);
    if (a == null || b == null) return null;

    return [a, b];
  }

  bool _samePair(MatchModel a, MatchModel b) {
    if (a.player1Id.isNotEmpty &&
        a.player2Id.isNotEmpty &&
        b.player1Id.isNotEmpty &&
        b.player2Id.isNotEmpty) {
      final aIds = {a.player1Id, a.player2Id};
      return aIds.contains(b.player1Id) && aIds.contains(b.player2Id);
    }

    final a1 = a.player1Name.trim().toLowerCase();
    final a2 = a.player2Name.trim().toLowerCase();
    final b1 = b.player1Name.trim().toLowerCase();
    final b2 = b.player2Name.trim().toLowerCase();

    return (a1 == b1 && a2 == b2) || (a1 == b2 && a2 == b1);
  }

  bool? _didPlayer1WinMatch(MatchModel match) {
    if (match.winnerId.isNotEmpty &&
        match.player1Id.isNotEmpty &&
        match.player2Id.isNotEmpty) {
      if (match.winnerId == match.player1Id) return true;
      if (match.winnerId == match.player2Id) return false;
    }

    int p1Sets = 0;
    int p2Sets = 0;

    final set1 = _parseScore(match.set1);
    final set2 = _parseScore(match.set2);
    final stb = _parseScore(match.superTieBreak);

    for (final set in [set1, set2, stb]) {
      if (set == null) continue;
      if (set[0] > set[1]) p1Sets++;
      if (set[1] > set[0]) p2Sets++;
    }

    if (p1Sets == p2Sets) return null;
    return p1Sets > p2Sets;
  }

  bool? _didSelectedP1Win(
    MatchModel selectedMatch,
    MatchModel historicalMatch,
  ) {
    final selectedP1Id = selectedMatch.player1Id;
    final selectedP1Name = selectedMatch.player1Name.trim().toLowerCase();

    bool selectedP1IsPlayer1InHistorical;

    if (selectedP1Id.isNotEmpty &&
        historicalMatch.player1Id.isNotEmpty &&
        historicalMatch.player2Id.isNotEmpty) {
      if (historicalMatch.player1Id == selectedP1Id) {
        selectedP1IsPlayer1InHistorical = true;
      } else if (historicalMatch.player2Id == selectedP1Id) {
        selectedP1IsPlayer1InHistorical = false;
      } else {
        return null;
      }
    } else {
      final h1 = historicalMatch.player1Name.trim().toLowerCase();
      final h2 = historicalMatch.player2Name.trim().toLowerCase();
      if (h1 == selectedP1Name) {
        selectedP1IsPlayer1InHistorical = true;
      } else if (h2 == selectedP1Name) {
        selectedP1IsPlayer1InHistorical = false;
      } else {
        return null;
      }
    }

    final player1Won = _didPlayer1WinMatch(historicalMatch);
    if (player1Won == null) return null;

    return selectedP1IsPlayer1InHistorical ? player1Won : !player1Won;
  }

  void _showHeadToHeadDialog(
    MatchModel selectedMatch,
    List<MatchModel> allMatches,
  ) {
    final pairMatches =
        allMatches.where((m) => _samePair(selectedMatch, m)).toList()
          ..sort((a, b) => b.playedAt.compareTo(a.playedAt));

    int p1Wins = 0;
    int p2Wins = 0;
    int seasonP1Wins = 0;
    int seasonP2Wins = 0;

    for (final historical in pairMatches) {
      final selectedP1Won = _didSelectedP1Win(selectedMatch, historical);
      if (selectedP1Won == null) continue;

      if (selectedP1Won) {
        p1Wins++;
        if (historical.season == selectedSeason) seasonP1Wins++;
      } else {
        p2Wins++;
        if (historical.season == selectedSeason) seasonP2Wins++;
      }
    }

    final resolvedMatches = p1Wins + p2Wins;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Head to Head'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${selectedMatch.player1Name} vs ${selectedMatch.player2Name}',
                ),
                const SizedBox(height: 10),
                Text('Ukupno mečeva: $resolvedMatches'),
                Text('${selectedMatch.player1Name}: $p1Wins pobjeda'),
                Text('${selectedMatch.player2Name}: $p2Wins pobjeda'),
                const SizedBox(height: 8),
                Text('Omjer: $p1Wins : $p2Wins'),
                const SizedBox(height: 12),
                Text('Sezona $selectedSeason: $seasonP1Wins : $seasonP2Wins'),
                const SizedBox(height: 6),
                Text('*all time* omjer: $p1Wins : $p2Wins'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Zatvori'),
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
          appBar: AppBar(title: const Text('Matches'), centerTitle: true),
          body: StreamBuilder<List<MatchModel>>(
            stream: firestoreService.getMatches(),
            builder: (context, matchesSnapshot) {
              if (matchesSnapshot.connectionState == ConnectionState.waiting ||
                  playersSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final allMatches = matchesSnapshot.data ?? [];

              final matches = allMatches.where((match) {
                if (match.season != selectedSeason) return false;
                return _matchBelongsToSelectedLeague(match, allPlayers);
              }).toList()..sort((a, b) => b.playedAt.compareTo(a.playedAt));

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
                        items: ['1', '2', '3', '4'].map((league) {
                          return DropdownMenuItem(
                            value: league,
                            child: Text(_leagueLabel(league)),
                          );
                        }).toList(),
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
                              final winner = _winnerName(match);

                              return Card(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                child: ListTile(
                                  onTap: () =>
                                      _showHeadToHeadDialog(match, allMatches),
                                  title: Text(
                                    '${match.player1Name} vs ${match.player2Name}',
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${_buildScore(match)}\n${_formatDate(match.playedAt)}\n${_leagueLabel(selectedLeague)}',
                                      ),
                                      if (winner != null) ...[
                                        const SizedBox(height: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          constraints: const BoxConstraints(
                                            minHeight: 32,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.green,
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(
                                                Icons.emoji_events,
                                                color: Colors.white,
                                                size: 20,
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                'Winner $winner',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  isThreeLine: true,
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit),
                                        tooltip: 'Uredi meč',
                                        onPressed: () =>
                                            _editMatchDialog(match),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete),
                                        tooltip: 'Obriši meč',
                                        onPressed: () =>
                                            _confirmDeleteMatch(match),
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
                    content: Text('Trebaš barem 2 igrača u odabranoj ligi.'),
                  ),
                );
                return;
              }

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      AddMatchPage(initialLeague: selectedLeague),
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
