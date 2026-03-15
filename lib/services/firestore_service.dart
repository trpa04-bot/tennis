import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/player.dart';
import '../models/match_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

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
    await players.add({
      'name': player.name,
      'rating': player.rating,
      'league': player.league,
    });
  }

  Future<void> deletePlayer(String id) async {
    await players.doc(id).delete();
  }

  Future<void> updatePlayer(Player player) async {
    await players.doc(player.id).update({
      'name': player.name,
      'rating': player.rating,
      'league': player.league,
    });
  }

  Future<void> updatePlayerLeague({
    required String playerId,
    required String newLeague,
  }) async {
    await players.doc(playerId).update({
      'league': newLeague,
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
      batch.update(players.doc(row.playerId), {'league': '2'});
    }

    for (final row in promotedFrom2) {
      batch.update(players.doc(row.playerId), {'league': '1'});
    }

    for (final row in relegatedFrom2) {
      batch.update(players.doc(row.playerId), {'league': '3'});
    }

    for (final row in promotedFrom3) {
      batch.update(players.doc(row.playerId), {'league': '2'});
    }

    for (final row in relegatedFrom3) {
      batch.update(players.doc(row.playerId), {'league': '4'});
    }

    for (final row in promotedFrom4) {
      batch.update(players.doc(row.playerId), {'league': '3'});
    }

    await batch.commit();
  }

  // HELPERS

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