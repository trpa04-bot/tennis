class ScheduledMatchSlot {
  final String league;
  final String cycleLabel;
  final int roundNumber;
  final DateTime startAt;
  final int courtNumber;
  final String player1Id;
  final String player2Id;
  final String player1Name;
  final String player2Name;

  ScheduledMatchSlot({
    required this.league,
    required this.cycleLabel,
    required this.roundNumber,
    required this.startAt,
    required this.courtNumber,
    required this.player1Id,
    required this.player2Id,
    required this.player1Name,
    required this.player2Name,
  });
}

class ScheduledRound {
  final String league;
  final String cycleLabel;
  final int roundNumber;
  final DateTime date;
  final List<ScheduledMatchSlot> matches;

  ScheduledRound({
    required this.league,
    required this.cycleLabel,
    required this.roundNumber,
    required this.date,
    required this.matches,
  });
}