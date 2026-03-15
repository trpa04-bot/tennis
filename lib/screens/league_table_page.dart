import 'package:flutter/material.dart';
import '../services/firestore_service.dart';

class LeagueTablePage extends StatefulWidget {
  const LeagueTablePage({super.key});

  @override
  State<LeagueTablePage> createState() => _LeagueTablePageState();
}

class _LeagueTablePageState extends State<LeagueTablePage> {
  final FirestoreService firestoreService = FirestoreService();

  String selectedLeague = '1';
  String selectedSeason = 'Winter 2026';

  final List<String> seasons = const [
    'Winter 2026',
    'Summer 2026',
  ];

  DataCell _buildCell(String text, {bool showTopDivider = false}) {
    return DataCell(
      Container(
        decoration: showTopDivider
            ? const BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.red, width: 2),
                ),
              )
            : null,
        padding: const EdgeInsets.only(top: 4),
        child: Text(text),
      ),
    );
  }

  DataRow _buildRow(
    int position,
    LeagueTableRow row, {
    bool showTopDivider = false,
  }) {
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
        _buildCell(position.toString(), showTopDivider: showTopDivider),
        _buildCell(row.playerName, showTopDivider: showTopDivider),
        _buildCell(row.played.toString(), showTopDivider: showTopDivider),
        _buildCell(row.wins.toString(), showTopDivider: showTopDivider),
        _buildCell(row.losses.toString(), showTopDivider: showTopDivider),
        _buildCell('${row.setsWon}:${row.setsLost}', showTopDivider: showTopDivider),
        _buildCell(row.setDifference.toString(), showTopDivider: showTopDivider),
        _buildCell('${row.gamesWon}:${row.gamesLost}', showTopDivider: showTopDivider),
        _buildCell(row.gameDifference.toString(), showTopDivider: showTopDivider),
        _buildCell(row.points.toString(), showTopDivider: showTopDivider),
      ],
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
                      DropdownMenuItem(value: '1', child: Text('1. liga')),
                      DropdownMenuItem(value: '2', child: Text('2. liga')),
                      DropdownMenuItem(value: '3', child: Text('3. liga')),
                      DropdownMenuItem(value: '4', child: Text('4. liga')),
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

                  return Scrollbar(
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columns: const [
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
                        (index) {
                          final position = index + 1;
                          final showCutLine = table.length > 10 && position == 11;
                          return _buildRow(
                            position,
                            table[index],
                            showTopDivider: showCutLine,
                          );
                        },
                          ),
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