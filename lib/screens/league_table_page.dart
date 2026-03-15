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

                  return SingleChildScrollView(
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
                        (index) => _buildRow(index + 1, table[index]),
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