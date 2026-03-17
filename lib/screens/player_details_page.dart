import 'dart:ui' as ui;

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
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(playerName),
          centerTitle: true,
          bottom: const TabBar(
            isScrollable: false,
            tabAlignment: TabAlignment.fill,
            tabs: [
              Tab(icon: Icon(Icons.bar_chart_outlined), text: 'Pregled'),
              Tab(icon: Icon(Icons.show_chart_outlined), text: 'Statistike'),
              Tab(icon: Icon(Icons.sports_tennis_outlined), text: 'Mečevi'),
            ],
          ),
        ),
        body: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('matches').snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text('Greška: ${snapshot.error}'));
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('players')
                  .snapshots(),
              builder: (context, playersSnapshot) {
                if (playersSnapshot.hasError) {
                  return Center(
                    child: Text('Greška: ${playersSnapshot.error}'),
                  );
                }

                if (playersSnapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
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

                final matches =
                    docs
                        .map((doc) {
                          final data = Map<String, dynamic>.from(
                            doc.data() as Map,
                          );
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

                final playerAchievements =
                    playersById[playerId]?.achievements ?? <String, int>{};
                final currentSeason = _currentSeasonLabel();

                final currentPlayer = playersById[playerId];
                final normalizedLeague = _normalizeLeague(
                  currentPlayer?.league ?? '',
                );

                final leaguePlayers = playersById.values
                    .where(
                      (p) =>
                          _normalizeLeague(p.league) == normalizedLeague &&
                          !p.archived &&
                          !p.frozen,
                    )
                    .toList()
                  ..sort((a, b) => a.name.compareTo(b.name));

                final seasonMatches = matches
                    .where((m) => m.season == currentSeason)
                    .toList();

                final playedOpponentKeys = seasonMatches
                    .map((m) => _opponentKeyForPlayer(m))
                    .where((k) => k.isNotEmpty)
                    .toSet();

                final notPlayedOpponents = leaguePlayers
                    .where((p) => (p.id ?? '').isNotEmpty)
                    .where((p) => p.id != playerId)
                    .where(
                      (p) => !playedOpponentKeys.contains(
                        _playerKeyFromIdName(p.id, p.name),
                      ),
                    )
                    .map((p) => p.name)
                    .toList();

                final playedOpponents = leaguePlayers
                    .where((p) => (p.id ?? '').isNotEmpty)
                    .where((p) => p.id != playerId)
                    .where(
                      (p) => playedOpponentKeys.contains(
                        _playerKeyFromIdName(p.id, p.name),
                      ),
                    )
                    .map((p) => p.name)
                    .toList();
                final isCompact = MediaQuery.of(context).size.width < 420;
                final pagePadding = EdgeInsets.fromLTRB(
                  isCompact ? 12 : 16,
                  isCompact ? 12 : 16,
                  isCompact ? 12 : 16,
                  isCompact ? 18 : 20,
                );
                final sectionGap = SizedBox(height: isCompact ? 12 : 16);

                return TabBarView(
                  children: [
                    // Pregled — hero + ATP overview
                    SingleChildScrollView(
                      padding: pagePadding,
                      child: Column(
                        children: [
                          _heroCard(context, stats),
                          sectionGap,
                          _atpStyleCard(context, stats, matches),
                        ],
                      ),
                    ),
                    // Statistike — progress chart + stats grid
                    SingleChildScrollView(
                      padding: pagePadding,
                      child: Column(
                        children: [
                          _progressChartCard(context, matches),
                          sectionGap,
                          _mainStatsGrid(context, stats),
                        ],
                      ),
                    ),
                    // Mečevi — achievements + recent matches
                    SingleChildScrollView(
                      padding: pagePadding,
                      child: Column(
                        children: [
                          _achievementsCard(context, playerAchievements),
                          sectionGap,
                          _remainingOpponentsCompactCard(
                            season: currentSeason,
                            playedOpponents: playedOpponents,
                            notPlayedOpponents: notPlayedOpponents,
                          ),
                          sectionGap,
                          _recentMatchesCard(matches, playersById),
                        ],
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
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

  String _currentSeasonLabel() {
    final now = DateTime.now();
    final seasonPrefix = now.month <= 6 ? 'Winter' : 'Summer';
    return '$seasonPrefix ${now.year}';
  }

  String _normalizeLeague(String league) {
    final value = league.trim().toLowerCase();
    if (value == '1' || value == '1. liga') return '1';
    if (value == '2' || value == '2. liga') return '2';
    if (value == '3' || value == '3. liga') return '3';
    if (value == '4' || value == '4. liga') return '4';
    return league;
  }

  String _playerKeyFromIdName(String? id, String name) {
    if (id != null && id.isNotEmpty) return 'id:$id';
    return 'name:${name.trim().toLowerCase()}';
  }

  String _opponentKeyForPlayer(MatchModel match) {
    final isP1 = _isPlayer1(match);
    if (isP1) {
      return _playerKeyFromIdName(match.player2Id, match.player2Name);
    }
    return _playerKeyFromIdName(match.player1Id, match.player1Name);
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
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text('${stats.wins}W • ${stats.losses}L • ${stats.played} matches'),
          ],
        ),
      ),
    );
  }

  Widget _mainStatsGrid(BuildContext context, _PlayerStats stats) {
    final items = [
      _StatItem('Points', '${stats.points}'),
      _StatItem('Wins', '${stats.wins}'),
      _StatItem('Losses', '${stats.losses}'),
      _StatItem('Sets', '${stats.setsWon}:${stats.setsLost}'),
      _StatItem('Games', '${stats.gamesWon}:${stats.gamesLost}'),
      _StatItem('Played', '${stats.played}'),
    ];

    final screenWidth = MediaQuery.of(context).size.width;
    final cols = screenWidth > 480 ? 3 : 2;
    final isCompact = screenWidth < 420;
    final mainAxisExtent = screenWidth > 480
        ? 112.0
        : (isCompact ? 124.0 : 118.0);
    final titleStyle = TextStyle(
      color: Colors.grey,
      fontSize: isCompact ? 14 : 15,
      height: 1.1,
    );
    final valueStyle = TextStyle(
      fontSize: isCompact ? 28 : 30,
      fontWeight: FontWeight.bold,
      height: 1.0,
    );

    return GridView.builder(
      itemCount: items.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cols,
        mainAxisSpacing: isCompact ? 10 : 12,
        crossAxisSpacing: isCompact ? 10 : 12,
        mainAxisExtent: mainAxisExtent,
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        return Card(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isCompact ? 8 : 10,
              vertical: isCompact ? 10 : 12,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: titleStyle,
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(item.value, maxLines: 1, style: valueStyle),
                    ),
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

    final recentForm = recent.map((m) => _didPlayerWin(m) ? 'W' : 'L').toList();

    final winRate = stats.played == 0 ? 0.0 : stats.wins / stats.played;
    final setDenominator = (stats.setsWon + stats.setsLost).toDouble();
    final setRate = setDenominator == 0 ? 0.0 : stats.setsWon / setDenominator;
    final gameDenominator = (stats.gamesWon + stats.gamesLost).toDouble();
    final gameRate = gameDenominator == 0
        ? 0.0
        : stats.gamesWon / gameDenominator;

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
            _performanceBar(context, label: 'Match dominance', value: winRate),
            const SizedBox(height: 10),
            _performanceBar(context, label: 'Set control', value: setRate),
            const SizedBox(height: 10),
            _performanceBar(context, label: 'Game control', value: gameRate),
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
          Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
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
          child: LinearProgressIndicator(value: safeValue, minHeight: 10),
        ),
      ],
    );
  }

  Widget _progressChartCard(BuildContext context, List<MatchModel> matches) {
    final points = _buildProgressPoints(matches);
    final scheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.show_chart),
                const SizedBox(width: 8),
                Text(
                  'Points Progress',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              points.isEmpty
                  ? 'Graf će se prikazati nakon prvog odigranog meča.'
                  : 'Kumulativni bodovi kroz vrijeme',
              style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.7)),
            ),
            const SizedBox(height: 16),
            if (points.isEmpty)
              Container(
                height: 180,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
                ),
                child: const Text('Nema dovoljno podataka za graf'),
              )
            else ...[
              SizedBox(
                height: 180,
                width: double.infinity,
                child: CustomPaint(
                  painter: _ProgressChartPainter(
                    points: points,
                    lineColor: scheme.primary,
                    fillColor: scheme.primary.withValues(alpha: 0.12),
                    gridColor: scheme.outlineVariant.withValues(alpha: 0.4),
                    textColor: scheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  _progressMetaChip(context, 'Start', '${points.first.value}'),
                  _progressMetaChip(context, 'Now', '${points.last.value}'),
                  _progressMetaChip(
                    context,
                    'Delta',
                    '+${points.last.value - points.first.value}',
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _progressMetaChip(BuildContext context, String label, String value) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(10),
      ),
      child: RichText(
        text: TextSpan(
          style: DefaultTextStyle.of(context).style,
          children: [
            TextSpan(
              text: '$label ',
              style: TextStyle(
                color: scheme.onSurface.withValues(alpha: 0.65),
                fontSize: 12,
              ),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  List<_ProgressPoint> _buildProgressPoints(List<MatchModel> matches) {
    final ordered = matches.toList()
      ..sort((a, b) => a.playedAt.compareTo(b.playedAt));
    var cumulativePoints = 0;
    final points = <_ProgressPoint>[];

    for (final match in ordered) {
      final parsed = _parseMatch(match);
      if (!parsed.isValid) continue;

      final isP1 = _isPlayer1(match);
      final didWin = _didPlayerWin(match);
      final playerSetsWon = isP1
          ? parsed.player1SetsWon
          : parsed.player2SetsWon;
      final playerSetsLost = isP1
          ? parsed.player2SetsWon
          : parsed.player1SetsWon;

      var matchPoints = 0;
      if (didWin) {
        matchPoints = (playerSetsWon == 2 && playerSetsLost == 0) ? 3 : 2;
      } else if (playerSetsWon == 1 && playerSetsLost == 2) {
        matchPoints = 1;
      }

      cumulativePoints += matchPoints;
      points.add(
        _ProgressPoint(
          label: _formatShortDate(match.playedAt),
          value: cumulativePoints,
          date: match.playedAt,
        ),
      );
    }

    return points;
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
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                final opponent = _opponentName(match, isP1, playersById);

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

  Widget _achievementsCard(BuildContext context, Map<String, int> earned) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('🏅', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                Text(
                  'Achievements',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: _kAchievements.map((def) {
                return _achievementBadge(context, def, earned[def.id] ?? 0);
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _achievementBadge(
    BuildContext context,
    _AchievementDef def,
    int count,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final isEarned = count > 0;
    final showCount = isEarned && count > 1 && def.id != 'first_win';

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 130,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: isEarned
                ? scheme.primaryContainer.withValues(alpha: 0.5)
                : Colors.grey.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isEarned
                  ? scheme.primary.withValues(alpha: 0.5)
                  : Colors.grey.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Opacity(
                opacity: isEarned ? 1.0 : 0.3,
                child: Text(def.emoji, style: const TextStyle(fontSize: 28)),
              ),
              const SizedBox(height: 6),
              Text(
                def.label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isEarned ? scheme.primary : Colors.grey,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                def.desc,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  color: isEarned
                      ? scheme.onSurface.withValues(alpha: 0.7)
                      : Colors.grey.withValues(alpha: 0.6),
                ),
              ),
              if (!isEarned) ...[
                const SizedBox(height: 4),
                const Icon(Icons.lock_outline, size: 12, color: Colors.grey),
              ],
            ],
          ),
        ),
        if (showCount)
          Positioned(
            top: -8,
            right: -8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: scheme.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'x$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _remainingOpponentsCompactCard({
    required String season,
    required List<String> playedOpponents,
    required List<String> notPlayedOpponents,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Status mečeva u sezoni',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text('Sezona: $season'),
            const SizedBox(height: 12),
            const Text(
              'Nije odigrano',
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            if (notPlayedOpponents.isEmpty)
              const Text('Nema, sve je odigrano.', style: TextStyle(color: Colors.red))
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: notPlayedOpponents
                    .map(
                      (name) => Text(
                        '• $name',
                        style: const TextStyle(color: Colors.red),
                      ),
                    )
                    .toList(),
              ),
            const SizedBox(height: 12),
            const Text(
              'Odigrano',
              style: TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            if (playedOpponents.isEmpty)
              const Text('Još nema odigranih mečeva.', style: TextStyle(color: Colors.green))
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: playedOpponents
                    .map(
                      (name) => Text(
                        '• $name',
                        style: const TextStyle(color: Colors.green),
                      ),
                    )
                    .toList(),
              ),
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

  String _formatShortDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}';
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
    return _ParsedMatch(isValid: false, player1SetsWon: 0, player2SetsWon: 0);
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

      final playerSetsWon = isP1
          ? parsed.player1SetsWon
          : parsed.player2SetsWon;
      final playerSetsLost = isP1
          ? parsed.player2SetsWon
          : parsed.player1SetsWon;
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

  _GameScore({required this.player1Games, required this.player2Games});
}

class _ProgressPoint {
  final String label;
  final int value;
  final DateTime date;

  const _ProgressPoint({
    required this.label,
    required this.value,
    required this.date,
  });
}

class _ProgressChartPainter extends CustomPainter {
  final List<_ProgressPoint> points;
  final Color lineColor;
  final Color fillColor;
  final Color gridColor;
  final Color textColor;

  const _ProgressChartPainter({
    required this.points,
    required this.lineColor,
    required this.fillColor,
    required this.gridColor,
    required this.textColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const leftPad = 10.0;
    const rightPad = 10.0;
    const topPad = 12.0;
    const bottomPad = 28.0;
    final chartWidth = size.width - leftPad - rightPad;
    final chartHeight = size.height - topPad - bottomPad;

    if (chartWidth <= 0 || chartHeight <= 0 || points.isEmpty) {
      return;
    }

    final maxValue = points.map((p) => p.value).reduce((a, b) => a > b ? a : b);
    final minValue = points.map((p) => p.value).reduce((a, b) => a < b ? a : b);
    final range = (maxValue - minValue).toDouble();
    final safeRange = range == 0 ? 1.0 : range;

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;

    for (var i = 0; i < 4; i++) {
      final y = topPad + (chartHeight * i / 3);
      canvas.drawLine(
        Offset(leftPad, y),
        Offset(size.width - rightPad, y),
        gridPaint,
      );
    }

    final path = Path();
    final fillPath = Path();
    final dotPaint = Paint()..color = lineColor;
    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;

    Offset pointOffset(int index) {
      final x = points.length == 1
          ? leftPad + (chartWidth / 2)
          : leftPad + (chartWidth * index / (points.length - 1));
      final normalized = (points[index].value - minValue) / safeRange;
      final y = topPad + chartHeight - (normalized * chartHeight);
      return Offset(x, y);
    }

    final first = pointOffset(0);
    path.moveTo(first.dx, first.dy);
    fillPath.moveTo(first.dx, topPad + chartHeight);
    fillPath.lineTo(first.dx, first.dy);

    for (var i = 1; i < points.length; i++) {
      final offset = pointOffset(i);
      path.lineTo(offset.dx, offset.dy);
      fillPath.lineTo(offset.dx, offset.dy);
    }

    final last = pointOffset(points.length - 1);
    fillPath.lineTo(last.dx, topPad + chartHeight);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, linePaint);

    for (var i = 0; i < points.length; i++) {
      final offset = pointOffset(i);
      canvas.drawCircle(offset, 4, dotPaint);
    }

    final labelsToDraw = <int>{
      0,
      if (points.length > 2) points.length ~/ 2,
      points.length - 1,
    };
    for (final index in labelsToDraw) {
      final offset = pointOffset(index);
      _drawText(
        canvas,
        points[index].label,
        Offset(offset.dx - 14, size.height - 20),
        textColor,
      );
    }

    _drawText(canvas, '$maxValue', const Offset(0, 6), textColor);
    _drawText(
      canvas,
      '$minValue',
      Offset(0, topPad + chartHeight - 8),
      textColor,
    );
  }

  void _drawText(Canvas canvas, String text, Offset offset, Color color) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();

    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _ProgressChartPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.fillColor != fillColor ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.textColor != textColor;
  }
}

class _AchievementDef {
  final String id;
  final String emoji;
  final String label;
  final String desc;

  const _AchievementDef(this.id, this.emoji, this.label, this.desc);
}

const _kAchievements = [
  _AchievementDef('first_win', '🏆', 'First Win', 'First ever win'),
  _AchievementDef('win_streak_3', '🔥', '3 in a Row', '3 consecutive wins'),
  _AchievementDef(
    'comeback_king',
    '💪',
    'Comeback King',
    'Won after losing set 1',
  ),
  _AchievementDef('perfect_match', '🎯', 'Perfect Match', '2:0 victory'),
  _AchievementDef(
    'tiebreak_hero',
    '⚡',
    'Tie-Break Hero',
    'Won in super tie-break',
  ),
];
