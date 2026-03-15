import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/player.dart';
import '../models/match_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const double _eloK = 24;
  static const double _straightSetsMultiplier = 1.15;
  static const double _maxUpsetBonus = 0.5;
  static const int _maxRatingDeltaPerMatch = 35;

  CollectionReference get players => _db.collection('players');
  CollectionReference get matches => _db.collection('matches');

  // PLAYERS

  Stream<List<Player>> getPlayers() {
    return players.snapshots().map(
      (snapshot) => snapshot.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data() as Map);
        return Player.fromMap(data, id: doc.id);
      }).toList(),
    );
  }

  Future<void> addPlayer(Player player) async {
    final normalizedLeague = _normalizeLeague(player.league);

    await players.add({
      'name': player.name,
      'rating': _baseRatingForLeague(normalizedLeague),
      'league': normalizedLeague,
    });
  }

  Future<void> deletePlayer(String id) async {
    await players.doc(id).delete();
  }

  Future<void> updatePlayer(Player player) async {
    final id = player.id;
    if (id == null || id.isEmpty) return;

    final existingDoc = await players.doc(id).get();
    if (!existingDoc.exists) return;

    final existing = Player.fromMap(
      Map<String, dynamic>.from(existingDoc.data() as Map),
      id: existingDoc.id,
    );

    final oldLeague = _normalizeLeague(existing.league);
    final newLeague = _normalizeLeague(player.league);

    final updatedRating = oldLeague == newLeague
        ? existing.rating
        : _shiftRatingForLeagueChange(
            currentRating: existing.rating,
            fromLeague: oldLeague,
            toLeague: newLeague,
          );

    await players.doc(id).update({
      'name': player.name,
      'rating': updatedRating,
      'league': newLeague,
    });
  }

  Future<void> updatePlayerLeague({
    required String playerId,
    required String newLeague,
  }) async {
    final playerDoc = await players.doc(playerId).get();
    if (!playerDoc.exists) return;

    final player = Player.fromMap(
      Map<String, dynamic>.from(playerDoc.data() as Map),
      id: playerDoc.id,
    );

    final oldLeague = _normalizeLeague(player.league);
    final targetLeague = _normalizeLeague(newLeague);

    final shiftedRating = _shiftRatingForLeagueChange(
      currentRating: player.rating,
      fromLeague: oldLeague,
      toLeague: targetLeague,
    );

    await players.doc(playerId).update({
      'league': targetLeague,
      'rating': shiftedRating,
    });
  }

  // MATCHES

  Stream<List<MatchModel>> getMatches() {
    return matches.snapshots().map(
      (snapshot) => snapshot.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data() as Map);
        return MatchModel.fromMap(data, id: doc.id);
      }).toList(),
    );
  }

  Future<void> addMatch(MatchModel match) async {
    debugPrint('Saving match...');
    await matches.add(match.toMap());
    await _applyEloForMatch(match);
    debugPrint('Match saved successfully');
  }

  Future<void> updateMatch(MatchModel match) async {
    await matches.doc(match.id).update(match.toMap());
  }

  Future<void> deleteMatch(String id) async {
    await matches.doc(id).delete();
  }

  // LEAGUE TABLE STREAM

  Stream<List<LeagueTableRow>> getLeagueTable({
    required String league,
    String? season,
  }) {
    return _db
        .collection('players')
        .where('league', isEqualTo: league)
        .snapshots()
        .asyncExpand((playerSnapshot) {
      final playersInLeague = playerSnapshot.docs
          .map(
            (doc) => Player.fromMap(
              Map<String, dynamic>.from(doc.data() as Map),
              id: doc.id,
            ),
          )
          .toList();

      return _db.collection('matches').snapshots().map((matchSnapshot) {
        final allMatches = matchSnapshot.docs
            .map((doc) {
              final data = Map<String, dynamic>.from(doc.data() as Map);
              return MatchModel.fromMap(data, id: doc.id);
            })
            .toList();

        final filteredMatches = allMatches.where((match) {
          final belongsToLeague = _matchBelongsToLeague(
            match: match,
            playersInLeague: playersInLeague,
          );

          if (!belongsToLeague) return false;

          if (season != null && season.isNotEmpty) {
            return match.season == season;
          }

          return true;
        }).toList();

        return _buildLeagueTable(
          players: playersInLeague,
          matches: filteredMatches,
        );
      });
    });
  }

  // LEAGUE TABLE ONCE (za promotions)

  Future<List<LeagueTableRow>> getLeagueTableOnce({
    required String league,
    String? season,
  }) async {
    final playerSnapshot =
        await _db.collection('players').where('league', isEqualTo: league).get();

    final playersInLeague = playerSnapshot.docs
        .map(
          (doc) => Player.fromMap(
            Map<String, dynamic>.from(doc.data() as Map),
            id: doc.id,
          ),
        )
        .toList();

    final matchSnapshot = await _db.collection('matches').get();

    final allMatches = matchSnapshot.docs
        .map((doc) {
          final data = Map<String, dynamic>.from(doc.data() as Map);
          return MatchModel.fromMap(data, id: doc.id);
        })
        .toList();

    final filteredMatches = allMatches.where((match) {
      final belongsToLeague = _matchBelongsToLeague(
        match: match,
        playersInLeague: playersInLeague,
      );

      if (!belongsToLeague) return false;

      if (season != null && season.isNotEmpty) {
        return match.season == season;
      }

      return true;
    }).toList();

    return _buildLeagueTable(
      players: playersInLeague,
      matches: filteredMatches,
    );
  }

  // PROMOTIONS

  Future<void> applyPromotionsAndRelegations({
    required String season,
  }) async {
    final league1 = await getLeagueTableOnce(league: '1', season: season);
    final league2 = await getLeagueTableOnce(league: '2', season: season);
    final league3 = await getLeagueTableOnce(league: '3', season: season);
    final league4 = await getLeagueTableOnce(league: '4', season: season);

    final relegatedFrom1 =
        league1.length > 4 ? league1.sublist(league1.length - 4) : [];
    final promotedFrom2 =
        league2.length >= 4 ? league2.sublist(0, 4) : [];

    final relegatedFrom2 =
        league2.length > 4 ? league2.sublist(league2.length - 4) : [];
    final promotedFrom3 =
        league3.length >= 4 ? league3.sublist(0, 4) : [];

    final relegatedFrom3 =
        league3.length > 4 ? league3.sublist(league3.length - 4) : [];
    final promotedFrom4 =
        league4.length >= 4 ? league4.sublist(0, 4) : [];

    final batch = _db.batch();

    for (final row in relegatedFrom1) {
      batch.update(players.doc(row.playerId), {
        'league': '2',
        'rating': FieldValue.increment(-500),
      });
    }

    for (final row in promotedFrom2) {
      batch.update(players.doc(row.playerId), {
        'league': '1',
        'rating': FieldValue.increment(500),
      });
    }

    for (final row in relegatedFrom2) {
      batch.update(players.doc(row.playerId), {
        'league': '3',
        'rating': FieldValue.increment(-500),
      });
    }

    for (final row in promotedFrom3) {
      batch.update(players.doc(row.playerId), {
        'league': '2',
        'rating': FieldValue.increment(500),
      });
    }

    for (final row in relegatedFrom3) {
      batch.update(players.doc(row.playerId), {
        'league': '4',
        'rating': FieldValue.increment(-500),
      });
    }

    for (final row in promotedFrom4) {
      batch.update(players.doc(row.playerId), {
        'league': '3',
        'rating': FieldValue.increment(500),
      });
    }

    await batch.commit();
  }

  // HELPERS

  String _normalizeLeague(String league) {
    final value = league.trim().toLowerCase();

    if (value == '1' || value == '1. liga') return '1';
    if (value == '2' || value == '2. liga') return '2';
    if (value == '3' || value == '3. liga') return '3';
    if (value == '4' || value == '4. liga') return '4';

    return league;
  }

  int _baseRatingForLeague(String league) {
    switch (_normalizeLeague(league)) {
      case '1':
        return 2000;
      case '2':
        return 1500;
      case '3':
        return 1000;
      case '4':
        return 500;
      default:
        return 1000;
    }
  }

  int _shiftRatingForLeagueChange({
    required int currentRating,
    required String fromLeague,
    required String toLeague,
  }) {
    final fromBase = _baseRatingForLeague(fromLeague);
    final toBase = _baseRatingForLeague(toLeague);
    return currentRating + (toBase - fromBase);
  }

  Future<void> _applyEloForMatch(MatchModel match) async {
    if (match.player1Id.isEmpty || match.player2Id.isEmpty) {
      return;
    }

    await _db.runTransaction((tx) async {
      final p1Ref = players.doc(match.player1Id);
      final p2Ref = players.doc(match.player2Id);

      final p1Doc = await tx.get(p1Ref);
      final p2Doc = await tx.get(p2Ref);

      if (!p1Doc.exists || !p2Doc.exists) return;

      final p1 = Player.fromMap(
        Map<String, dynamic>.from(p1Doc.data() as Map),
        id: p1Doc.id,
      );
      final p2 = Player.fromMap(
        Map<String, dynamic>.from(p2Doc.data() as Map),
        id: p2Doc.id,
      );

      final sets = _parseSetWins(match);
      final winnerId = _resolveWinnerId(match, sets);
      if (winnerId.isEmpty) return;

      final p1Won = winnerId == match.player1Id;
      final p2Won = winnerId == match.player2Id;
      if (!p1Won && !p2Won) return;

      final expectedP1 = 1 / (1 + pow(10, (p2.rating - p1.rating) / 400));
      final expectedP2 = 1 - expectedP1;

      final scoreP1 = p1Won ? 1.0 : 0.0;
      final scoreP2 = p2Won ? 1.0 : 0.0;

      final straightSets =
          (sets.player1SetsWon == 2 && sets.player2SetsWon == 0) ||
          (sets.player2SetsWon == 2 && sets.player1SetsWon == 0);

      final upsetMultiplier = _calculateUpsetMultiplier(
        player1Rating: p1.rating,
        player2Rating: p2.rating,
        player1Won: p1Won,
      );

      final multiplier =
          (straightSets ? _straightSetsMultiplier : 1.0) * upsetMultiplier;

      final rawDeltaP1 = (_eloK * (scoreP1 - expectedP1) * multiplier).round();
      final rawDeltaP2 = (_eloK * (scoreP2 - expectedP2) * multiplier).round();

      final deltaP1 = rawDeltaP1.clamp(
        -_maxRatingDeltaPerMatch,
        _maxRatingDeltaPerMatch,
      );
      final deltaP2 = rawDeltaP2.clamp(
        -_maxRatingDeltaPerMatch,
        _maxRatingDeltaPerMatch,
      );

      tx.update(p1Ref, {'rating': p1.rating + deltaP1});
      tx.update(p2Ref, {'rating': p2.rating + deltaP2});
    });
  }

  double _calculateUpsetMultiplier({
    required int player1Rating,
    required int player2Rating,
    required bool player1Won,
  }) {
    final p1IsUnderdog = player1Rating < player2Rating;
    final p2IsUnderdog = player2Rating < player1Rating;

    final isUpset = (player1Won && p1IsUnderdog) || (!player1Won && p2IsUnderdog);

    if (!isUpset) return 1.0;

    final ratingGap = (player1Rating - player2Rating).abs().toDouble();

    // Bonus raste s razlikom ratinga, do max +50%.
    final bonus = (ratingGap / 800).clamp(0.0, _maxUpsetBonus);
    return 1.0 + bonus;
  }

  _SetWins _parseSetWins(MatchModel match) {
    int p1Sets = 0;
    int p2Sets = 0;

    final set1 = _parseScore(match.set1);
    final set2 = _parseScore(match.set2);
    final stb = _parseScore(match.superTieBreak);

    if (set1 != null) {
      if (set1[0] > set1[1]) p1Sets++;
      if (set1[1] > set1[0]) p2Sets++;
    }

    if (set2 != null) {
      if (set2[0] > set2[1]) p1Sets++;
      if (set2[1] > set2[0]) p2Sets++;
    }

    if (stb != null) {
      if (stb[0] > stb[1]) p1Sets++;
      if (stb[1] > stb[0]) p2Sets++;
    }

    return _SetWins(player1SetsWon: p1Sets, player2SetsWon: p2Sets);
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

  String _resolveWinnerId(MatchModel match, _SetWins sets) {
    if (match.winnerId.isNotEmpty) return match.winnerId;

    if (sets.player1SetsWon > sets.player2SetsWon) {
      return match.player1Id;
    }
    if (sets.player2SetsWon > sets.player1SetsWon) {
      return match.player2Id;
    }

    return '';
  }

  bool _matchBelongsToLeague({
    required MatchModel match,
    required List<Player> playersInLeague,
  }) {
    final leaguePlayerIds = playersInLeague
        .map((p) => p.id ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();

    return leaguePlayerIds.contains(match.player1Id) &&
        leaguePlayerIds.contains(match.player2Id);
  }

  List<LeagueTableRow> _buildLeagueTable({
    required List<Player> players,
    required List<MatchModel> matches,
  }) {
    final Map<String, LeagueTableRow> table = {
      for (final p in players)
        p.id ?? '':
            LeagueTableRow(playerId: p.id ?? '', playerName: p.name, league: p.league)
    };

    for (final match in matches) {
      final p1 = table[match.player1Id];
      final p2 = table[match.player2Id];
      if (p1 == null || p2 == null) continue;

      bool p1WonMatch = false;
      bool p2WonMatch = false;

      p1.played++;
      p2.played++;

      // Parse setove
      List<String> sets = [match.set1, match.set2];
      int p1SetsWon = 0;
      int p2SetsWon = 0;
      int p1Games = 0;
      int p2Games = 0;

      for (var set in sets) {
        final parts = set.split(":");
        if (parts.length == 2) {
          final s1 = int.tryParse(parts[0]) ?? 0;
          final s2 = int.tryParse(parts[1]) ?? 0;
          p1Games += s1;
          p2Games += s2;
          if (s1 > s2) p1SetsWon++;
          if (s2 > s1) p2SetsWon++;
        }
      }

      // Super tie break
      final stbParts = match.superTieBreak.split(":");
      int stb1 = stbParts.isNotEmpty ? int.tryParse(stbParts[0]) ?? 0 : 0;
      int stb2 = stbParts.length > 1 ? int.tryParse(stbParts[1]) ?? 0 : 0;
      if (stb1 > stb2) p1SetsWon++;
      if (stb2 > stb1) p2SetsWon++;

      p1.setsWon += p1SetsWon;
      p1.setsLost += p2SetsWon;
      p1.gamesWon += p1Games;
      p1.gamesLost += p2Games;

      p2.setsWon += p2SetsWon;
      p2.setsLost += p1SetsWon;
      p2.gamesWon += p2Games;
      p2.gamesLost += p1Games;

      // Odredi pobjednika
      String winnerId = match.winnerId;
      if (winnerId.isNotEmpty) {
        if (winnerId == p1.playerId) {
          p1.wins++;
          p2.losses++;
          p1WonMatch = true;
        } else if (winnerId == p2.playerId) {
          p2.wins++;
          p1.losses++;
          p2WonMatch = true;
        }
      } else {
        // Ako winnerId nije postavljen, odredi prema setovima
        if (p1SetsWon > p2SetsWon) {
          p1.wins++;
          p2.losses++;
          p1WonMatch = true;
        } else if (p2SetsWon > p1SetsWon) {
          p2.wins++;
          p1.losses++;
          p2WonMatch = true;
        }
      }

      final p1WonByTwoSets = p1SetsWon == 2 && p2SetsWon == 0;
      final p2WonByTwoSets = p2SetsWon == 2 && p1SetsWon == 0;

      // Bodovanje:
      // 2:0 -> pobjednik 3, porazeni 0
      // 2:1 -> pobjednik 2, porazeni 1
      if (p1WonMatch) {
        if (p1WonByTwoSets) {
          p1.points += 3;
        } else {
          p1.points += 2;
          p2.points += 1;
        }
      } else if (p2WonMatch) {
        if (p2WonByTwoSets) {
          p2.points += 3;
        } else {
          p2.points += 2;
          p1.points += 1;
        }
      }
    }

    final sorted = table.values.toList()
      ..sort((a, b) {
        final byPoints = b.points.compareTo(a.points);
        if (byPoints != 0) return byPoints;

        final byWins = b.wins.compareTo(a.wins);
        if (byWins != 0) return byWins;

        final bySetDiff = b.setDifference.compareTo(a.setDifference);
        if (bySetDiff != 0) return bySetDiff;

        final byGameDiff = b.gameDifference.compareTo(a.gameDifference);
        if (byGameDiff != 0) return byGameDiff;

        return a.playerName.compareTo(b.playerName);
      });

    return sorted;
  }
}

class _SetWins {
  final int player1SetsWon;
  final int player2SetsWon;

  _SetWins({
    required this.player1SetsWon,
    required this.player2SetsWon,
  });
}

class LeagueTableRow {
  final String playerId;
  final String playerName;
  final String league;

  int played = 0;
  int wins = 0;
  int losses = 0;
  int points = 0;
  int setsWon = 0;
  int setsLost = 0;
  int gamesWon = 0;
  int gamesLost = 0;

  LeagueTableRow({
    required this.playerId,
    required this.playerName,
    required this.league,
  });

  int get setDifference => setsWon - setsLost;
  int get gameDifference => gamesWon - gamesLost;
}