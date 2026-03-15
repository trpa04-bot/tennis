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
                    _atpStyleCard(context, stats, matches),
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

  Widget _atpStyleCard(
    BuildContext context,
    _PlayerStats stats,
    List<MatchModel> matches,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final recent = matches.take(5).toList();

    final recentForm = recent
        .map((m) => _didPlayerWin(m) ? 'W' : 'L')
        .toList();

    final winRate = stats.played == 0 ? 0.0 : stats.wins / stats.played;
    final setDenominator = (stats.setsWon + stats.setsLost).toDouble();
    final setRate = setDenominator == 0 ? 0.0 : stats.setsWon / setDenominator;
    final gameDenominator = (stats.gamesWon + stats.gamesLost).toDouble();
    final gameRate = gameDenominator == 0 ? 0.0 : stats.gamesWon / gameDenominator;

    return Card(
      elevation: 3,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [
              scheme.primaryContainer.withValues(alpha: 0.55),
              scheme.surface,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.emoji_events_outlined),
                const SizedBox(width: 8),
                Text(
                  'ATP-style Performance',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _atpChip(
                  context,
                  title: 'Win Rate',
                  value: '${(winRate * 100).toStringAsFixed(1)}%',
                ),
                _atpChip(
                  context,
                  title: 'Set Diff',
                  value: '${stats.setsWon - stats.setsLost}',
                ),
                _atpChip(
                  context,
                  title: 'Game Diff',
                  value: '${stats.gamesWon - stats.gamesLost}',
                ),
                _atpChip(
                  context,
                  title: 'Form (5)',
                  value: recentForm.isEmpty ? '-' : recentForm.join(' '),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _performanceBar(
              context,
              label: 'Match dominance',
              value: winRate,
            ),
            const SizedBox(height: 10),
            _performanceBar(
              context,
              label: 'Set control',
              value: setRate,
            ),
            const SizedBox(height: 10),
            _performanceBar(
              context,
              label: 'Game control',
              value: gameRate,
            ),
          ],
        ),
      ),
    );
  }

  Widget _atpChip(
    BuildContext context, {
    required String title,
    required String value,
  }) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _performanceBar(
    BuildContext context, {
    required String label,
    required double value,
  }) {
    final safeValue = value.clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: safeValue,
            minHeight: 10,
          ),
        ),
      ],
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

    final stb = _parseScore(match.superTieBreak);
    if (p1Sets == p2Sets) {
      if (stb == null) {
        return _ParsedMatch.invalid();
      }

      if (stb[0] > stb[1]) {
        p1Sets++;
      } else if (stb[1] > stb[0]) {
        p2Sets++;
      } else {
        return _ParsedMatch.invalid();
      }
    }

    if (p1Sets == p2Sets) {
      return _ParsedMatch.invalid();
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
      final isP1 = (match.player1Id.isNotEmpty || match.player2Id.isNotEmpty)
          ? match.player1Id == playerId
          : match.player1Name == playerName;

      final parsed = _parseMatchFromModel(match);
      if (!parsed.isValid) {
        continue;
      }

      played++;

      final didWin = _didPlayerWinMatch(
        match: match,
        playerId: playerId,
        isP1: isP1,
        parsed: parsed,
      );

      if (didWin) {
        wins++;
      } else {
        losses++;
      }

      final playerSetsWon = isP1 ? parsed.player1SetsWon : parsed.player2SetsWon;
      final playerSetsLost = isP1 ? parsed.player2SetsWon : parsed.player1SetsWon;
      setsWon += playerSetsWon;
      setsLost += playerSetsLost;

      if (didWin) {
        points += (playerSetsWon == 2 && playerSetsLost == 0) ? 3 : 2;
      } else if (playerSetsWon == 1 && playerSetsLost == 2) {
        points += 1;
      }

      final score = _parseGamesFromMatch(match);
      gamesWon += isP1 ? score.player1Games : score.player2Games;
      gamesLost += isP1 ? score.player2Games : score.player1Games;

      // Super tie-break je set odlučivanja, ne ulazi u game statistiku.
      // Zato je games obračun samo iz set1 i set2.
      // (Namjerno bez super tie-break poena.)

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

  static _ParsedMatch _parseMatchFromModel(MatchModel match) {
    final set1 = _parseScoreStatic(match.set1);
    final set2 = _parseScoreStatic(match.set2);

    if (set1 == null || set2 == null) {
      return _ParsedMatch.invalid();
    }

    int p1Sets = 0;
    int p2Sets = 0;

    if (set1[0] > set1[1]) {
      p1Sets++;
    } else if (set1[1] > set1[0]) {
      p2Sets++;
    }

    if (set2[0] > set2[1]) {
      p1Sets++;
    } else if (set2[1] > set2[0]) {
      p2Sets++;
    }

    if (p1Sets == p2Sets) {
      final stb = _parseScoreStatic(match.superTieBreak);
      if (stb == null) return _ParsedMatch.invalid();

      if (stb[0] > stb[1]) {
        p1Sets++;
      } else if (stb[1] > stb[0]) {
        p2Sets++;
      } else {
        return _ParsedMatch.invalid();
      }
    }

    if (p1Sets == p2Sets) {
      return _ParsedMatch.invalid();
    }

    return _ParsedMatch(
      isValid: true,
      player1SetsWon: p1Sets,
      player2SetsWon: p2Sets,
    );
  }

  static bool _didPlayerWinMatch({
    required MatchModel match,
    required String playerId,
    required bool isP1,
    required _ParsedMatch parsed,
  }) {
    if (match.winnerId.isNotEmpty && playerId.isNotEmpty) {
      return match.winnerId == playerId;
    }

    return isP1
        ? parsed.player1SetsWon > parsed.player2SetsWon
        : parsed.player2SetsWon > parsed.player1SetsWon;
  }

  static _GameScore _parseGamesFromMatch(MatchModel match) {
    int p1Games = 0;
    int p2Games = 0;

    for (final raw in [match.set1, match.set2]) {
      final set = _parseScoreStatic(raw);
      if (set == null) continue;
      p1Games += set[0];
      p2Games += set[1];
    }

    return _GameScore(player1Games: p1Games, player2Games: p2Games);
  }

  static List<int>? _parseScoreStatic(String score) {
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
}

class _GameScore {
  final int player1Games;
  final int player2Games;

  _GameScore({
    required this.player1Games,
    required this.player2Games,
  });
}