import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../utils/league_utils.dart';
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
  CollectionReference get playerArchive => _db.collection('player_archive');
  CollectionReference get activity => _db.collection('activity');
  CollectionReference get config => _db.collection('config');

  Future<void> resetTrend() async {
    await _db.collection('config').doc('trend').set({
      'resetAt': FieldValue.serverTimestamp(),
    });
  }

  // PLAYERS

  Stream<List<Player>> getPlayers() {
    return players.snapshots().map(
      (snapshot) => snapshot.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data() as Map);
        return Player.fromMap(data, id: doc.id);
      }).toList(),
    );
  }

  /// Raw stream of the player_archive collection ordered by archivedAt desc.
  Stream<QuerySnapshot> playerArchiveStream() {
    return playerArchive.orderBy('archivedAt', descending: true).snapshots();
  }

  /// Raw snapshot stream of all players (for screens that need fields not in the Player model).
  Stream<QuerySnapshot> playersRawStream() {
    return players.snapshots();
  }

  Future<void> addPlayer(Player player) async {
    final normalizedLeague = _normalizeLeague(player.league);
    final initialRating = player.rating > 0
        ? player.rating
        : _baseRatingForLeague(normalizedLeague);

    await players.add({
      'name': player.name,
      'rating': initialRating,
      'league': normalizedLeague,
      'frozen': player.frozen,
      'archived': player.archived,
      'achievements': player.achievements,
    });
  }

  Future<void> deletePlayer(String id) async {
    // Delete all matches involving this player before removing the player doc
    final matchQuery1 = await _db
        .collection('matches')
        .where('player1Id', isEqualTo: id)
        .get();
    final matchQuery2 = await _db
        .collection('matches')
        .where('player2Id', isEqualTo: id)
        .get();

    final batch = _db.batch();
    for (final doc in matchQuery1.docs) {
      batch.delete(doc.reference);
    }
    for (final doc in matchQuery2.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(players.doc(id));
    await batch.commit();

    // Rebuild derived data so ratings and achievements reflect removal
    await rebuildDerivedDataFromMatches();
  }

  Future<bool> updatePlayer(Player player) async {
    final id = player.id;
    if (id == null || id.isEmpty) return false;

    final existingDoc = await players.doc(id).get();
    if (!existingDoc.exists) return false;

    final existing = Player.fromMap(
      Map<String, dynamic>.from(existingDoc.data() as Map),
      id: existingDoc.id,
    );

    final oldLeague = _normalizeLeague(existing.league);
    final newLeague = _normalizeLeague(player.league);

    final updatedRating = oldLeague == newLeague
        ? player.rating
        : _shiftRatingForLeagueChange(
            currentRating: player.rating,
            fromLeague: oldLeague,
            toLeague: newLeague,
          );

    await players.doc(id).update({
      'name': player.name,
      'rating': updatedRating,
      'league': newLeague,
      'frozen': player.frozen,
      'archived': player.archived,
      'achievements': player.achievements,
    });

    return true;
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

  Future<void> freezePlayer(String playerId) async {
    await players.doc(playerId).update({
      'frozen': true,
      'frozenAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> unfreezePlayer(String playerId) async {
    await players.doc(playerId).update({'frozen': false, 'frozenAt': null});
  }

  Future<void> archivePlayer(String playerId) async {
    final playerDoc = await players.doc(playerId).get();
    if (!playerDoc.exists) return;

    final player = Player.fromMap(
      Map<String, dynamic>.from(playerDoc.data() as Map),
      id: playerDoc.id,
    );

    final matchSnapshot = await matches.get();
    final allMatches = matchSnapshot.docs.map((doc) {
      final data = Map<String, dynamic>.from(doc.data() as Map);
      return MatchModel.fromMap(data, id: doc.id);
    }).toList();

    final involvedMatches = allMatches.where((m) {
      final hasIds = m.player1Id.isNotEmpty || m.player2Id.isNotEmpty;
      if (hasIds) {
        return m.player1Id == playerId || m.player2Id == playerId;
      }

      return m.player1Name == player.name || m.player2Name == player.name;
    }).toList();

    final stats = _buildArchivedStats(playerId, player.name, involvedMatches);

    await playerArchive.add({
      'playerId': player.id,
      'name': player.name,
      'league': player.league,
      'rating': player.rating,
      'archivedAt': FieldValue.serverTimestamp(),
      'stats': stats,
    });

    await players.doc(playerId).update({
      'archived': true,
      'frozen': true,
      'archivedAt': FieldValue.serverTimestamp(),
    });
  }

  // MATCHES

  Stream<List<MatchModel>> getMatches() {
    return matches.orderBy('playedAt', descending: true).snapshots().map((
      snapshot,
    ) {
      final items = snapshot.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data() as Map);
        return MatchModel.fromMap(data, id: doc.id);
      }).toList();

      items.sort((a, b) => b.playedAt.compareTo(a.playedAt));
      return items;
    });
  }

  Future<void> addMatch(MatchModel match) async {
    debugPrint('Saving match...');
    final docRef = await matches.add(match.toMap());
    final savedMatch = MatchModel(
      id: docRef.id,
      player1Id: match.player1Id,
      player2Id: match.player2Id,
      player1Name: match.player1Name,
      player2Name: match.player2Name,
      league: match.league,
      set1: match.set1,
      set2: match.set2,
      superTieBreak: match.superTieBreak,
      season: match.season,
      winnerId: match.winnerId,
      playedAt: match.playedAt,
      simpleMode: match.simpleMode,
      resultLabel: match.resultLabel,
    );
    await _applyEloForMatch(savedMatch);
    if (!_isSimpleSeason(savedMatch.season)) {
      final earnedAchievements = await _checkAndGrantAchievements(savedMatch);
      await _logActivitiesForMatch(
        savedMatch,
        earnedAchievements: earnedAchievements,
      );
    }
    debugPrint('Match saved successfully');
  }

  Future<void> updateMatch(MatchModel match) async {
    await matches.doc(match.id).update(match.toMap());
  }

  Future<void> rebuildDerivedDataFromMatches() async {
    await _recalculateRatingsFromAllMatches();
    await recalculateAllAchievements();
    await rebuildActivityFeed();
  }

  Future<void> deleteMatch(String id) async {
    await matches.doc(id).delete();
    await rebuildDerivedDataFromMatches();
  }

  /// Returns all matches that still have an empty [league] field.
  /// Fetches all matches and filters client-side to also catch docs where the
  /// field is absent entirely (which Firestore where-clauses cannot find).
  Future<List<MatchModel>> getMatchesWithEmptyLeague() async {
    final snapshot = await matches.get();
    return snapshot.docs
        .map(
          (doc) => MatchModel.fromMap(
            doc.data() as Map<String, dynamic>,
            id: doc.id,
          ),
        )
        .where((m) => m.league.isEmpty)
        .toList();
  }

  /// Saves [league] onto the match document [matchId].
  Future<void> patchMatchLeague(String matchId, String league) async {
    await matches.doc(matchId).update({'league': league});
  }

  Future<MatchLeagueBackfillReport> backfillMissingMatchLeagues() async {
    final playersSnapshot = await players.get();
    final archivedSnapshot = await playerArchive.get();
    final matchSnapshot = await matches.get();

    final leagueById = <String, String>{};
    final leaguesByName = <String, Set<String>>{};

    void registerPlayer({
      required String playerId,
      required String playerName,
      required String league,
    }) {
      final normalizedLeague = _normalizeLeague(league);
      if (normalizedLeague.isEmpty) return;

      if (playerId.isNotEmpty) {
        leagueById[playerId] = normalizedLeague;
      }

      final normalizedName = _normalizePlayerName(playerName);
      if (normalizedName.isEmpty) return;

      leaguesByName
          .putIfAbsent(normalizedName, () => <String>{})
          .add(normalizedLeague);
    }

    for (final doc in playersSnapshot.docs) {
      final data = Map<String, dynamic>.from(doc.data() as Map);
      registerPlayer(
        playerId: doc.id,
        playerName: data['name']?.toString() ?? '',
        league: data['league']?.toString() ?? '',
      );
    }

    for (final doc in archivedSnapshot.docs) {
      final data = Map<String, dynamic>.from(doc.data() as Map);
      registerPlayer(
        playerId: data['playerId']?.toString() ?? '',
        playerName: data['name']?.toString() ?? '',
        league: data['league']?.toString() ?? '',
      );
    }

    ({String league, bool fromName}) resolveLeague({
      required String playerId,
      required String playerName,
    }) {
      if (playerId.isNotEmpty) {
        final byId = leagueById[playerId];
        if (byId != null && byId.isNotEmpty) {
          return (league: byId, fromName: false);
        }
      }

      final normalizedName = _normalizePlayerName(playerName);
      final leagues = leaguesByName[normalizedName];
      if (leagues != null && leagues.length == 1) {
        return (league: leagues.first, fromName: true);
      }

      return (league: '', fromName: false);
    }

    var scanned = 0;
    var updated = 0;
    var normalizedExisting = 0;
    var resolvedByIds = 0;
    var resolvedByNames = 0;
    var skippedConflicts = 0;
    var skippedUnresolved = 0;

    var batch = _db.batch();
    var operationCount = 0;

    Future<void> flushBatch() async {
      if (operationCount == 0) return;
      await batch.commit();
      batch = _db.batch();
      operationCount = 0;
    }

    for (final doc in matchSnapshot.docs) {
      final data = Map<String, dynamic>.from(doc.data() as Map);
      final match = MatchModel.fromMap(data, id: doc.id);
      final normalizedStoredLeague = _normalizeLeague(match.league);
      final storedLeagueNeedsNormalization =
          match.league.isNotEmpty && normalizedStoredLeague != match.league;
      final missingLeague = match.league.trim().isEmpty;

      if (!missingLeague && !storedLeagueNeedsNormalization) {
        continue;
      }

      scanned++;

      if (storedLeagueNeedsNormalization && normalizedStoredLeague.isNotEmpty) {
        batch.update(doc.reference, {'league': normalizedStoredLeague});
        operationCount++;
        updated++;
        normalizedExisting++;
        if (operationCount >= 400) {
          await flushBatch();
        }
        continue;
      }

      final p1League = resolveLeague(
        playerId: match.player1Id,
        playerName: match.player1Name,
      );
      final p2League = resolveLeague(
        playerId: match.player2Id,
        playerName: match.player2Name,
      );

      if (p1League.league.isEmpty || p2League.league.isEmpty) {
        skippedUnresolved++;
        continue;
      }

      if (p1League.league != p2League.league) {
        skippedConflicts++;
        continue;
      }

      batch.update(doc.reference, {'league': p1League.league});
      operationCount++;
      updated++;

      if (p1League.fromName || p2League.fromName) {
        resolvedByNames++;
      } else {
        resolvedByIds++;
      }

      if (operationCount >= 400) {
        await flushBatch();
      }
    }

    await flushBatch();

    return MatchLeagueBackfillReport(
      scanned: scanned,
      updated: updated,
      normalizedExisting: normalizedExisting,
      resolvedByIds: resolvedByIds,
      resolvedByNames: resolvedByNames,
      skippedConflicts: skippedConflicts,
      skippedUnresolved: skippedUnresolved,
    );
  }

  Stream<List<ActivityFeedItem>> getActivityFeed({
    int limit = 12,
    String? season,
  }) {
    return activity
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .asyncExpand((activitySnapshot) async* {
          if (activitySnapshot.docs.isNotEmpty) {
            yield activitySnapshot.docs
                .map((doc) {
                  final data = Map<String, dynamic>.from(doc.data() as Map);
                  return ActivityFeedItem.fromMap(data, id: doc.id);
                })
                .where(
                  (item) =>
                      season == null || season.isEmpty || item.season == season,
                )
                .toList();
            return;
          }

          yield* players.snapshots().asyncExpand((playerSnapshot) async* {
            final allPlayers = playerSnapshot.docs
                .map(
                  (doc) => Player.fromMap(
                    Map<String, dynamic>.from(doc.data() as Map),
                    id: doc.id,
                  ),
                )
                .where((player) => !player.archived && !player.frozen)
                .toList();

            yield* matches.snapshots().map((matchSnapshot) {
              final allMatches =
                  matchSnapshot.docs
                      .map((doc) {
                        final data = Map<String, dynamic>.from(
                          doc.data() as Map,
                        );
                        return MatchModel.fromMap(data, id: doc.id);
                      })
                      .where(
                        (match) => _resolveWinnerId(
                          match,
                          _parseSetWins(match),
                        ).isNotEmpty,
                      )
                      .where(
                        (match) =>
                            season == null ||
                            season.isEmpty ||
                            match.season == season,
                      )
                      .toList()
                    ..sort((a, b) => b.playedAt.compareTo(a.playedAt));

              final items = <ActivityFeedItem>[];

              for (final match in allMatches.take(limit)) {
                items.add(_buildMatchActivity(match));
                items.addAll(_buildAchievementActivities(match));
                items.addAll(
                  _buildMovementActivities(
                    match: match,
                    allPlayers: allPlayers,
                    allMatches: allMatches,
                  ),
                );
              }

              items.sort((a, b) => b.timestamp.compareTo(a.timestamp));
              return items.take(limit).toList();
            });
          });
        });
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
        .asyncExpand((playerSnapshot) async* {
          final playersInLeague = playerSnapshot.docs
              .map(
                (doc) => Player.fromMap(
                  Map<String, dynamic>.from(doc.data() as Map),
                  id: doc.id,
                ),
              )
              .where((player) => !player.frozen && !player.archived)
              .toList();

          final configDoc = await _db.collection('config').doc('trend').get();
          final resetAt = (configDoc.data()?['resetAt'] as Timestamp?)
              ?.toDate();

          yield* _db.collection('matches').snapshots().asyncMap((
            matchSnapshot,
          ) async {
            final allMatches = matchSnapshot.docs.map((doc) {
              final data = Map<String, dynamic>.from(doc.data() as Map);
              return MatchModel.fromMap(data, id: doc.id);
            }).toList();

            final resolvedPlayersInLeague = _mergePlayersWithLeagueHistory(
              league: league,
              currentPlayers: playersInLeague,
              allMatches: allMatches,
            );

            final seasonSeeds = await _getSeasonSeedsForLeague(
              league: league,
              season: season,
              playersInLeague: resolvedPlayersInLeague,
            );

            final filteredMatches = allMatches.where((match) {
              final belongsToLeague = _matchBelongsToLeague(
                league: league,
                match: match,
                playersInLeague: resolvedPlayersInLeague,
              );

              if (!belongsToLeague) return false;

              if (season != null && season.isNotEmpty) {
                return match.season == season;
              }

              return true;
            }).toList();

            filteredMatches.sort((a, b) => b.playedAt.compareTo(a.playedAt));

            List<MatchModel> previousMatches;
            if (filteredMatches.length >= 2) {
              final latestDate = filteredMatches.first.playedAt;
              previousMatches = filteredMatches
                  .where((m) => m.playedAt.isBefore(latestDate))
                  .where((m) => resetAt == null || m.playedAt.isAfter(resetAt))
                  .toList();
              // Fallback only when no reset: all matches share same timestamp
              if (previousMatches.isEmpty && resetAt == null) {
                previousMatches = filteredMatches.sublist(1);
              }
            } else {
              previousMatches = <MatchModel>[];
            }

            final currentTable = _buildLeagueTable(
              players: resolvedPlayersInLeague,
              matches: filteredMatches,
              seasonSeeds: seasonSeeds,
            );

            final previousTable = _buildLeagueTable(
              players: resolvedPlayersInLeague,
              matches: previousMatches,
              seasonSeeds: seasonSeeds,
            );

            _applyMovementAndChaseData(
              currentTable: currentTable,
              previousTable: previousTable,
            );

            return currentTable;
          });
        });
  }

  // LEAGUE TABLE ONCE (za promotions)

  Future<List<LeagueTableRow>> getLeagueTableOnce({
    required String league,
    String? season,
  }) async {
    final playerSnapshot = await _db
        .collection('players')
        .where('league', isEqualTo: league)
        .get();

    final playersInLeague = playerSnapshot.docs
        .map(
          (doc) => Player.fromMap(
            Map<String, dynamic>.from(doc.data() as Map),
            id: doc.id,
          ),
        )
        .where((player) => !player.frozen && !player.archived)
        .toList();

    final matchSnapshot = await _db.collection('matches').get();

    final allMatches = matchSnapshot.docs.map((doc) {
      final data = Map<String, dynamic>.from(doc.data() as Map);
      return MatchModel.fromMap(data, id: doc.id);
    }).toList();

    final resolvedPlayersInLeague = _mergePlayersWithLeagueHistory(
      league: league,
      currentPlayers: playersInLeague,
      allMatches: allMatches,
    );

    final filteredMatches = allMatches.where((match) {
      final belongsToLeague = _matchBelongsToLeague(
        league: league,
        match: match,
        playersInLeague: resolvedPlayersInLeague,
      );

      if (!belongsToLeague) return false;

      if (season != null && season.isNotEmpty) {
        return match.season == season;
      }

      return true;
    }).toList();

    final seasonSeeds = await _getSeasonSeedsForLeague(
      league: league,
      season: season,
      playersInLeague: resolvedPlayersInLeague,
    );

    filteredMatches.sort((a, b) => b.playedAt.compareTo(a.playedAt));

    final configDoc = await _db.collection('config').doc('trend').get();
    final resetAt = (configDoc.data()?['resetAt'] as Timestamp?)?.toDate();

    List<MatchModel> previousMatches;
    if (filteredMatches.length >= 2) {
      final latestDate = filteredMatches.first.playedAt;
      previousMatches = filteredMatches
          .where((m) => m.playedAt.isBefore(latestDate))
          .where((m) => resetAt == null || m.playedAt.isAfter(resetAt))
          .toList();
      if (previousMatches.isEmpty && resetAt == null) {
        previousMatches = filteredMatches.sublist(1);
      }
    } else {
      previousMatches = <MatchModel>[];
    }

    final currentTable = _buildLeagueTable(
      players: resolvedPlayersInLeague,
      matches: filteredMatches,
      seasonSeeds: seasonSeeds,
    );

    final previousTable = _buildLeagueTable(
      players: resolvedPlayersInLeague,
      matches: previousMatches,
      seasonSeeds: seasonSeeds,
    );

    _applyMovementAndChaseData(
      currentTable: currentTable,
      previousTable: previousTable,
    );

    return currentTable;
  }

  // PROMOTIONS

  Future<void> applyPromotionsAndRelegations({required String season}) async {
    final seasonKey = _seasonKey(season);
    final seasonRunRef = config.doc('promotions_$seasonKey');
    final existingRun = await seasonRunRef.get();
    if (existingRun.exists) {
      throw StateError('Promocije za sezonu $season su već primijenjene.');
    }

    final league1 = await getLeagueTableOnce(league: '1', season: season);
    final league2 = await getLeagueTableOnce(league: '2', season: season);
    final league3 = await getLeagueTableOnce(league: '3', season: season);
    final league4 = await getLeagueTableOnce(league: '4', season: season);

    final relegatedFrom1 = league1.length > 4
        ? league1.sublist(league1.length - 4)
        : [];
    final promotedFrom2 = league2.length >= 4 ? league2.sublist(0, 4) : [];

    final relegatedFrom2 = league2.length > 4
        ? league2.sublist(league2.length - 4)
        : [];
    final promotedFrom3 = league3.length >= 4 ? league3.sublist(0, 4) : [];

    final relegatedFrom3 = league3.length > 4
        ? league3.sublist(league3.length - 4)
        : [];
    final promotedFrom4 = league4.length >= 4 ? league4.sublist(0, 4) : [];

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

    batch.set(seasonRunRef, {
      'season': season,
      'appliedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  // HELPERS

  String _normalizeLeague(String league) => LeagueUtils.normalize(league);

  bool _isSimpleSeason(String season) => season == 'Winter 2026';

  String _seasonKey(String season) {
    return season.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
  }

  Future<Map<String, _SeasonTableSeed>> _getSeasonSeedsForLeague({
    required String league,
    required String? season,
    required List<Player> playersInLeague,
  }) async {
    if (season == null || season.isEmpty) return const {};

    final snapshot = await _db
        .collection('season_table_seeds')
        .where('season', isEqualTo: season)
        .where('league', isEqualTo: league)
        .get();

    if (snapshot.docs.isEmpty) return const {};

    final byId = <String, _SeasonTableSeed>{};
    final byNormalizedName = <String, _SeasonTableSeed>{};

    for (final doc in snapshot.docs) {
      final data = Map<String, dynamic>.from(doc.data() as Map);
      final seed = _SeasonTableSeed(
        playerId: data['playerId']?.toString() ?? '',
        playerName: data['playerName']?.toString() ?? '',
        played: int.tryParse(data['played']?.toString() ?? '0') ?? 0,
        points: int.tryParse(data['points']?.toString() ?? '0') ?? 0,
        rank: int.tryParse(data['rank']?.toString() ?? '0') ?? 0,
      );

      if (seed.playerId.isNotEmpty) {
        byId[seed.playerId] = seed;
      }

      if (seed.playerName.trim().isNotEmpty) {
        byNormalizedName[_normalizePlayerName(seed.playerName)] = seed;
      }
    }

    final resolved = <String, _SeasonTableSeed>{};
    for (final player in playersInLeague) {
      final id = player.id ?? '';
      if (id.isNotEmpty && byId.containsKey(id)) {
        resolved[id] = byId[id]!;
        continue;
      }

      final byName = byNormalizedName[_normalizePlayerName(player.name)];
      if (byName != null && id.isNotEmpty) {
        resolved[id] = byName;
      }
    }

    return resolved;
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

  Future<void> _recalculateRatingsFromAllMatches() async {
    final playerSnapshot = await players.get();

    WriteBatch batch = _db.batch();
    int operationCount = 0;

    Future<void> flushBatch() async {
      if (operationCount == 0) return;
      await batch.commit();
      batch = _db.batch();
      operationCount = 0;
    }

    for (final playerDoc in playerSnapshot.docs) {
      final data = Map<String, dynamic>.from(playerDoc.data() as Map);
      final league = data['league']?.toString() ?? '';

      batch.update(playerDoc.reference, {
        'rating': _baseRatingForLeague(league),
      });
      operationCount++;

      if (operationCount >= 450) {
        await flushBatch();
      }
    }

    await flushBatch();

    final matchSnapshot = await matches.get();
    final allMatches =
        matchSnapshot.docs
            .map((doc) {
              final data = Map<String, dynamic>.from(doc.data() as Map);
              return MatchModel.fromMap(data, id: doc.id);
            })
            .where(
              (match) =>
                  _resolveWinnerId(match, _parseSetWins(match)).isNotEmpty,
            )
            .toList()
          ..sort((a, b) => a.playedAt.compareTo(b.playedAt));

    for (final match in allMatches) {
      await _applyEloForMatch(match);
    }
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

    final isUpset =
        (player1Won && p1IsUnderdog) || (!player1Won && p2IsUnderdog);

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

  String _normalizePlayerName(String name) {
    return name.trim().toLowerCase();
  }

  Future<String> _resolvePlayerDocId({
    required String playerId,
    required String playerName,
  }) async {
    if (playerId.isNotEmpty) return playerId;

    final trimmedName = playerName.trim();
    if (trimmedName.isEmpty) return '';

    final exactSnapshot = await players
        .where('name', isEqualTo: trimmedName)
        .limit(1)
        .get();
    if (exactSnapshot.docs.isNotEmpty) {
      return exactSnapshot.docs.first.id;
    }

    final normalizedName = _normalizePlayerName(trimmedName);
    final allPlayersSnapshot = await players.get();
    for (final doc in allPlayersSnapshot.docs) {
      final data = Map<String, dynamic>.from(doc.data() as Map);
      final name = data['name']?.toString() ?? '';
      if (_normalizePlayerName(name) == normalizedName) {
        return doc.id;
      }
    }

    return '';
  }

  bool _matchInvolvesPlayer(
    MatchModel match, {
    required String playerId,
    required String playerName,
  }) {
    if (match.player1Id == playerId || match.player2Id == playerId) {
      return true;
    }

    final normalizedName = _normalizePlayerName(playerName);
    return _normalizePlayerName(match.player1Name) == normalizedName ||
        _normalizePlayerName(match.player2Name) == normalizedName;
  }

  bool _didPlayerWinResolved(
    MatchModel match, {
    required String playerId,
    required String playerName,
  }) {
    final sets = _parseSetWins(match);
    if (sets.player1SetsWon == sets.player2SetsWon) {
      return false;
    }

    if (match.winnerId.isNotEmpty && match.winnerId == playerId) {
      return true;
    }

    final normalizedName = _normalizePlayerName(playerName);
    final isPlayer1 =
        match.player1Id == playerId ||
        _normalizePlayerName(match.player1Name) == normalizedName;
    final isPlayer2 =
        match.player2Id == playerId ||
        _normalizePlayerName(match.player2Name) == normalizedName;

    if (isPlayer1) {
      return sets.player1SetsWon > sets.player2SetsWon;
    }
    if (isPlayer2) {
      return sets.player2SetsWon > sets.player1SetsWon;
    }

    return false;
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

  Map<String, dynamic> _buildArchivedStats(
    String playerId,
    String playerName,
    List<MatchModel> matches,
  ) {
    int played = 0;
    int wins = 0;
    int losses = 0;

    for (final match in matches) {
      played++;
      final winnerId = _resolveWinnerId(match, _parseSetWins(match));

      if (winnerId.isNotEmpty) {
        if (winnerId == playerId) {
          wins++;
        } else {
          losses++;
        }
        continue;
      }

      final p1 = match.player1Name.trim().toLowerCase();
      final player = playerName.trim().toLowerCase();
      final didWinAsP1 = _didPlayer1Win(match);

      if (didWinAsP1 == null) continue;
      final isPlayer1 = p1 == player;

      final didWin = isPlayer1 ? didWinAsP1 : !didWinAsP1;
      if (didWin) {
        wins++;
      } else {
        losses++;
      }
    }

    return {'played': played, 'wins': wins, 'losses': losses};
  }

  bool? _didPlayer1Win(MatchModel match) {
    final sets = _parseSetWins(match);
    if (sets.player1SetsWon == sets.player2SetsWon) return null;
    return sets.player1SetsWon > sets.player2SetsWon;
  }

  bool _matchBelongsToLeague({
    required String league,
    required MatchModel match,
    required List<Player> playersInLeague,
  }) {
    if (match.league.isNotEmpty) {
      return _normalizeLeague(match.league) == _normalizeLeague(league);
    }

    final leaguePlayerIds = playersInLeague
        .map((p) => p.id ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();

    return leaguePlayerIds.contains(match.player1Id) &&
        leaguePlayerIds.contains(match.player2Id);
  }

  ActivityFeedItem _buildMatchActivity(MatchModel match) {
    final winnerId = _resolveWinnerId(match, _parseSetWins(match));
    final winnerName = winnerId == match.player1Id
        ? match.player1Name
        : match.player2Name;
    final loserName = winnerId == match.player1Id
        ? match.player2Name
        : match.player1Name;

    return ActivityFeedItem(
      timestamp: match.playedAt,
      icon: ActivityFeedIcon.match,
      title: '$winnerName defeated $loserName',
      subtitle: _buildActivityScore(match),
    );
  }

  List<ActivityFeedItem> _buildAchievementActivities(MatchModel match) {
    final winnerId = _resolveWinnerId(match, _parseSetWins(match));
    if (winnerId.isEmpty) return const [];

    final winnerName = winnerId == match.player1Id
        ? match.player1Name
        : match.player2Name;
    final achievements = _activityAchievementsForMatch(match, winnerId);

    return achievements
        .map(
          (achievementId) => ActivityFeedItem(
            timestamp: match.playedAt.subtract(const Duration(seconds: 1)),
            icon: ActivityFeedIcon.achievement,
            title: '$winnerName earned badge',
            subtitle: _achievementLabel(achievementId),
          ),
        )
        .toList();
  }

  List<ActivityFeedItem> _buildMovementActivities({
    required MatchModel match,
    required List<Player> allPlayers,
    required List<MatchModel> allMatches,
  }) {
    final league = _leagueForMatch(match, allPlayers);
    if (league.isEmpty) return const [];

    final leaguePlayers = allPlayers
        .where(
          (player) =>
              !player.frozen &&
              !player.archived &&
              _normalizeLeague(player.league) == league,
        )
        .toList();
    final resolvedLeaguePlayers = _mergePlayersWithLeagueHistory(
      league: league,
      currentPlayers: leaguePlayers,
      allMatches: allMatches,
    );
    if (resolvedLeaguePlayers.isEmpty) return const [];

    final upToMatch = allMatches
        .where(
          (m) =>
              m.playedAt.isBefore(match.playedAt) ||
              m.playedAt.isAtSameMomentAs(match.playedAt),
        )
        .where((m) => m.season == match.season)
        .where(
          (m) => _matchBelongsToLeague(
            league: league,
            match: m,
            playersInLeague: resolvedLeaguePlayers,
          ),
        )
        .toList();

    final beforeMatch = upToMatch.where((m) => m.id != match.id).toList();
    if (beforeMatch.isEmpty) return const [];

    final currentTable = _buildLeagueTable(
      players: resolvedLeaguePlayers,
      matches: upToMatch,
    );
    final previousTable = _buildLeagueTable(
      players: resolvedLeaguePlayers,
      matches: beforeMatch,
    );
    _applyMovementAndChaseData(
      currentTable: currentTable,
      previousTable: previousTable,
    );

    final movers = currentTable.where((row) => row.movement != 0).toList()
      ..sort((a, b) => b.movement.abs().compareTo(a.movement.abs()));

    if (movers.isEmpty) return const [];

    final topMover = movers.first;
    if (topMover.movement > 0) {
      return [
        ActivityFeedItem(
          timestamp: match.playedAt.subtract(const Duration(seconds: 2)),
          icon: ActivityFeedIcon.rankUp,
          title:
              '${topMover.playerName} moved to #${currentTable.indexOf(topMover) + 1}',
          subtitle:
              'Up ${topMover.movement} place${topMover.movement == 1 ? '' : 's'} in League $league',
        ),
      ];
    }

    return [
      ActivityFeedItem(
        timestamp: match.playedAt.subtract(const Duration(seconds: 2)),
        icon: ActivityFeedIcon.rankDown,
        title:
            '${topMover.playerName} dropped to #${currentTable.indexOf(topMover) + 1}',
        subtitle:
            'Down ${topMover.movement.abs()} place${topMover.movement.abs() == 1 ? '' : 's'} in League $league',
      ),
    ];
  }

  Future<void> _logActivitiesForMatch(
    MatchModel match, {
    required List<String> earnedAchievements,
  }) async {
    final items = <ActivityFeedItem>[
      _buildMatchActivity(match),
      ...earnedAchievements.map(
        (achievementId) => ActivityFeedItem(
          timestamp: match.playedAt.subtract(const Duration(seconds: 1)),
          icon: ActivityFeedIcon.achievement,
          title: '${_winnerNameForActivity(match)} earned badge',
          subtitle: _achievementLabel(achievementId),
          season: match.season,
        ),
      ),
    ];

    final playersSnapshot = await players.get();
    final allPlayers = playersSnapshot.docs
        .map(
          (doc) => Player.fromMap(
            Map<String, dynamic>.from(doc.data() as Map),
            id: doc.id,
          ),
        )
        .where((player) => !player.archived && !player.frozen)
        .toList();

    final allMatchesSnapshot = await matches.get();
    final allMatches =
        allMatchesSnapshot.docs
            .map((doc) {
              final data = Map<String, dynamic>.from(doc.data() as Map);
              return MatchModel.fromMap(data, id: doc.id);
            })
            .where((m) => m.season == match.season)
            .toList()
          ..sort((a, b) => b.playedAt.compareTo(a.playedAt));

    items.addAll(
      _buildMovementActivities(
        match: match,
        allPlayers: allPlayers,
        allMatches: allMatches,
      ).map(
        (item) => ActivityFeedItem(
          timestamp: item.timestamp,
          icon: item.icon,
          title: item.title,
          subtitle: item.subtitle,
          season: match.season,
        ),
      ),
    );

    final batch = _db.batch();
    for (final item in items) {
      batch.set(activity.doc(), item.toMap());
    }
    await batch.commit();
  }

  String _winnerNameForActivity(MatchModel match) {
    final winnerId = _resolveWinnerId(match, _parseSetWins(match));
    if (winnerId == match.player1Id) return match.player1Name;
    if (winnerId == match.player2Id) return match.player2Name;
    return 'Unknown player';
  }

  String _leagueForMatch(MatchModel match, List<Player> players) {
    if (match.league.isNotEmpty) {
      return _normalizeLeague(match.league);
    }

    for (final player in players) {
      if (player.id == match.player1Id || player.id == match.player2Id) {
        return _normalizeLeague(player.league);
      }
    }
    return '';
  }

  List<String> _activityAchievementsForMatch(
    MatchModel match,
    String winnerId,
  ) {
    final sets = _parseSetWins(match);
    final winnerIsP1 = winnerId == match.player1Id;
    final winnerSets = winnerIsP1 ? sets.player1SetsWon : sets.player2SetsWon;
    final loserSets = winnerIsP1 ? sets.player2SetsWon : sets.player1SetsWon;
    final set1 = _parseScore(match.set1);
    final stb = _parseScore(match.superTieBreak);

    final result = <String>[];
    if (winnerSets == 2 && loserSets == 0) {
      result.add('perfect_match');
    }
    if (stb != null) {
      final winnerWonStb = winnerIsP1 ? stb[0] > stb[1] : stb[1] > stb[0];
      if (winnerWonStb) {
        result.add('tiebreak_hero');
      }
    }
    if (set1 != null) {
      final winnerLostSet1 = winnerIsP1 ? set1[1] > set1[0] : set1[0] > set1[1];
      if (winnerLostSet1) {
        result.add('comeback_king');
      }
    }
    return result;
  }

  String _achievementLabel(String achievementId) {
    switch (achievementId) {
      case 'first_win':
        return 'First Win';
      case 'win_streak_3':
        return '3 Wins in a Row';
      case 'comeback_king':
        return 'Comeback King';
      case 'perfect_match':
        return 'Perfect Match';
      case 'tiebreak_hero':
        return 'Tie-Break Hero';
      default:
        return achievementId;
    }
  }

  String _buildActivityScore(MatchModel match) {
    if (match.simpleMode && match.resultLabel.trim().isNotEmpty) {
      return match.resultLabel;
    }

    final scores = <String>[];
    for (final raw in [match.set1, match.set2, match.superTieBreak]) {
      if (raw.trim().isEmpty) continue;
      scores.add(raw.replaceAll(':', '-'));
    }
    return scores.join(' ');
  }

  void _applyMovementAndChaseData({
    required List<LeagueTableRow> currentTable,
    required List<LeagueTableRow> previousTable,
  }) {
    // Only show movement if previous table has meaningful data (at least one player with points).
    final hasPreviousData = previousTable.any((r) => r.points > 0);

    final previousPositionById = <String, int>{
      for (int i = 0; i < previousTable.length; i++)
        previousTable[i].playerId: i + 1,
    };

    for (int i = 0; i < currentTable.length; i++) {
      final row = currentTable[i];
      final currentPos = i + 1;
      final previousPos = previousPositionById[row.playerId];

      if (!hasPreviousData || previousPos == null) {
        row.movement = 0;
      } else {
        row.movement = previousPos - currentPos;
      }

      if (i == 0) {
        row.pointsToNext = 0;
      } else {
        final above = currentTable[i - 1];
        row.pointsToNext = max(0, (above.points - row.points) + 1);
      }
    }
  }

  Future<List<String>> _checkAndGrantAchievements(MatchModel match) async {
    final sets = _parseSetWins(match);
    if (sets.player1SetsWon == sets.player2SetsWon) return <String>[];

    final winnerIsP1 = sets.player1SetsWon > sets.player2SetsWon;
    final winnerId = await _resolvePlayerDocId(
      playerId: winnerIsP1 ? match.player1Id : match.player2Id,
      playerName: winnerIsP1 ? match.player1Name : match.player2Name,
    );
    if (winnerId.isEmpty) return <String>[];

    final winnerSets = winnerIsP1 ? sets.player1SetsWon : sets.player2SetsWon;
    final loserSets = winnerIsP1 ? sets.player2SetsWon : sets.player1SetsWon;

    final set1 = _parseScore(match.set1);
    final stb = _parseScore(match.superTieBreak);

    final Map<String, dynamic> updates = {};
    final earnedAchievements = <String>[];

    // perfect_match: 2:0 victory
    if (winnerSets == 2 && loserSets == 0) {
      updates['achievements.perfect_match'] = FieldValue.increment(1);
      earnedAchievements.add('perfect_match');
    }

    // tiebreak_hero: won the super tie-break to win the match
    if (stb != null) {
      final winnerWonStb = winnerIsP1 ? stb[0] > stb[1] : stb[1] > stb[0];
      if (winnerWonStb) {
        updates['achievements.tiebreak_hero'] = FieldValue.increment(1);
        earnedAchievements.add('tiebreak_hero');
      }
    }

    // comeback_king: lost set 1 but won the match
    if (set1 != null) {
      final winnerLostSet1 = winnerIsP1 ? set1[1] > set1[0] : set1[0] > set1[1];
      if (winnerLostSet1) {
        updates['achievements.comeback_king'] = FieldValue.increment(1);
        earnedAchievements.add('comeback_king');
      }
    }

    if (updates.isNotEmpty) {
      await players.doc(winnerId).update(updates);
    }

    earnedAchievements.addAll(await _checkCumulativeAchievements(winnerId));
    return earnedAchievements;
  }

  Future<List<String>> _checkCumulativeAchievements(String playerId) async {
    final playerDoc = await players.doc(playerId).get();
    if (!playerDoc.exists) return <String>[];

    final playerData = Map<String, dynamic>.from(playerDoc.data() as Map);
    final playerName = playerData['name']?.toString() ?? '';

    final matchSnapshot = await matches.get();
    final playerMatches =
        matchSnapshot.docs
            .map((doc) {
              final data = Map<String, dynamic>.from(doc.data() as Map);
              return MatchModel.fromMap(data, id: doc.id);
            })
            .where(
              (m) =>
                  _matchInvolvesPlayer(
                    m,
                    playerId: playerId,
                    playerName: playerName,
                  ) &&
                  !_isSimpleSeason(m.season),
            )
            .toList()
          ..sort((a, b) => a.playedAt.compareTo(b.playedAt)); // oldest first

    final Map<String, dynamic> updates = {};
    final currentAch = Map<String, dynamic>.from(
      (playerData['achievements'] as Map?) ?? {},
    );
    final earnedAchievements = <String>[];

    // first_win: grant once only
    final hasWin = playerMatches.any(
      (m) =>
          _didPlayerWinResolved(m, playerId: playerId, playerName: playerName),
    );
    if (hasWin) {
      if ((currentAch['first_win'] as int? ?? 0) == 0) {
        updates['achievements.first_win'] = 1;
        earnedAchievements.add('first_win');
      }
    }

    // win_streak_3: trailing win streak divisible by 3 → new group of 3 completed
    int trailingStreak = 0;
    for (final m in playerMatches.reversed) {
      if (_didPlayerWinResolved(
        m,
        playerId: playerId,
        playerName: playerName,
      )) {
        trailingStreak++;
      } else {
        break;
      }
    }
    final currentStreakCount = currentAch['win_streak_3'] as int? ?? 0;
    final expectedStreakCount = trailingStreak ~/ 3;
    if (expectedStreakCount > currentStreakCount) {
      updates['achievements.win_streak_3'] = FieldValue.increment(1);
      earnedAchievements.add('win_streak_3');
    }

    if (updates.isNotEmpty) {
      await players.doc(playerId).update(updates);
    }
    return earnedAchievements;
  }

  /// Recalculates achievements for every player from scratch based on all matches.
  Future<void> recalculateAllAchievements() async {
    final playerSnapshot = await players.get();
    final matchSnapshot = await matches.get();

    final allMatches =
        matchSnapshot.docs
            .map((doc) {
              final data = Map<String, dynamic>.from(doc.data() as Map);
              return MatchModel.fromMap(data, id: doc.id);
            })
            .where((match) => !_isSimpleSeason(match.season))
            .toList()
          ..sort((a, b) => a.playedAt.compareTo(b.playedAt)); // oldest first

    final batch = _db.batch();

    for (final playerDoc in playerSnapshot.docs) {
      final playerId = playerDoc.id;
      final playerMatches = allMatches
          .where((m) => m.player1Id == playerId || m.player2Id == playerId)
          .toList(); // already sorted oldest first

      final Map<String, int> earned = {};

      // first_win
      final hasWin = playerMatches.any(
        (m) => _resolveWinnerId(m, _parseSetWins(m)) == playerId,
      );
      if (hasWin) earned['first_win'] = 1;

      // win_streak_3: non-overlapping groups of 3 consecutive wins
      int currentStreak = 0;
      for (final m in playerMatches) {
        if (_resolveWinnerId(m, _parseSetWins(m)) == playerId) {
          currentStreak++;
          if (currentStreak % 3 == 0) {
            earned['win_streak_3'] = (earned['win_streak_3'] ?? 0) + 1;
          }
        } else {
          currentStreak = 0;
        }
      }

      // Per-match achievements (counted)
      for (final match in playerMatches) {
        final sets = _parseSetWins(match);
        final winnerId = _resolveWinnerId(match, sets);
        if (winnerId != playerId) continue;

        final winnerIsP1 = match.player1Id == playerId;
        final winnerSets = winnerIsP1
            ? sets.player1SetsWon
            : sets.player2SetsWon;
        final loserSets = winnerIsP1
            ? sets.player2SetsWon
            : sets.player1SetsWon;

        if (winnerSets == 2 && loserSets == 0) {
          earned['perfect_match'] = (earned['perfect_match'] ?? 0) + 1;
        }

        final stb = _parseScore(match.superTieBreak);
        if (stb != null) {
          final winnerWonStb = winnerIsP1 ? stb[0] > stb[1] : stb[1] > stb[0];
          if (winnerWonStb) {
            earned['tiebreak_hero'] = (earned['tiebreak_hero'] ?? 0) + 1;
          }
        }

        final set1 = _parseScore(match.set1);
        if (set1 != null) {
          final winnerLostSet1 = winnerIsP1
              ? set1[1] > set1[0]
              : set1[0] > set1[1];
          if (winnerLostSet1) {
            earned['comeback_king'] = (earned['comeback_king'] ?? 0) + 1;
          }
        }
      }

      batch.update(players.doc(playerId), {'achievements': earned});
    }

    await batch.commit();
  }

  /// Deletes all existing activity docs and rebuilds them from scratch
  /// based on every match in the database.
  Future<void> rebuildActivityFeed() async {
    // 1. Delete all existing activity documents in batches of 499
    var activitySnapshot = await activity.get();
    while (activitySnapshot.docs.isNotEmpty) {
      final deleteBatch = _db.batch();
      final chunk = activitySnapshot.docs.take(499).toList();
      for (final doc in chunk) {
        deleteBatch.delete(doc.reference);
      }
      await deleteBatch.commit();
      if (activitySnapshot.docs.length <= 499) break;
      activitySnapshot = await activity.get();
    }

    // 2. Load all data
    final playersSnapshot = await players.get();
    final allPlayers = playersSnapshot.docs
        .map(
          (doc) => Player.fromMap(
            Map<String, dynamic>.from(doc.data() as Map),
            id: doc.id,
          ),
        )
        .where((p) => !p.archived && !p.frozen)
        .toList();

    final matchesSnapshot = await matches.get();
    final allMatches =
        matchesSnapshot.docs
            .map(
              (doc) => MatchModel.fromMap(
                Map<String, dynamic>.from(doc.data() as Map),
                id: doc.id,
              ),
            )
            .where((m) => !_isSimpleSeason(m.season))
            .where((m) => _resolveWinnerId(m, _parseSetWins(m)).isNotEmpty)
            .toList()
          ..sort((a, b) => a.playedAt.compareTo(b.playedAt)); // oldest first

    // 3. Build activity items for every match
    final items = <ActivityFeedItem>[];

    for (final match in allMatches) {
      final winnerId = _resolveWinnerId(match, _parseSetWins(match));

      // Match result
      final matchActivity = _buildMatchActivity(match);
      items.add(
        ActivityFeedItem(
          timestamp: matchActivity.timestamp,
          icon: matchActivity.icon,
          title: matchActivity.title,
          subtitle: matchActivity.subtitle,
          season: match.season,
        ),
      );

      // Badge activities
      for (final achievementId in _activityAchievementsForMatch(
        match,
        winnerId,
      )) {
        items.add(
          ActivityFeedItem(
            timestamp: match.playedAt.subtract(const Duration(seconds: 1)),
            icon: ActivityFeedIcon.achievement,
            title: '${_winnerNameForActivity(match)} earned badge',
            subtitle: _achievementLabel(achievementId),
            season: match.season,
          ),
        );
      }

      // Rank movement activities
      for (final item in _buildMovementActivities(
        match: match,
        allPlayers: allPlayers,
        allMatches: allMatches,
      )) {
        items.add(
          ActivityFeedItem(
            timestamp: item.timestamp,
            icon: item.icon,
            title: item.title,
            subtitle: item.subtitle,
            season: match.season,
          ),
        );
      }
    }

    // 4. Write all items in batches of 499
    const batchSize = 499;
    for (var i = 0; i < items.length; i += batchSize) {
      final writeBatch = _db.batch();
      for (final item in items.skip(i).take(batchSize)) {
        writeBatch.set(activity.doc(), item.toMap());
      }
      await writeBatch.commit();
    }
  }

  List<LeagueTableRow> _buildLeagueTable({
    required List<Player> players,
    required List<MatchModel> matches,
    Map<String, _SeasonTableSeed> seasonSeeds = const {},
  }) {
    final Map<String, LeagueTableRow> table = {
      for (final p in players)
        p.id ?? '': LeagueTableRow(
          playerId: p.id ?? '',
          playerName: p.name,
          league: p.league,
        ),
    };

    for (final entry in seasonSeeds.entries) {
      final row = table[entry.key];
      if (row == null) continue;
      row.played = entry.value.played;
      row.points = entry.value.points;
      row.seedRank = entry.value.rank;
    }

    LeagueTableRow? rowForParticipant(String playerId, String playerName) {
      if (playerId.isNotEmpty) {
        final byId = table[playerId];
        if (byId != null) return byId;
      }

      final normalizedName = _normalizePlayerName(playerName);
      for (final row in table.values) {
        if (_normalizePlayerName(row.playerName) == normalizedName) {
          return row;
        }
      }

      return null;
    }

    for (final match in matches) {
      final p1 = rowForParticipant(match.player1Id, match.player1Name);
      final p2 = rowForParticipant(match.player2Id, match.player2Name);
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

        if (a.seedRank > 0 && b.seedRank > 0 && a.seedRank != b.seedRank) {
          return a.seedRank.compareTo(b.seedRank);
        }

        return a.playerName.compareTo(b.playerName);
      });

    return sorted;
  }

  List<Player> _mergePlayersWithLeagueHistory({
    required String league,
    required List<Player> currentPlayers,
    required List<MatchModel> allMatches,
  }) {
    final normalizedLeague = _normalizeLeague(league);
    final byId = <String, Player>{
      for (final player in currentPlayers)
        if ((player.id ?? '').isNotEmpty) player.id!: player,
    };
    final byName = <String, Player>{
      for (final player in currentPlayers)
        _normalizePlayerName(player.name): player,
    };

    void ensurePlayer({required String playerId, required String playerName}) {
      if (playerId.isNotEmpty && byId.containsKey(playerId)) {
        return;
      }

      final normalizedName = _normalizePlayerName(playerName);
      if (normalizedName.isEmpty || byName.containsKey(normalizedName)) {
        return;
      }

      final resolvedId = playerId.isNotEmpty
          ? playerId
          : 'historical:$normalizedLeague:$normalizedName';
      final historicalPlayer = Player(
        id: resolvedId,
        name: playerName,
        rating: _baseRatingForLeague(normalizedLeague),
        league: normalizedLeague,
      );

      byId[resolvedId] = historicalPlayer;
      byName[normalizedName] = historicalPlayer;
    }

    for (final match in allMatches) {
      if (_normalizeLeague(match.league) != normalizedLeague) continue;

      ensurePlayer(playerId: match.player1Id, playerName: match.player1Name);
      ensurePlayer(playerId: match.player2Id, playerName: match.player2Name);
    }

    return byId.values.toList()..sort((a, b) => a.name.compareTo(b.name));
  }
}

class MatchLeagueBackfillReport {
  final int scanned;
  final int updated;
  final int normalizedExisting;
  final int resolvedByIds;
  final int resolvedByNames;
  final int skippedConflicts;
  final int skippedUnresolved;

  const MatchLeagueBackfillReport({
    required this.scanned,
    required this.updated,
    required this.normalizedExisting,
    required this.resolvedByIds,
    required this.resolvedByNames,
    required this.skippedConflicts,
    required this.skippedUnresolved,
  });
}

class _SetWins {
  final int player1SetsWon;
  final int player2SetsWon;

  _SetWins({required this.player1SetsWon, required this.player2SetsWon});
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
  int movement = 0;
  int pointsToNext = 0;
  int seedRank = 0;

  LeagueTableRow({
    required this.playerId,
    required this.playerName,
    required this.league,
  });

  int get setDifference => setsWon - setsLost;
  int get gameDifference => gamesWon - gamesLost;
}

enum ActivityFeedIcon { match, achievement, rankUp, rankDown }

class ActivityFeedItem {
  final String? id;
  final DateTime timestamp;
  final ActivityFeedIcon icon;
  final String title;
  final String subtitle;
  final String? season;

  const ActivityFeedItem({
    this.id,
    required this.timestamp,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.season,
  });

  Map<String, dynamic> toMap() {
    return {
      'timestamp': Timestamp.fromDate(timestamp),
      'icon': icon.name,
      'title': title,
      'subtitle': subtitle,
      'season': season,
    };
  }

  factory ActivityFeedItem.fromMap(Map<dynamic, dynamic> map, {String? id}) {
    final rawTimestamp = map['timestamp'];
    DateTime parsedTimestamp = DateTime.now();
    if (rawTimestamp is Timestamp) {
      parsedTimestamp = rawTimestamp.toDate();
    } else if (rawTimestamp is DateTime) {
      parsedTimestamp = rawTimestamp;
    }

    final iconName = map['icon']?.toString() ?? ActivityFeedIcon.match.name;
    final icon = ActivityFeedIcon.values.firstWhere(
      (value) => value.name == iconName,
      orElse: () => ActivityFeedIcon.match,
    );

    return ActivityFeedItem(
      id: id,
      timestamp: parsedTimestamp,
      icon: icon,
      title: map['title']?.toString() ?? '',
      subtitle: map['subtitle']?.toString() ?? '',
      season: map['season']?.toString(),
    );
  }
}

class _SeasonTableSeed {
  final String playerId;
  final String playerName;
  final int played;
  final int points;
  final int rank;

  const _SeasonTableSeed({
    required this.playerId,
    required this.playerName,
    required this.played,
    required this.points,
    required this.rank,
  });
}
