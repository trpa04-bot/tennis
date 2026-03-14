class Player {
  final String? id;
  final String name;
  final int rating;
  final String league;

  Player({
    this.id,
    required this.name,
    required this.rating,
    required this.league,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'rating': rating,
      'league': league,
    };
  }

  factory Player.fromMap(Map<dynamic, dynamic> map, {String? id}) {
    return Player(
      id: id,
      name: map['name']?.toString() ?? '',
      rating: int.tryParse(map['rating']?.toString() ?? '0') ?? 0,
      league: map['league']?.toString() ?? '',
    );
  }
}