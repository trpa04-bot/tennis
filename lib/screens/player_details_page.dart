import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/match_model.dart';

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

          final docs = snapshot.data?.docs ?? [];

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

          final headToHeadRows = _buildHeadToHeadRows(matches);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _heroCard(context, stats),
                const SizedBox(height: 16),
                _mainStatsGrid(stats),
                const SizedBox(height: 16),
                _advancedStatsCard(stats),
                const SizedBox(height: 16),
                _formCard(stats),
                const SizedBox(height: 16),
                _headToHeadCard(headToHeadRows),
                const SizedBox(height: 16),
                _recentMatchesCard(matches),
              ],
            ),
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
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text('${stats.wins}W • ${stats.losses}L • ${stats.played} mečeva'),
            const SizedBox(height: 6),
            Text(
              'Win rate ${stats.winPercentage.toStringAsFixed(1)}%',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mainStatsGrid(_PlayerStats stats) {
    final items = [
      _StatItem('Bodovi', '${stats.points}'),
      _StatItem('Pobjede', '${stats.wins}'),
      _StatItem('Porazi', '${stats.losses}'),
      _StatItem('Setovi', '${stats.setsWon}:${stats.setsLost}'),
      _StatItem('Gemovi', '${stats.gamesWon}:${stats.gamesLost}'),
      _StatItem('Odigrano', '${stats.played}'),
    ];

    return GridView.builder(
      itemCount: items.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 2.1,
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(color: Colors.grey),
                ),
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

  Widget _advancedStatsCard(_PlayerStats stats) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'ATP style statistika',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 12),
            _advancedRow('Current streak', stats.currentStreakText),
            _advancedRow('Longest win streak', '${stats.longestWinStreak}'),
            _advancedRow('Pobjede 2:0', '${stats.winsTwoZero}'),
            _advancedRow('Pobjede 2:1', '${stats.winsTwoOne}'),
            _advancedRow('Porazi 1:2', '${stats.lossesOneTwo}'),
            _advancedRow('Porazi 0:2', '${stats.lossesZeroTwo}'),
            _advancedRow('STB mečevi', '${stats.superTieBreakMatches}'),
            _advancedRow(
              'Prosjek gemova / meč',
              stats.played == 0
                  ? '0.0'
                  : ((stats.gamesWon + stats.gamesLost) / stats.played)
                      .toStringAsFixed(1),
            ),
            _advancedRow(
              'Prosjek osvojenih gemova',
              stats.averageGamesWon.toStringAsFixed(1),
            ),
            _advancedRow(
              'Prosjek izgubljenih gemova',
              stats.averageGamesLost.toStringAsFixed(1),
            ),
          ],
        ),
      ),
    );
  }

  Widget _advancedRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _formCard(_PlayerStats stats) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Text(
              'Forma zadnjih 5:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: stats.last5.isEmpty
                  ? const Text('Nema odigranih mečeva')
                  : Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: stats.last5.map((result) {
                        final isWin = result == 'W';
                        return Container(
                          width: 36,
                          height: 36,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isWin ? Colors.green : Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            result,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _headToHeadCard(List<_HeadToHeadRow> rows) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Head-to-Head',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (rows.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('Nema podataka'),
              )
            else ...[
              const Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: Text(
                      'Protivnik',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'W-L',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'Mečevi',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'Win %',
                      textAlign: TextAlign.end,
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...rows.map(
                (row) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 4,
                        child: Text(row.opponentLabel),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          '${row.wins}-${row.losses}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          '${row.matches}',
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          '${row.winRate.toStringAsFixed(0)}%',
                          textAlign: TextAlign.end,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _recentMatchesCard(List<MatchModel> matches) {
    final recent = matches.take(5).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Zadnji mečevi',
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
                child: Text('Nema odigranih mečeva'),
              )
            else
              ...recent.map((match) {
                final didWin = _didPlayerWin(match);
                final isP1 = _isPlayer1(match);

                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(_scoreText(match, isP1)),
                  subtitle: Text(_formatDate(match.playedAt)),
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

  String _scoreText(MatchModel match, bool isP1) {
    final parts = <String>[];

    final s1 = _parseScore(match.set1);
    final s2 = _parseScore(match.set2);
    final stb = _parseScore(match.superTieBreak);

    if (s1 != null) {
      parts.add(isP1 ? '${s1[0]}-${s1[1]}' : '${s1[1]}-${s1[0]}');
    }
    if (s2 != null) {
      parts.add(isP1 ? '${s2[0]}-${s2[1]}' : '${s2[1]}-${s2[0]}');
    }
    if (stb != null) {
      parts.add(isP1 ? '${stb[0]}-${stb[1]}' : '${stb[1]}-${stb[0]}');
    }

    return parts.isEmpty ? 'Bez rezultata' : parts.join('  ');
  }

  List<_HeadToHeadRow> _buildHeadToHeadRows(List<MatchModel> matches) {
    final Map<String, Map<String, dynamic>> data = {};

    for (final match in matches) {
      final isP1 = _isPlayer1(match);

      final opponentKey = isP1
          ? (match.player2Id.isNotEmpty ? match.player2Id : match.player2Name)
          : (match.player1Id.isNotEmpty ? match.player1Id : match.player1Name);

      final opponentLabel = isP1 ? match.player2Name : match.player1Name;

      if (!data.containsKey(opponentKey)) {
        data[opponentKey] = {
          'label': opponentLabel.isEmpty ? 'Opponent' : opponentLabel,
          'matches': 0,
          'wins': 0,
          'losses': 0,
        };
      }

      data[opponentKey]!['matches'] =
          (data[opponentKey]!['matches'] as int) + 1;

      if (_didPlayerWin(match)) {
        data[opponentKey]!['wins'] = (data[opponentKey]!['wins'] as int) + 1;
      } else {
        data[opponentKey]!['losses'] =
            (data[opponentKey]!['losses'] as int) + 1;
      }
    }

    final rows = data.entries.map((entry) {
      final map = entry.value;
      final totalMatches = map['matches'] as int;
      final wins = map['wins'] as int;
      final losses = map['losses'] as int;

      return _HeadToHeadRow(
        opponentLabel: map['label'] as String,
        matches: totalMatches,
        wins: wins,
        losses: losses,
        winRate: totalMatches == 0 ? 0 : (wins / totalMatches) * 100,
      );
    }).toList();

    rows.sort((a, b) {
      final byMatches = b.matches.compareTo(a.matches);
      if (byMatches != 0) return byMatches;

      final byWins = b.wins.compareTo(a.wins);
      if (byWins != 0) return byWins;

      return a.opponentLabel.compareTo(b.opponentLabel);
    });

    return rows;
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
    final stb = _parseScore(match.superTieBreak);

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

    if (stb != null) {
      if (stb[0] > stb[1]) {
        p1Sets++;
      } else if (stb[1] > stb[0]) {
        p2Sets++;
      }
    }

    return _ParsedMatch(
      isValid: true,
      player1SetsWon: p1Sets,
      player2SetsWon: p2Sets,
      player1GamesWon: set1[0] + set2[0],
      player2GamesWon: set1[1] + set2[1],
      hasSuperTieBreak: stb != null,
    );
  }
}

class _StatItem {
  final String title;
  final String value;

  _StatItem(this.title, this.value);
}

class _HeadToHeadRow {
  final String opponentLabel;
  final int matches;
  final int wins;
  final int losses;
  final double winRate;

  _HeadToHeadRow({
    required this.opponentLabel,
    required this.matches,
    required this.wins,
    required this.losses,
    required this.winRate,
  });
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
  final double winPercentage;
  final List<String> last5;
  final int winsTwoZero;
  final int winsTwoOne;
  final int lossesOneTwo;
  final int lossesZeroTwo;
  final int superTieBreakMatches;
  final int longestWinStreak;
  final int currentStreak;
  final bool currentStreakIsWin;
  final double averageGamesWon;
  final double averageGamesLost;

  _PlayerStats({
    required this.played,
    required this.wins,
    required this.losses,
    required this.points,
    required this.setsWon,
    required this.setsLost,
    required this.gamesWon,
    required this.gamesLost,
    required this.winPercentage,
    required this.last5,
    required this.winsTwoZero,
    required this.winsTwoOne,
    required this.lossesOneTwo,
    required this.lossesZeroTwo,
    required this.superTieBreakMatches,
    required this.longestWinStreak,
    required this.currentStreak,
    required this.currentStreakIsWin,
    required this.averageGamesWon,
    required this.averageGamesLost,
  });

  String get currentStreakText {
    if (currentStreak == 0) return '0';
    return currentStreakIsWin ? 'W$currentStreak' : 'L$currentStreak';
  }

  factory _PlayerStats.empty() {
    return _PlayerStats(
      played: 0,
      wins: 0,
      losses: 0,
      points: 0,
      setsWon: 0,
      setsLost: 0,
      gamesWon: 0,
      gamesLost: 0,
      winPercentage: 0,
      last5: const [],
      winsTwoZero: 0,
      winsTwoOne: 0,
      lossesOneTwo: 0,
      lossesZeroTwo: 0,
      superTieBreakMatches: 0,
      longestWinStreak: 0,
      currentStreak: 0,
      currentStreakIsWin: true,
      averageGamesWon: 0,
      averageGamesLost: 0,
    );
  }

  factory _PlayerStats.fromMatches({
    required String playerId,
    required String playerName,
    required List<MatchModel> matches,
  }) {
    if (matches.isEmpty) {
      return _PlayerStats.empty();
    }

    bool isPlayer1(MatchModel match) {
      if (match.player1Id.isNotEmpty || match.player2Id.isNotEmpty) {
        return match.player1Id == playerId;
      }
      return match.player1Name == playerName;
    }

    bool didWin(MatchModel match) {
      if (match.winnerId.isNotEmpty) {
        return match.winnerId == playerId;
      }

      final parsed = _parseStaticMatch(match);
      if (!parsed.isValid) return false;

      return isPlayer1(match)
          ? parsed.player1SetsWon > parsed.player2SetsWon
          : parsed.player2SetsWon > parsed.player1SetsWon;
    }

    int played = 0;
    int wins = 0;
    int losses = 0;
    int points = 0;
    int setsWon = 0;
    int setsLost = 0;
    int gamesWon = 0;
    int gamesLost = 0;
    int winsTwoZero = 0;
    int winsTwoOne = 0;
    int lossesOneTwo = 0;
    int lossesZeroTwo = 0;
    int superTieBreakMatches = 0;
    final List<String> last5 = [];

    int longestWinStreak = 0;
    int tempWinStreak = 0;

    final oldestFirst = [...matches]..sort((a, b) => a.playedAt.compareTo(b.playedAt));

    for (final match in oldestFirst) {
      if (didWin(match)) {
        tempWinStreak++;
        if (tempWinStreak > longestWinStreak) {
          longestWinStreak = tempWinStreak;
        }
      } else {
        tempWinStreak = 0;
      }
    }

    int currentStreak = 0;
    bool currentStreakIsWin = true;

    if (matches.isNotEmpty) {
      currentStreakIsWin = didWin(matches.first);
      for (final match in matches) {
        if (didWin(match) == currentStreakIsWin) {
          currentStreak++;
        } else {
          break;
        }
      }
    }

    for (final match in matches) {
      final parsed = _parseStaticMatch(match);
      if (!parsed.isValid) continue;

      final p1 = isPlayer1(match);
      final matchSetsWon = p1 ? parsed.player1SetsWon : parsed.player2SetsWon;
      final matchSetsLost = p1 ? parsed.player2SetsWon : parsed.player1SetsWon;
      final matchGamesWon = p1 ? parsed.player1GamesWon : parsed.player2GamesWon;
      final matchGamesLost = p1 ? parsed.player2GamesWon : parsed.player1GamesWon;

      played++;

      if (didWin(match)) {
        wins++;
      } else {
        losses++;
      }

      setsWon += matchSetsWon;
      setsLost += matchSetsLost;
      gamesWon += matchGamesWon;
      gamesLost += matchGamesLost;

      if (parsed.hasSuperTieBreak) {
        superTieBreakMatches++;
      }

      if (matchSetsWon == 2 && matchSetsLost == 0) {
        points += 3;
        winsTwoZero++;
      } else if (matchSetsWon == 2 && matchSetsLost == 1) {
        points += 2;
        winsTwoOne++;
      } else if (matchSetsWon == 1 && matchSetsLost == 2) {
        points += 1;
        lossesOneTwo++;
      } else if (matchSetsWon == 0 && matchSetsLost == 2) {
        lossesZeroTwo++;
      }

      if (last5.length < 5) {
        last5.add(didWin(match) ? 'W' : 'L');
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
      winPercentage: played == 0 ? 0 : (wins / played) * 100,
      last5: last5,
      winsTwoZero: winsTwoZero,
      winsTwoOne: winsTwoOne,
      lossesOneTwo: lossesOneTwo,
      lossesZeroTwo: lossesZeroTwo,
      superTieBreakMatches: superTieBreakMatches,
      longestWinStreak: longestWinStreak,
      currentStreak: currentStreak,
      currentStreakIsWin: currentStreakIsWin,
      averageGamesWon: played == 0 ? 0 : gamesWon / played,
      averageGamesLost: played == 0 ? 0 : gamesLost / played,
    );
  }

  static _ParsedMatch _parseStaticMatch(MatchModel match) {
    List<int>? parseScore(String score) {
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

    final set1 = parseScore(match.set1);
    final set2 = parseScore(match.set2);
    final stb = parseScore(match.superTieBreak);

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

    if (stb != null) {
      if (stb[0] > stb[1]) {
        p1Sets++;
      } else if (stb[1] > stb[0]) {
        p2Sets++;
      }
    }

    return _ParsedMatch(
      isValid: true,
      player1SetsWon: p1Sets,
      player2SetsWon: p2Sets,
      player1GamesWon: set1[0] + set2[0],
      player2GamesWon: set1[1] + set2[1],
      hasSuperTieBreak: stb != null,
    );
  }
}

class _ParsedMatch {
  final bool isValid;
  final int player1SetsWon;
  final int player2SetsWon;
  final int player1GamesWon;
  final int player2GamesWon;
  final bool hasSuperTieBreak;

  _ParsedMatch({
    required this.isValid,
    required this.player1SetsWon,
    required this.player2SetsWon,
    required this.player1GamesWon,
    required this.player2GamesWon,
    required this.hasSuperTieBreak,
  });

  factory _ParsedMatch.invalid() {
    return _ParsedMatch(
      isValid: false,
      player1SetsWon: 0,
      player2SetsWon: 0,
      player1GamesWon: 0,
      player2GamesWon: 0,
      hasSuperTieBreak: false,
    );
  }
}