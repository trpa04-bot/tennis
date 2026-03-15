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

  String _buildScore(MatchModel match) {
    if (match.superTieBreak.isNotEmpty) {
      return '${match.season} • ${match.set1}, ${match.set2}, ${match.superTieBreak}';
    }
    return '${match.season} • ${match.set1}, ${match.set2}';
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.'
        '${date.year}';
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

                                return Card(
                                  child: ListTile(
                                    title: Text('${match.player1Name} vs ${match.player2Name}'),
                                    subtitle: Text(
                                      '${_buildScore(match)}\n${_formatDate(match.playedAt)}',
                                    ),
                                    isThreeLine: true,
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