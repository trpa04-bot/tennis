import 'package:flutter/material.dart';
import '../models/player.dart';
import '../models/round_robin_models.dart';
import '../services/firestore_service.dart';
import '../services/round_robin_service.dart';

class SchedulePage extends StatefulWidget {
  const SchedulePage({super.key});

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  final FirestoreService firestoreService = FirestoreService();
  final RoundRobinService roundRobinService = RoundRobinService();

  String selectedLeague = '1';
  String selectedSeason = 'Winter 2026';

  final List<String> seasons = const [
    'Winter 2026',
    'Summer 2026',
  ];

  String _normalizeLeague(String league) {
    final value = league.trim().toLowerCase();

    if (value == '1' || value == '1.(ROLAND GARROS)') return '1';
    if (value == '2' || value == '2.(AUSTRALIAN OPEN)') return '2';
    if (value == '3' || value == '3.(WIMBLEDON)') return '3';
    if (value == '4' || value == '4.(US OPEN)') return '4';

    return league;
  }

  String _leagueLabel(String league) {
    switch (_normalizeLeague(league)) {
      case '1':
        return '1.(ROLAND GARROS)';
      case '2':
        return '2.(AUSTRALIAN OPEN)';
      case '3':
        return '3.(WIMBLEDON)';
      case '4':
        return '4.(US OPEN)';
      default:
        return league;
    }
  }

  int _seasonYearFromLabel(String season) {
    final parts = season.split(' ');
    if (parts.length == 2) {
      final year = int.tryParse(parts[1]);
      if (year != null) return year;
    }
    return 2026;
  }

  List<Player> _playersForLeague(List<Player> players) {
    return players
        .where((p) =>
            _normalizeLeague(p.league) == selectedLeague &&
            !p.archived &&
            !p.frozen)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.'
        '${date.year}.';
  }

  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  String _weekdayLabel(DateTime date) {
    switch (date.weekday) {
      case DateTime.monday:
        return 'Ponedjeljak';
      case DateTime.tuesday:
        return 'Utorak';
      case DateTime.wednesday:
        return 'Srijeda';
      case DateTime.thursday:
        return 'Četvrtak';
      case DateTime.friday:
        return 'Petak';
      case DateTime.saturday:
        return 'Subota';
      case DateTime.sunday:
        return 'Nedjelja';
      default:
        return '';
    }
  }

  Widget _buildHeaderCard(List<Player> players, List<ScheduledRound> rounds) {
    final totalMatches = rounds.fold<int>(
      0,
      (sum, round) => sum + round.matches.length,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Winter Round Robin Generator',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 10),
            Text('Liga: ${_leagueLabel(selectedLeague)}'),
            Text('Sezona: $selectedSeason'),
            Text('Broj igrača: ${players.length}'),
            Text('Broj kola: ${rounds.length}'),
            Text('Ukupno mečeva: $totalMatches'),
            const SizedBox(height: 10),
            const Text(
              'Logika: 2 kola po vikendu — jedno kolo subotom, jedno nedjeljom. '
              'Svaki termin ima 3 terena, pa se mečevi automatski raspoređuju po satima i terenima.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPromotionCard(List<Player> players, List<ScheduledRound> rounds) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Promocija / ispadanje – prijedlog pravila',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            const Text(
              '1. Završava se prvi puni krug kad svatko odigra sa svakim jednom.',
            ),
            const SizedBox(height: 6),
            const Text(
              '2. Zaključava se tablica po pravilima: bodovi → međusobni omjer → set razlika → gem razlika.',
            ),
            const SizedBox(height: 6),
            const Text(
              '3. U ligama 1–3 zadnja 4 igrača padaju dolje, a top 4 iz niže lige idu gore.',
            ),
            const SizedBox(height: 6),
            const Text(
              '4. U 4. ligi nema ispadanja, samo promocija top 4.',
            ),
            const SizedBox(height: 6),
            const Text(
              '5. Nakon promjena kreće novi round robin ciklus s novim sastavom liga.',
            ),
            const SizedBox(height: 12),
            Text(
              'Za ovu ligu trenutno generator priprema: ${rounds.length} kola za ${players.length} igrača.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoundCard(ScheduledRound round) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Kolo ${round.roundNumber} • ${_weekdayLabel(round.date)} ${_formatDate(round.date)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 12),
            ...round.matches.map(
              (match) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    SizedBox(
                      width: 58,
                      child: Text(
                        _formatTime(match.startAt),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 70,
                      child: Text('Teren ${match.courtNumber}'),
                    ),
                    Expanded(
                      child: Text(
                        '${match.player1Name} vs ${match.player2Name}',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Player>>(
      stream: firestoreService.getPlayers(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Schedule'),
            ),
            body: Center(
              child: Text('Greška: ${snapshot.error}'),
            ),
          );
        }

        final allPlayers = snapshot.data ?? [];
        final leaguePlayers = _playersForLeague(allPlayers);

        final rounds = selectedSeason.startsWith('Winter')
            ? roundRobinService.generateWinterSchedule(
                players: leaguePlayers,
                league: selectedLeague,
                seasonYear: _seasonYearFromLabel(selectedSeason),
                cycleLabel: 'Cycle 1',
              )
            : <ScheduledRound>[];

        return Scaffold(
          appBar: AppBar(
            title: const Text('Schedule'),
            centerTitle: true,
          ),
          body: Column(
            children: [
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Season: '),
                  const SizedBox(width: 10),
                  DropdownButton<String>(
                    value: selectedSeason,
                    items: seasons.map((season) {
                      return DropdownMenuItem<String>(
                        value: season,
                        child: Text(season),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        selectedSeason = value;
                      });
                    },
                  ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('League: '),
                  const SizedBox(width: 10),
                  DropdownButton<String>(
                    value: selectedLeague,
                    items: const [
                      DropdownMenuItem(value: '1', child: Text('1.(ROLAND GARROS)')),
                      DropdownMenuItem(value: '2', child: Text('2.(AUSTRALIAN OPEN)')),
                      DropdownMenuItem(value: '3', child: Text('3.(WIMBLEDON)')),
                      DropdownMenuItem(value: '4', child: Text('4.(US OPEN)')),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        selectedLeague = value;
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: leaguePlayers.length < 2
                    ? const Center(
                        child: Text(
                          'Nema dovoljno igrača u odabranoj ligi.',
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          _buildHeaderCard(leaguePlayers, rounds),
                          const SizedBox(height: 16),
                          _buildPromotionCard(leaguePlayers, rounds),
                          const SizedBox(height: 16),
                          if (selectedSeason.startsWith('Summer'))
                            const Card(
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: Text(
                                  'Summer generator još nije definiran. '
                                  'Za sada je potpuno složen Winter raspored 15.10 – 15.04.',
                                ),
                              ),
                            )
                          else if (rounds.isEmpty)
                            const Card(
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: Text('Nema generiranog rasporeda.'),
                              ),
                            )
                          else
                            ...rounds.map(_buildRoundCard),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}