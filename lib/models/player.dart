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
    return Player(
      id: id,
      name: map['name']?.toString() ?? '',
      rating: int.tryParse(map['rating']?.toString() ?? '0') ?? 0,
      league: map['league']?.toString() ?? '',
      frozen: map['frozen'] == true,
      archived: map['archived'] == true,
      achievements: ((map['achievements'] as Map?) ?? const <dynamic, dynamic>{})
          .map(
            (key, value) => MapEntry(
              key.toString(),
              int.tryParse(value?.toString() ?? '0') ?? 0,
            ),
          ),
    );
  }
}