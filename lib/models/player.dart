class Player {
  final String? id;
  final String name;
  final int rating;
  final String league;
  final bool frozen;
  final bool archived;
  final Map<String, int> achievements;

  Player({
    this.id,
    required this.name,
    required this.rating,
    required this.league,
    this.frozen = false,
    this.archived = false,
    this.achievements = const {},
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'rating': rating,
      'league': league,
      'frozen': frozen,
      'archived': archived,
      'achievements': achievements,
    };
  }

  factory Player.fromMap(Map<dynamic, dynamic> map, {String? id}) {
    final frozenRaw = map['frozen'];
    final archivedRaw = map['archived'];

    return Player(
      id: id,
      name: map['name']?.toString() ?? '',
      rating: int.tryParse(map['rating']?.toString() ?? '0') ?? 0,
      league: map['league']?.toString() ?? '',
      frozen: frozenRaw == true || frozenRaw?.toString().toLowerCase() == 'true',
      archived:
          archivedRaw == true || archivedRaw?.toString().toLowerCase() == 'true',
      achievements: () {
        final raw = map['achievements'];
        if (raw is Map) {
          return Map<String, int>.from(
            raw.map((k, v) => MapEntry(
              k.toString(),
              (v is int) ? v : int.tryParse(v.toString()) ?? 0,
            )),
          );
        }
        return <String, int>{};
      }(),
    );
  }
}