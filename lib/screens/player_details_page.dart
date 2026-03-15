import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/match_model.dart';
import '../models/player.dart';

class PlayerDetailsPage extends StatelessWidget {
  final String playerId;
  final String playerName;

  const PlayerDetailsPage({
    super.key,
    required this.playerId,
    required this.playerName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(playerName),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('matches').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text('Greška: ${snapshot.error}'),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('players').snapshots(),
            builder: (context, playersSnapshot) {
              if (playersSnapshot.hasError) {
                return Center(
                  child: Text('Greška: ${playersSnapshot.error}'),
                );
              }

              if (playersSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }

              final docs = snapshot.data?.docs ?? [];
              final playerDocs = playersSnapshot.data?.docs ?? [];

              final playersById = <String, Player>{
                for (final doc in playerDocs)
                  doc.id: Player.fromMap(
                    Map<String, dynamic>.from(doc.data() as Map),
                    id: doc.id,
                  ),
              };

              final matches = docs
                  .map((doc) {
                    final data = Map<String, dynamic>.from(doc.data() as Map);
                    return MatchModel.fromMap(data, id: doc.id);
                  })
                  .where((m) => _involvesPlayer(m))
                  .where((m) => _isFinished(m))
                  .toList()
                ..sort((a, b) => b.playedAt.compareTo(a.playedAt));

              final stats = _PlayerStats.fromMatches(
                playerId: playerId,
                playerName: playerName,
                matches: matches,
              );

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _heroCard(context, stats),
                    const SizedBox(height: 16),
                    _mainStatsGrid(stats),
                    const SizedBox(height: 16),
                    _recentMatchesCard(matches, playersById),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  bool _involvesPlayer(MatchModel match) {
    if (match.player1Id.isNotEmpty || match.player2Id.isNotEmpty) {
      return match.player1Id == playerId || match.player2Id == playerId;
    }
    return match.player1Name == playerName || match.player2Name == playerName;
  }

  bool _isFinished(MatchModel match) {
    return _parseMatch(match).isValid;
  }

  bool _isPlayer1(MatchModel match) {
    if (match.player1Id.isNotEmpty || match.player2Id.isNotEmpty) {
      return match.player1Id == playerId;
    }
    return match.player1Name == playerName;
  }

  bool _didPlayerWin(MatchModel match) {
    if (match.winnerId.isNotEmpty) {
      return match.winnerId == playerId;
    }

    final parsed = _parseMatch(match);
    if (!parsed.isValid) return false;

    final isP1 = _isPlayer1(match);
    return isP1
        ? parsed.player1SetsWon > parsed.player2SetsWon
        : parsed.player2SetsWon > parsed.player1SetsWon;
  }

  Widget _heroCard(BuildContext context, _PlayerStats stats) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            CircleAvatar(
              radius: 34,
              child: Text(
                playerName.isNotEmpty ? playerName[0].toUpperCase() : '?',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              playerName,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 6),
            Text('${stats.wins}W • ${stats.losses}L • ${stats.played} matches'),
          ],
        ),
      ),
    );
  }

  Widget _mainStatsGrid(_PlayerStats stats) {
    final items = [
      _StatItem('Points', '${stats.points}'),
      _StatItem('Wins', '${stats.wins}'),
      _StatItem('Losses', '${stats.losses}'),
      _StatItem('Sets', '${stats.setsWon}:${stats.setsLost}'),
      _StatItem('Games', '${stats.gamesWon}:${stats.gamesLost}'),
      _StatItem('Played', '${stats.played}'),
    ];

    return GridView.builder(
      itemCount: items.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 2.2,
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(item.title, style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 8),
                Text(
                  item.value,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _recentMatchesCard(
    List<MatchModel> matches,
    Map<String, Player> playersById,
  ) {
    final recent = matches.take(5).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Recent matches',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (recent.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('No matches played'),
              )
            else
              ...recent.map((match) {
                final didWin = _didPlayerWin(match);
                final isP1 = _isPlayer1(match);
                final opponent = _opponentName(
                  match,
                  isP1,
                  playersById,
                );

                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('vs $opponent'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_scoreText(match, isP1)),
                      Text(_formatDate(match.playedAt)),
                    ],
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: didWin ? Colors.green : Colors.red,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      didWin ? 'W' : 'L',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  String _opponentName(
    MatchModel match,
    bool isP1,
    Map<String, Player> playersById,
  ) {
    if (isP1) {
      if (match.player2Name.trim().isNotEmpty) return match.player2Name;
      return playersById[match.player2Id]?.name ?? 'Nepoznati igrac';
    }

    if (match.player1Name.trim().isNotEmpty) return match.player1Name;
    return playersById[match.player1Id]?.name ?? 'Nepoznati igrac';
  }

  String _scoreText(MatchModel match, bool isP1) {
    final parts = <String>[];

    final s1 = _parseScore(match.set1);
    final s2 = _parseScore(match.set2);
    final stb = _parseScore(match.superTieBreak);

    if (s1 != null) {
      parts.add(isP1 ? '${s1[0]}–${s1[1]}' : '${s1[1]}–${s1[0]}');
    }
    if (s2 != null) {
      parts.add(isP1 ? '${s2[0]}–${s2[1]}' : '${s2[1]}–${s2[0]}');
    }
    if (stb != null) {
      parts.add(isP1 ? '${stb[0]}–${stb[1]}' : '${stb[1]}–${stb[0]}');
    }

    return parts.join('  ');
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.'
        '${date.year}';
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

  _ParsedMatch _parseMatch(MatchModel match) {
    final set1 = _parseScore(match.set1);
    final set2 = _parseScore(match.set2);

    if (set1 == null || set2 == null) {
      return _ParsedMatch.invalid();
    }

    int p1Sets = 0;
    int p2Sets = 0;

    if (set1[0] > set1[1]) {
      p1Sets++;
    } else {
      p2Sets++;
    }

    if (set2[0] > set2[1]) {
      p1Sets++;
    } else {
      p2Sets++;
    }

    return _ParsedMatch(
      isValid: true,
      player1SetsWon: p1Sets,
      player2SetsWon: p2Sets,
    );
  }
}

class _StatItem {
  final String title;
  final String value;

  _StatItem(this.title, this.value);
}

class _ParsedMatch {
  final bool isValid;
  final int player1SetsWon;
  final int player2SetsWon;

  _ParsedMatch({
    required this.isValid,
    required this.player1SetsWon,
    required this.player2SetsWon,
  });

  factory _ParsedMatch.invalid() {
    return _ParsedMatch(
      isValid: false,
      player1SetsWon: 0,
      player2SetsWon: 0,
    );
  }
}

class _PlayerStats {
  final int played;
  final int wins;
  final int losses;
  final int points;
  final int setsWon;
  final int setsLost;
  final int gamesWon;
  final int gamesLost;

  _PlayerStats({
    required this.played,
    required this.wins,
    required this.losses,
    required this.points,
    required this.setsWon,
    required this.setsLost,
    required this.gamesWon,
    required this.gamesLost,
  });

  factory _PlayerStats.fromMatches({
    required String playerId,
    required String playerName,
    required List<MatchModel> matches,
  }) {
    int played = 0;
    int wins = 0;
    int losses = 0;
    int points = 0;
    int setsWon = 0;
    int setsLost = 0;
    int gamesWon = 0;
    int gamesLost = 0;

    for (final match in matches) {
      final isP1 = match.player1Id == playerId ||
          match.player1Name == playerName;

      final parsed = _ParsedMatch(
        isValid: true,
        player1SetsWon: 0,
        player2SetsWon: 0,
      );

      played++;

      if (match.winnerId == playerId) {
        wins++;
      } else {
        losses++;
      }

      setsWon += parsed.player1SetsWon;
      setsLost += parsed.player2SetsWon;

      if (parsed.player1SetsWon == 2 && parsed.player2SetsWon == 0) {
        points += 3;
      } else if (parsed.player1SetsWon == 2 && parsed.player2SetsWon == 1) {
        points += 2;
      } else if (parsed.player1SetsWon == 1 && parsed.player2SetsWon == 2) {
        points += 1;
      }

      if (isP1) {
        gamesWon += parsed.player1SetsWon;
        gamesLost += parsed.player2SetsWon;
      } else {
        gamesWon += parsed.player2SetsWon;
        gamesLost += parsed.player1SetsWon;
      }
    }

    return _PlayerStats(
      played: played,
      wins: wins,
      losses: losses,
      points: points,
      setsWon: setsWon,
      setsLost: setsLost,
      gamesWon: gamesWon,
      gamesLost: gamesLost,
    );
  }
}