import 'dart:async';

import 'package:flutter/material.dart';
import '../services/firestore_service.dart';

class LeagueTablePage extends StatefulWidget {
  const LeagueTablePage({super.key});

  @override
  State<LeagueTablePage> createState() => _LeagueTablePageState();
}

class _LeagueTablePageState extends State<LeagueTablePage> {
  final FirestoreService firestoreService = FirestoreService();
  final ScrollController _leagueTabsController = ScrollController();
  final ScrollController _tableScrollController = ScrollController();
  final ScrollController _tableVerticalScrollController = ScrollController();

  String selectedLeague = '1';
  String selectedSeason = 'Winter 2026';
  Future<List<LeagueTableRow>>? _tableFuture;
  // Each reload gets a unique key so FutureBuilder fully discards the old state.
  Object _futureKey = Object();

  final List<String> seasons = const ['Winter 2026', 'Summer 2026'];

  bool get isSimpleSeason => selectedSeason == 'Winter 2026';

  @override
  void initState() {
    super.initState();
    _reloadTable();
  }

  void _reloadTable() {
    _futureKey = Object();
    _tableFuture = firestoreService
        .getLeagueTableOnce(league: selectedLeague, season: selectedSeason)
        .timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            throw TimeoutException('Učitavanje tablice je isteklo (>30s).');
          },
        );
  }

  @override
  void dispose() {
    _leagueTabsController.dispose();
    _tableScrollController.dispose();
    _tableVerticalScrollController.dispose();
    super.dispose();
  }

  String _leagueShortLabel(String league) {
    switch (league) {
      case '1':
        return 'Roland Garros';
      case '2':
        return 'Australian Open';
      case '3':
        return 'Wimbledon';
      case '4':
        return 'US Open';
      default:
        return league;
    }
  }

  Widget _leagueChip(String value) {
    final isSelected = selectedLeague == value;
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: () {
        if (isSelected) return;
        setState(() {
          selectedLeague = value;
          _reloadTable();
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? scheme.primaryContainer : scheme.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isSelected ? scheme.primary : scheme.outlineVariant,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Text(
          _leagueShortLabel(value),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isSelected ? scheme.onPrimaryContainer : null,
          ),
        ),
      ),
    );
  }

  DataRow _buildRow(
    int position,
    LeagueTableRow row, {
    required bool isSimpleSeason,
  }) {
    Color? rowColor;

    if (position == 1) {
      rowColor = Colors.amber.withValues(alpha: 0.25); // gold
    } else if (position == 2) {
      rowColor = Colors.grey.withValues(alpha: 0.25); // silver
    } else if (position == 3) {
      rowColor = Colors.brown.withValues(alpha: 0.25); // bronze
    }

    return DataRow(
      color: rowColor != null ? WidgetStatePropertyAll(rowColor) : null,
      cells: isSimpleSeason
          ? [
              DataCell(Text(position.toString())),
              DataCell(Text(row.playerName)),
              DataCell(Text(row.played.toString())),
              DataCell(Text(row.points.toString())),
            ]
          : [
              DataCell(Text(position.toString())),
              DataCell(Text(row.playerName)),
              DataCell(Text(row.played.toString())),
              DataCell(Text(row.wins.toString())),
              DataCell(Text(row.losses.toString())),
              DataCell(Text('${row.setsWon}:${row.setsLost}')),
              DataCell(Text(row.setDifference.toString())),
              DataCell(Text('${row.gamesWon}:${row.gamesLost}')),
              DataCell(Text(row.gameDifference.toString())),
              DataCell(Text(row.points.toString())),
            ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('League Table'),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () {
              setState(_reloadTable);
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
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
                              _reloadTable();
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 40,
                      child: SingleChildScrollView(
                        controller: _leagueTabsController,
                        primary: false,
                        scrollDirection: Axis.horizontal,
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _leagueChip('1'),
                              const SizedBox(width: 8),
                              _leagueChip('2'),
                              const SizedBox(width: 8),
                              _leagueChip('3'),
                              const SizedBox(width: 8),
                              _leagueChip('4'),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          Expanded(
            child: FutureBuilder<List<LeagueTableRow>>(
              key: ValueKey(_futureKey),
              future: _tableFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Greška: ${snapshot.error}'),
                        const SizedBox(height: 8),
                        FilledButton(
                          onPressed: () {
                            setState(_reloadTable);
                          },
                          child: const Text('Pokušaj ponovno'),
                        ),
                      ],
                    ),
                  );
                }

                final table = snapshot.data ?? [];

                if (table.isEmpty) {
                  return const Center(
                    child: Text('Nema podataka za odabranu ligu i sezonu.'),
                  );
                }

                return Scrollbar(
                  controller: _tableVerticalScrollController,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: _tableVerticalScrollController,
                    primary: false,
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Scrollbar(
                      controller: _tableScrollController,
                      thumbVisibility: true,
                      notificationPredicate: (notification) {
                        return notification.metrics.axis == Axis.horizontal;
                      },
                      child: SingleChildScrollView(
                        controller: _tableScrollController,
                        primary: false,
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columns: isSimpleSeason
                              ? const [
                                  DataColumn(label: Text('#')),
                                  DataColumn(label: Text('Ime')),
                                  DataColumn(label: Text('Odigrano')),
                                  DataColumn(label: Text('Bodovi')),
                                ]
                              : const [
                                  DataColumn(label: Text('#')),
                                  DataColumn(label: Text('Player')),
                                  DataColumn(label: Text('M')),
                                  DataColumn(label: Text('W')),
                                  DataColumn(label: Text('L')),
                                  DataColumn(label: Text('Sets')),
                                  DataColumn(label: Text('Set +/-')),
                                  DataColumn(label: Text('Games')),
                                  DataColumn(label: Text('Gem +/-')),
                                  DataColumn(label: Text('Pts')),
                                ],
                          rows: List.generate(
                            table.length,
                            (index) => _buildRow(
                              index + 1,
                              table[index],
                              isSimpleSeason: isSimpleSeason,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
