import 'package:cloud_firestore/cloud_firestore.dart';

class MatchModel {
  final String? id;
  final String player1Id;
  final String player2Id;
  final String player1Name;
  final String player2Name;
  final String set1;
  final String set2;
  final String superTieBreak;
  final String season;
  final String winnerId;
  final DateTime playedAt;

  MatchModel({
    this.id,
    required this.player1Id,
    required this.player2Id,
    required this.player1Name,
    required this.player2Name,
    required this.set1,
    required this.set2,
    required this.superTieBreak,
    required this.season,
    required this.winnerId,
    required this.playedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'player1Id': player1Id,
      'player2Id': player2Id,
      'player1Name': player1Name,
      'player2Name': player2Name,
      'set1': set1,
      'set2': set2,
      'superTieBreak': superTieBreak,
      'season': season,
      'winnerId': winnerId,
      'playedAt': Timestamp.fromDate(playedAt),
    };
  }

  factory MatchModel.fromMap(Map<dynamic, dynamic> map, {String? id}) {
    DateTime parsedPlayedAt = DateTime.now();

    final rawPlayedAt = map['playedAt'];
    if (rawPlayedAt is Timestamp) {
      parsedPlayedAt = rawPlayedAt.toDate();
    } else if (rawPlayedAt is DateTime) {
      parsedPlayedAt = rawPlayedAt;
    } else if (rawPlayedAt is String) {
      final parsed = DateTime.tryParse(rawPlayedAt);
      if (parsed != null) {
        parsedPlayedAt = parsed;
      }
    }

    return MatchModel(
      id: id,
      player1Id: map['player1Id']?.toString() ?? '',
      player2Id: map['player2Id']?.toString() ?? '',
      player1Name: map['player1Name']?.toString() ?? '',
      player2Name: map['player2Name']?.toString() ?? '',
      set1: map['set1']?.toString() ?? '',
      set2: map['set2']?.toString() ?? '',
      superTieBreak: map['superTieBreak']?.toString() ?? '',
      season: map['season']?.toString() ?? 'Winter 2026',
      winnerId: map['winnerId']?.toString() ?? '',
      playedAt: parsedPlayedAt,
    );
  }
}
