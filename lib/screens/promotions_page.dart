import 'package:flutter/material.dart';
import '../services/firestore_service.dart';

class PromotionsPage extends StatefulWidget {
  const PromotionsPage({super.key});

  @override
  State<PromotionsPage> createState() => _PromotionsPageState();
}

class _PromotionsPageState extends State<PromotionsPage> {
  final FirestoreService firestoreService = FirestoreService();

  String selectedSeason = 'Winter 2026';
  bool isApplying = false;
  late Future<_PromotionPreview> _previewFuture;

  final List<String> seasons = const ['Winter 2026', 'Summer 2026'];

  @override
  void initState() {
    super.initState();
    _previewFuture = _loadPreview();
  }

  Future<_PromotionPreview> _loadPreview() async {
    final league1 = await firestoreService.getLeagueTableOnce(
      league: '1',
      season: selectedSeason,
    );
    final league2 = await firestoreService.getLeagueTableOnce(
      league: '2',
      season: selectedSeason,
    );
    final league3 = await firestoreService.getLeagueTableOnce(
      league: '3',
      season: selectedSeason,
    );
    final league4 = await firestoreService.getLeagueTableOnce(
      league: '4',
      season: selectedSeason,
    );

    return _PromotionPreview(
      relegatedFrom1: league1.length > 4
          ? league1.sublist(league1.length - 4)
          : [],
      promotedFrom2: league2.length >= 4 ? league2.sublist(0, 4) : [],
      relegatedFrom2: league2.length > 4
          ? league2.sublist(league2.length - 4)
          : [],
      promotedFrom3: league3.length >= 4 ? league3.sublist(0, 4) : [],
      relegatedFrom3: league3.length > 4
          ? league3.sublist(league3.length - 4)
          : [],
      promotedFrom4: league4.length >= 4 ? league4.sublist(0, 4) : [],
    );
  }

  Future<void> _applyChanges() async {
    setState(() {
      isApplying = true;
    });

    try {
      await firestoreService.applyPromotionsAndRelegations(
        season: selectedSeason,
      );

      if (!mounted) return;

      setState(() {
        _previewFuture = _loadPreview();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Promocije i ispadanja su primijenjeni.')),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Greška: $e')));
    } finally {
      if (mounted) {
        setState(() {
          isApplying = false;
        });
      }
    }
  }

  Widget _sectionTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildPlayerList(
    String emptyText,
    List<LeagueTableRow> rows, {
    required String moveLabel,
  }) {
    if (rows.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(emptyText),
      );
    }

    return Column(
      children: rows
          .map(
            (row) => Card(
              margin: const EdgeInsets.symmetric(vertical: 6),
              child: ListTile(
                title: Text(row.playerName),
                subtitle: Text(
                  'Pts ${row.points} • Set +/- ${row.setDifference} • Gem +/- ${row.gameDifference}',
                ),
                trailing: Text(
                  moveLabel,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Apply Promotions / Relegations',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text(
              'Sustav predlaže standardnu promjenu nakon završenog ciklusa:',
            ),
            SizedBox(height: 8),
            Text('• Bottom 4 iz više lige padaju dolje'),
            Text('• Top 4 iz niže lige idu gore'),
            SizedBox(height: 8),
            Text(
              'Nakon primjene uvijek možeš ručno korigirati stanje u League Management tabu.',
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_PromotionPreview>(
      future: _previewFuture,
      builder: (context, snapshot) {
        return Scaffold(
          appBar: AppBar(title: const Text('Promotions'), centerTitle: true),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildInfoCard(),
              const SizedBox(height: 12),
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
                        _previewFuture = _loadPreview();
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (snapshot.connectionState == ConnectionState.waiting)
                const Padding(
                  padding: EdgeInsets.all(30),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (snapshot.hasError)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('Greška: ${snapshot.error}'),
                  ),
                )
              else ...[
                _sectionTitle('1.(ROLAND GARROS) → 2.(AUSTRALIAN OPEN)'),
                _buildPlayerList(
                  'Nema kandidata za ispadanje iz 1. lige.',
                  snapshot.data!.relegatedFrom1,
                  moveLabel: '↓ 2.(AUSTRALIAN OPEN)',
                ),
                const SizedBox(height: 16),
                _sectionTitle('2.(AUSTRALIAN OPEN) → 1.(ROLAND GARROS)'),
                _buildPlayerList(
                  'Nema kandidata za promociju iz 2. lige.',
                  snapshot.data!.promotedFrom2,
                  moveLabel: '↑ 1.(ROLAND GARROS)',
                ),
                const SizedBox(height: 16),
                _sectionTitle('2.(AUSTRALIAN OPEN) → 3.(WIMBLEDON)'),
                _buildPlayerList(
                  'Nema kandidata za ispadanje iz 2. lige.',
                  snapshot.data!.relegatedFrom2,
                  moveLabel: '↓ 3.(WIMBLEDON)',
                ),
                const SizedBox(height: 16),
                _sectionTitle('3.(WIMBLEDON) → 2.(AUSTRALIAN OPEN)'),
                _buildPlayerList(
                  'Nema kandidata za promociju iz 3. lige.',
                  snapshot.data!.promotedFrom3,
                  moveLabel: '↑ 2.(AUSTRALIAN OPEN)',
                ),
                const SizedBox(height: 16),
                _sectionTitle('3.(WIMBLEDON) → 4.(US OPEN)'),
                _buildPlayerList(
                  'Nema kandidata za ispadanje iz 3. lige.',
                  snapshot.data!.relegatedFrom3,
                  moveLabel: '↓ 4.(US OPEN)',
                ),
                const SizedBox(height: 16),
                _sectionTitle('4.(US OPEN) → 3.(WIMBLEDON)'),
                _buildPlayerList(
                  'Nema kandidata za promociju iz 4. lige.',
                  snapshot.data!.promotedFrom4,
                  moveLabel: '↑ 3.(WIMBLEDON)',
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: isApplying ? null : _applyChanges,
                  icon: isApplying
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.swap_vert),
                  label: Text(
                    isApplying
                        ? 'Applying...'
                        : 'Apply Promotions / Relegations',
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _PromotionPreview {
  final List<LeagueTableRow> relegatedFrom1;
  final List<LeagueTableRow> promotedFrom2;
  final List<LeagueTableRow> relegatedFrom2;
  final List<LeagueTableRow> promotedFrom3;
  final List<LeagueTableRow> relegatedFrom3;
  final List<LeagueTableRow> promotedFrom4;

  _PromotionPreview({
    required this.relegatedFrom1,
    required this.promotedFrom2,
    required this.relegatedFrom2,
    required this.promotedFrom3,
    required this.relegatedFrom3,
    required this.promotedFrom4,
  });
}
