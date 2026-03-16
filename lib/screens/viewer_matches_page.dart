import 'package:flutter/material.dart';
import '../models/match_model.dart';
import '../models/player.dart';
import '../services/firestore_service.dart';

class ViewerMatchesPage extends StatefulWidget {
  const ViewerMatchesPage({super.key});

  @override
  State<ViewerMatchesPage> createState() => _ViewerMatchesPageState();
}

class _ViewerMatchesPageState extends State<ViewerMatchesPage> {
  final FirestoreService firestoreService = FirestoreService();
  final List<String> leagues = const ['1', '2', '3', '4'];

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

  String _buildScoreOnly(MatchModel match) {
    if (match.superTieBreak.isNotEmpty) {
      return '${match.set1}, ${match.set2}, ${match.superTieBreak}';
    }
    return '${match.set1}, ${match.set2}';
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

  bool? _didSelectedP1Win(MatchModel selectedMatch, MatchModel historicalMatch) {
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

  void _showHeadToHeadDialog(MatchModel selectedMatch, List<MatchModel> allMatches) {
    final pairMatches = allMatches
        .where((m) => _samePair(selectedMatch, m))
        .toList()
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
                Text('${selectedMatch.player1Name} vs ${selectedMatch.player2Name}'),
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

        return DefaultTabController(
          length: leagues.length,
          initialIndex: leagues.indexOf(selectedLeague),
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Matches'),
              centerTitle: true,
            ),
            body: StreamBuilder<List<MatchModel>>(
              stream: firestoreService.getMatches(),
              builder: (context, matchesSnapshot) {
              if (matchesSnapshot.connectionState == ConnectionState.waiting ||
                  playersSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }

              if (matchesSnapshot.hasError) {
                return Center(
                  child: Text('Greška: ${matchesSnapshot.error}'),
                );
              }

              if (playersSnapshot.hasError) {
                return Center(
                  child: Text('Greška: ${playersSnapshot.error}'),
                );
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
                    const SizedBox(height: 6),
                    TabBar(
                      tabs: leagues
                          .map((league) => Tab(text: '$league. liga'))
                          .toList(),
                      onTap: (index) {
                        setState(() {
                          selectedLeague = leagues[index];
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: matches.isEmpty
                          ? const Center(
                              child: Text('Nema mečeva za odabranu ligu i sezonu.'),
                            )
                          : ListView.builder(
                              itemCount: matches.length,
                              itemBuilder: (context, index) {
                                final match = matches[index];
                                final winner = _winnerName(match);
                                final player1Won = _didPlayer1WinMatch(match);
                                final player2Won = player1Won == null
                                    ? null
                                    : !player1Won;

                                return Card(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(12),
                                    onTap: () => _showHeadToHeadDialog(
                                      match,
                                      allMatches,
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: RichText(
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  text: TextSpan(
                                                    children: [
                                                      TextSpan(
                                                        text: match.player1Name,
                                                        style: TextStyle(
                                                          fontSize: 17,
                                                          fontWeight:
                                                              player1Won == true
                                                              ? FontWeight.w800
                                                              : FontWeight.w500,
                                                          color: player1Won ==
                                                                  true
                                                              ? Colors.green.shade700
                                                              : player2Won ==
                                                                      true
                                                                  ? Colors.black54
                                                                  : Colors.black87,
                                                        ),
                                                      ),
                                                      const TextSpan(
                                                        text: ' vs ',
                                                        style: TextStyle(
                                                          fontSize: 16,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                          color: Colors.black45,
                                                        ),
                                                      ),
                                                      TextSpan(
                                                        text: match.player2Name,
                                                        style: TextStyle(
                                                          fontSize: 17,
                                                          fontWeight:
                                                              player2Won == true
                                                              ? FontWeight.w800
                                                              : FontWeight.w500,
                                                          color: player2Won ==
                                                                  true
                                                              ? Colors.green.shade700
                                                              : player1Won ==
                                                                      true
                                                                  ? Colors.black54
                                                                  : Colors.black87,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Text(
                                                '${match.season} • ${_formatDate(match.playedAt)}',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodyMedium
                                                    ?.copyWith(
                                                      color: Colors.black54,
                                                    ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 10),
                                          Row(
                                            children: [
                                              if (winner != null)
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 4,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.green,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                      999,
                                                    ),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      const Icon(
                                                        Icons.emoji_events,
                                                        color: Colors.white,
                                                        size: 16,
                                                      ),
                                                      const SizedBox(width: 6),
                                                      Text(
                                                        winner,
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              if (winner != null)
                                                const SizedBox(width: 10),
                                              Expanded(
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 10,
                                                        vertical: 6,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: winner != null
                                                        ? Colors.green
                                                              .withValues(
                                                                alpha: 0.08,
                                                              )
                                                        : Colors.transparent,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                      8,
                                                    ),
                                                  ),
                                                  child: Text(
                                                    _buildScoreOnly(match),
                                                    textAlign: TextAlign.right,
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      fontSize: 16,
                                                      color: winner != null
                                                          ? Colors.green.shade800
                                                          : Colors.black87,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
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
          ),
        );
      },
    );
  }
}