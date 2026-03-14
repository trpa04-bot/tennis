import '../models/player.dart';
import '../models/round_robin_models.dart';

class RoundRobinService {
  static const List<int> _slotHours = [15, 16, 18, 19];
  static const List<int> _slotMinutes = [0, 30, 0, 30];
  static const int _courtsPerSlot = 3;

  List<ScheduledRound> generateWinterSchedule({
    required List<Player> players,
    required String league,
    required int seasonYear,
    String cycleLabel = 'Cycle 1',
  }) {
    final normalizedPlayers = [...players]..sort((a, b) => a.name.compareTo(b.name));

    if (normalizedPlayers.length < 2) {
      return [];
    }

    final rounds = _buildRoundRobinRounds(normalizedPlayers);
    final playDates = _winterPlayDates(seasonYear);

    if (playDates.isEmpty) {
      return [];
    }

    final List<ScheduledRound> scheduledRounds = [];

    for (int i = 0; i < rounds.length; i++) {
      if (i >= playDates.length) {
        break;
      }

      final roundDate = playDates[i];
      final pairings = rounds[i];

      final slots = _assignRoundToSlots(
        league: league,
        cycleLabel: cycleLabel,
        roundNumber: i + 1,
        date: roundDate,
        pairings: pairings,
      );

      scheduledRounds.add(
        ScheduledRound(
          league: league,
          cycleLabel: cycleLabel,
          roundNumber: i + 1,
          date: roundDate,
          matches: slots,
        ),
      );
    }

    return scheduledRounds;
  }

  List<DateTime> _winterPlayDates(int seasonYear) {
    final start = DateTime(seasonYear - 1, 10, 15);
    final end = DateTime(seasonYear, 4, 15);

    final List<DateTime> dates = [];
    DateTime current = start;

    while (!current.isAfter(end)) {
      if (current.weekday == DateTime.saturday ||
          current.weekday == DateTime.sunday) {
        dates.add(DateTime(current.year, current.month, current.day));
      }
      current = current.add(const Duration(days: 1));
    }

    return dates;
  }

  List<List<_Pairing>> _buildRoundRobinRounds(List<Player> players) {
    final List<_RoundRobinEntry> entries = players
        .map(
          (p) => _RoundRobinEntry(
            id: p.id ?? '',
            name: p.name,
            isBye: false,
          ),
        )
        .toList();

    if (entries.length.isOdd) {
      entries.add(
        _RoundRobinEntry(
          id: '__BYE__',
          name: 'BYE',
          isBye: true,
        ),
      );
    }

    final int n = entries.length;
    final int totalRounds = n - 1;
    final int half = n ~/ 2;

    final List<_RoundRobinEntry> rotation = [...entries];
    final List<List<_Pairing>> rounds = [];

    for (int round = 0; round < totalRounds; round++) {
      final List<_Pairing> pairings = [];

      for (int i = 0; i < half; i++) {
        final a = rotation[i];
        final b = rotation[n - 1 - i];

        if (a.isBye || b.isBye) {
          continue;
        }

        if (round.isEven) {
          pairings.add(_Pairing(player1: a, player2: b));
        } else {
          pairings.add(_Pairing(player1: b, player2: a));
        }
      }

      rounds.add(pairings);

      final fixed = rotation.first;
      final rest = rotation.sublist(1);

      rest.insert(0, rest.removeLast());

      rotation
        ..clear()
        ..add(fixed)
        ..addAll(rest);
    }

    return rounds;
  }

  List<ScheduledMatchSlot> _assignRoundToSlots({
    required String league,
    required String cycleLabel,
    required int roundNumber,
    required DateTime date,
    required List<_Pairing> pairings,
  }) {
    final List<ScheduledMatchSlot> slots = [];

    int matchIndex = 0;

    for (int slotIndex = 0; slotIndex < _slotHours.length; slotIndex++) {
      for (int court = 1; court <= _courtsPerSlot; court++) {
        if (matchIndex >= pairings.length) {
          return slots;
        }

        final pairing = pairings[matchIndex];
        final startAt = DateTime(
          date.year,
          date.month,
          date.day,
          _slotHours[slotIndex],
          _slotMinutes[slotIndex],
        );

        slots.add(
          ScheduledMatchSlot(
            league: league,
            cycleLabel: cycleLabel,
            roundNumber: roundNumber,
            startAt: startAt,
            courtNumber: court,
            player1Id: pairing.player1.id,
            player2Id: pairing.player2.id,
            player1Name: pairing.player1.name,
            player2Name: pairing.player2.name,
          ),
        );

        matchIndex++;
      }
    }

    return slots;
  }
}

class _RoundRobinEntry {
  final String id;
  final String name;
  final bool isBye;

  _RoundRobinEntry({
    required this.id,
    required this.name,
    required this.isBye,
  });
}

class _Pairing {
  final _RoundRobinEntry player1;
  final _RoundRobinEntry player2;

  _Pairing({
    required this.player1,
    required this.player2,
  });
}