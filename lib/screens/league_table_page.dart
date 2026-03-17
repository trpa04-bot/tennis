import 'package:flutter/material.dart';
import '../services/firestore_service.dart';

class LeagueTablePage extends StatefulWidget {
  final bool canResetTrend;

  const LeagueTablePage({
    super.key,
    this.canResetTrend = true,
  });

  @override
  State<LeagueTablePage> createState() => _LeagueTablePageState();
}

class _LeagueTablePageState extends State<LeagueTablePage> {
  final FirestoreService firestoreService = FirestoreService();
  static const double _tableRowHeight = 56;
  static const double _tableHeadingHeight = 56;

  String selectedLeague = '1';
  String selectedSeason = 'Winter 2026';

  final List<String> seasons = const [
    'Winter 2026',
    'Summer 2026',
  ];

  DataRow _buildRow(int position, LeagueTableRow row) {
    Color? rowColor;

    if (position == 1) {
      rowColor = Colors.amber.withValues(alpha: 0.25); // 🥇 gold
    } else if (position == 2) {
      rowColor = Colors.grey.withValues(alpha: 0.25); // 🥈 silver
    } else if (position == 3) {
      rowColor = Colors.brown.withValues(alpha: 0.25); // 🥉 bronze
    }

    return DataRow(
      color: rowColor != null
          ? WidgetStatePropertyAll(rowColor)
          : null,
      cells: [
        DataCell(Text(position.toString())),
        DataCell(_movementCell(row.movement)),
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

  Widget _movementCell(int movement) {
    if (movement > 0) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.arrow_drop_up, color: Colors.blue, size: 28),
          Text('+$movement', style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
        ],
      );
    }

    if (movement < 0) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.arrow_drop_down, color: Colors.red, size: 28),
          Text('$movement', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        ],
      );
    }

    return const Text('-', style: TextStyle(color: Colors.grey));
  }

  Future<void> _confirmResetTrend(BuildContext ctx) async {
    final confirmed = await showDialog<bool>(
      context: ctx,
      builder: (dCtx) => AlertDialog(
        title: const Text('Reset trend'),
        content: const Text(
          'Ovo će resetirati trend strelice za sve igrače. Od sada će se trend računati od trenutnih pozicija. Nastavi?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx, false),
            child: const Text('Odustani'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dCtx, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await firestoreService.resetTrend();
    if (!ctx.mounted) return;
    ScaffoldMessenger.of(ctx).showSnackBar(
      const SnackBar(content: Text('Trend je resetiran!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<LeagueTableRow>>(
      stream: firestoreService.getLeagueTable(
        league: selectedLeague,
        season: selectedSeason,
      ),
      builder: (context, snapshot) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('League Table'),
            centerTitle: true,
            actions: widget.canResetTrend
                ? [
                    IconButton(
                      tooltip: 'Reset trend',
                      icon: const Icon(Icons.restart_alt),
                      onPressed: () => _confirmResetTrend(context),
                    ),
                  ]
                : null,
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
                child: () {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text('Greška: ${snapshot.error}'),
                    );
                  }

                  final table = snapshot.data ?? [];

                  if (table.isEmpty) {
                    return const Center(
                      child: Text('Nema podataka za odabranu ligu i sezonu.'),
                    );
                  }

                  final cutLineY = _tableHeadingHeight + (_tableRowHeight * 10);

                  return Scrollbar(
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Stack(
                          children: [
                            DataTable(
                              headingRowHeight: _tableHeadingHeight,
                              dataRowMinHeight: _tableRowHeight,
                              dataRowMaxHeight: _tableRowHeight,
                              columns: const [
                                DataColumn(label: Text('#')),
                                DataColumn(label: Text('Trend')),
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
                                (index) => _buildRow(index + 1, table[index]),
                              ),
                            ),
                            if (table.length > 10)
                              Positioned(
                                top: cutLineY,
                                left: 0,
                                right: 0,
                                child: Container(
                                  height: 2,
                                  color: Colors.red,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                }(),
              ),
            ],
          ),
        );
      },
    );
  }
}