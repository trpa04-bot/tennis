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

  /// All raw Firestore data, loaded once per page open (or manual refresh).
  Future<TableRawCache>? _cacheFuture;

  /// The currently displayed table rows, computed synchronously from the cache.
  List<LeagueTableRow>? _table;

  /// Reference to the loaded cache so league/season switches never refetch.
  TableRawCache? _cache;

  final List<String> seasons = const ['Winter 2026', 'Summer 2026'];

  bool get isSimpleSeason => selectedSeason == 'Winter 2026';

  @override
  void initState() {
    super.initState();
    _loadCache();
  }

  @override
  void dispose() {
    _leagueTabsController.dispose();
    _tableScrollController.dispose();
    _tableVerticalScrollController.dispose();
    super.dispose();
  }

  /// Fetch all Firestore data once. League/season switches after this are free.
  void _loadCache() {
    _cache = null;
    _table = null;
    _cacheFuture = firestoreService.fetchTableRawCache().timeout(
      const Duration(seconds: 30),
      onTimeout: () => throw TimeoutException('Dohvat podataka je istekao.'),
    );
  }

  /// Synchronously rebuilds the table from the cached data – no network calls.
  void _rebuildTable() {
    final cache = _cache;
    if (cache == null) return;
    _table = firestoreService.buildLeagueTableFromCache(
      cache: cache,
      league: selectedLeague,
      season: selectedSeason,
    );
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
          _rebuildTable();
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

  DataRow _buildRow(int position, LeagueTableRow row) {
    Color? rowColor;
    if (position == 1) rowColor = Colors.amber.withValues(alpha: 0.25);
    else if (position == 2) rowColor = Colors.grey.withValues(alpha: 0.25);
    else if (position == 3) rowColor = Colors.brown.withValues(alpha: 0.25);

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

  Widget _buildControls() {
    return Padding(
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
                    items: seasons
                        .map(
                          (s) => DropdownMenuItem<String>(
                            value: s,
                            child: Text(s),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        selectedSeason = value;
                        _rebuildTable();
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
    );
  }

  Widget _buildTableView(List<LeagueTableRow> table) {
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
          notificationPredicate: (n) => n.metrics.axis == Axis.horizontal,
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
                (i) => _buildRow(i + 1, table[i]),
              ),
            ),
          ),
        ),
      ),
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
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(_loadCache),
          ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 10),
          _buildControls(),
          const SizedBox(height: 10),
          Expanded(
            child: FutureBuilder<TableRawCache>(
              future: _cacheFuture,
              builder: (context, snapshot) {
                // Cache just finished loading – compute the table.
                if (snapshot.connectionState == ConnectionState.done &&
                    snapshot.hasData &&
                    _cache != snapshot.data) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      setState(() {
                        _cache = snapshot.data;
                        _rebuildTable();
                      });
                    }
                  });
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline,
                            size: 48, color: Colors.red),
                        const SizedBox(height: 8),
                        Text('Greška: ${snapshot.error}'),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: () => setState(_loadCache),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Pokušaj ponovno'),
                        ),
                      ],
                    ),
                  );
                }

                // Still loading the initial cache.
                if (_table == null) {
                  return const Center(child: CircularProgressIndicator());
                }

                return _buildTableView(_table!);
              },
            ),
          ),
        ],
      ),
    );
  }
}
