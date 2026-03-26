import 'package:flutter/material.dart';
import '../models/match_model.dart';
import '../services/firestore_service.dart';
import '../utils/league_utils.dart';

class UnresolvedMatchesRepairPage extends StatefulWidget {
  const UnresolvedMatchesRepairPage({super.key});

  @override
  State<UnresolvedMatchesRepairPage> createState() =>
      _UnresolvedMatchesRepairPageState();
}

class _UnresolvedMatchesRepairPageState
    extends State<UnresolvedMatchesRepairPage> {
  static const _leagues = ['1', '2', '3', '4'];

  final FirestoreService _firestoreService = FirestoreService();
  late Future<List<MatchModel>> _matchesFuture;

  @override
  void initState() {
    super.initState();
    _matchesFuture = _firestoreService.getMatchesWithEmptyLeague();
  }

  void _reload() {
    setState(() {
      _matchesFuture = _firestoreService.getMatchesWithEmptyLeague();
    });
  }

  Future<void> _assignLeague(MatchModel match) async {
    String? chosen;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Dodijeli ligu meču'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${match.player1Name} vs ${match.player2Name}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${match.playedAt.day}.${match.playedAt.month}.${match.playedAt.year}',
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: chosen,
                    decoration: const InputDecoration(
                      labelText: 'Liga',
                      border: OutlineInputBorder(),
                    ),
                    items: _leagues.map((l) {
                      return DropdownMenuItem<String>(
                        value: l,
                        child: Text(LeagueUtils.label(l)),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setDialogState(() {
                        chosen = value;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Odustani'),
                ),
                ElevatedButton(
                  onPressed: chosen == null
                      ? null
                      : () => Navigator.pop(context, true),
                  child: const Text('Spremi'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true || chosen == null || match.id == null) return;

    try {
      await _firestoreService.patchMatchLeague(match.id!, chosen!);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Liga dodijeljena: Liga $chosen')));
      _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Greška: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mečevi bez lige'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Osvježi',
            icon: const Icon(Icons.refresh),
            onPressed: _reload,
          ),
        ],
      ),
      body: FutureBuilder<List<MatchModel>>(
        future: _matchesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Greška: ${snapshot.error}'));
          }
          final items = snapshot.data ?? [];
          if (items.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 64,
                    color: Color(0xFF1A7F37),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Svi mečevi imaju dodijelju ligu!',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Text(
                  '${items.length} meč/a bez dodijeljene lige',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: Color(0xFF8B2121),
                  ),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(12),
                  separatorBuilder: (_, _) => const SizedBox(height: 6),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final match = items[index];
                    final dateStr =
                        '${match.playedAt.day}.${match.playedAt.month}.${match.playedAt.year}';
                    return Card(
                      margin: EdgeInsets.zero,
                      child: ListTile(
                        title: Text(
                          '${match.player1Name} vs ${match.player2Name}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          '$dateStr  •  ${match.season.isNotEmpty ? match.season : "Sezona nepoznata"}',
                          style: const TextStyle(fontSize: 12.5),
                        ),
                        trailing: TextButton.icon(
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          label: const Text('Dodijeli ligu'),
                          onPressed: () => _assignLeague(match),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
