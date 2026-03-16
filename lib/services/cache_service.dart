import 'package:hive/hive.dart';
import '../models/player.dart';
import '../models/match_model.dart';

/// Simple caching service for scalability support
class CacheService {
  static const String playersBoxName = 'players_cache';
  static const String matchesBoxName = 'matches_cache';

  static final CacheService _instance = CacheService._();

  factory CacheService() => _instance;

  CacheService._();

  late Box<String> _playersBox;
  late Box<String> _matchesBox;

  /// Initialize cache boxes
  Future<void> init() async {
    _playersBox = await Hive.openBox<String>(playersBoxName);
    _matchesBox = await Hive.openBox<String>(matchesBoxName);
  }

  /// Cache players locally for offline support
  Future<void> cachePlayer(Player player) async {
    final json = _playerToJson(player);
    await _playersBox.put(player.id ?? '', json);
  }

  /// Get cached player
  Player? getCachedPlayer(String playerId) {
    final json = _playersBox.get(playerId);
    if (json == null) return null;
    return _jsonToPlayer(json);
  }

  /// Cache match locally
  Future<void> cacheMatch(MatchModel match) async {
    final json = _matchToJson(match);
    await _matchesBox.put(match.id, json);
  }

  /// Get cached match
  MatchModel? getCachedMatch(String matchId) {
    final json = _matchesBox.get(matchId);
    if (json == null) return null;
    return _jsonToMatch(json);
  }

  /// Clear all caches
  Future<void> clearAll() async {
    await _playersBox.clear();
    await _matchesBox.clear();
  }

  String _playerToJson(Player player) {
    return player.name; // Simplified for initial version
  }

  Player? _jsonToPlayer(String json) {
    // Simplified deserialization
    return Player(name: json, rating: 0, league: '1');
  }

  String _matchToJson(MatchModel match) {
    return match.id;
  }

  MatchModel? _jsonToMatch(String json) {
    // Simplified deserialization
    return null;
  }
}
