import 'package:flutter/material.dart';
import '../models/player.dart';
import '../models/match_model.dart';
import '../services/firestore_service.dart';

class AddMatchPage extends StatefulWidget {
  const AddMatchPage({super.key});

  @override
  State<AddMatchPage> createState() => _AddMatchPageState();
}

class _AddMatchPageState extends State<AddMatchPage> {
    DateTime? selectedDate;
  final FirestoreService firestoreService = FirestoreService();

  String? player1Id;
  String? player2Id;

  Player? player1;
  Player? player2;

  int set1p1 = 0;
  int set1p2 = 0;

  int set2p1 = 0;
  int set2p2 = 0;

  int stb1 = 0;
  int stb2 = 0;

  String season = 'Winter 2026';

  final List<int> setNumbers = List.generate(8, (i) => i); // 0-7
  final List<int> stbNumbers = List.generate(31, (i) => i); // 0-30

  Widget scoreSelector({
    required String title,
    required int p1,
    required int p2,
    required List<int> values,
    required ValueChanged<int> onP1,
    required ValueChanged<int> onP2,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
                      // Polje za odabir datuma
                      Row(
                        children: [
                          const Text('Datum meča:', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(width: 10),
                          Text(selectedDate == null
                              ? 'Odaberi datum'
                              : '${selectedDate!.day}.${selectedDate!.month}.${selectedDate!.year}'),
                          IconButton(
                            icon: const Icon(Icons.calendar_today),
                            onPressed: () async {
                              final now = DateTime.now();
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: selectedDate ?? now,
                                firstDate: DateTime(now.year - 5),
                                lastDate: DateTime(now.year + 1),
                              );
                              if (picked != null) {
                                setState(() {
                                  selectedDate = picked;
                                });
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
        const SizedBox(height: 20),
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 10),
        const Text('Igrač 1'),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: values.map((v) {
            return ChoiceChip(
              label: Text('$v'),
              selected: p1 == v,
              onSelected: (_) {
                setState(() {
                  onP1(v);
                });
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        const Text('Igrač 2'),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: values.map((v) {
            return ChoiceChip(
              label: Text('$v'),
              selected: p2 == v,
              onSelected: (_) {
                setState(() {
                  onP2(v);
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  String _buildSet(int a, int b) => '$a:$b';

  String _determineWinnerId() {
    int p1Sets = 0;
    int p2Sets = 0;

    if (set1p1 > set1p2) {
      p1Sets++;
    } else if (set1p2 > set1p1) {
      p2Sets++;
    }

    if (set2p1 > set2p2) {
      p1Sets++;
    } else if (set2p2 > set2p1) {
      p2Sets++;
    }

    if (p1Sets == 1 && p2Sets == 1) {
      if (stb1 > stb2) {
        p1Sets++;
      } else if (stb2 > stb1) {
        p2Sets++;
      }
    }

    return p1Sets > p2Sets ? (player1Id ?? '') : (player2Id ?? '');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Match'),
        centerTitle: true,
      ),
      body: StreamBuilder<List<Player>>(
        stream: firestoreService.getPlayers(),
        builder: (context, snapshot) {
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

          final players = snapshot.data ?? [];

          final player2Options = players
              .where((p) => p.id != player1Id)
              .toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              DropdownButtonFormField<String>(
                initialValue: player1Id,
                decoration: const InputDecoration(
                  labelText: 'Player 1',
                  border: OutlineInputBorder(),
                ),
                items: players.map((p) {
                  return DropdownMenuItem<String>(
                    value: p.id,
                    child: Text(p.name),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    player1Id = value;
                    player1 = players.firstWhere((p) => p.id == value);

                    if (player2Id == player1Id) {
                      player2Id = null;
                      player2 = null;
                    }
                  });
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: player2Id,
                decoration: const InputDecoration(
                  labelText: 'Player 2',
                  border: OutlineInputBorder(),
                ),
                items: player2Options.map((p) {
                  return DropdownMenuItem<String>(
                    value: p.id,
                    child: Text(p.name),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    player2Id = value;
                    player2 = players.firstWhere((p) => p.id == value);
                  });
                },
              ),
              scoreSelector(
                title: 'Set 1',
                p1: set1p1,
                p2: set1p2,
                values: setNumbers,
                onP1: (v) => set1p1 = v,
                onP2: (v) => set1p2 = v,
              ),
              const SizedBox(height: 8),
              Text('Odabrano: ${_buildSet(set1p1, set1p2)}'),
              scoreSelector(
                title: 'Set 2',
                p1: set2p1,
                p2: set2p2,
                values: setNumbers,
                onP1: (v) => set2p1 = v,
                onP2: (v) => set2p2 = v,
              ),
              const SizedBox(height: 8),
              Text('Odabrano: ${_buildSet(set2p1, set2p2)}'),
              scoreSelector(
                title: 'Super Tie Break',
                p1: stb1,
                p2: stb2,
                values: stbNumbers,
                onP1: (v) => stb1 = v,
                onP2: (v) => stb2 = v,
              ),
              const SizedBox(height: 8),
              Text('Odabrano: ${_buildSet(stb1, stb2)}'),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: () async {
                  if (player1 == null || player2 == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Odaberi oba igrača'),
                      ),
                    );
                    return;
                  }

                  if (player1Id == player2Id) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Igrač ne može igrati sam protiv sebe'),
                      ),
                    );
                    return;
                  }

                  String superTieBreakValue = _buildSet(stb1, stb2);
                  // Ako je rezultat setova 2:0 ili 0:2, ne spremaj super tie break
                  int s1p1 = set1p1;
                  int s1p2 = set1p2;
                  int s2p1 = set2p1;
                  int s2p2 = set2p2;
                  int setsWonP1 = 0;
                  int setsWonP2 = 0;
                  if (s1p1 > s1p2) setsWonP1++;
                  if (s1p2 > s1p1) setsWonP2++;
                  if (s2p1 > s2p2) setsWonP1++;
                  if (s2p2 > s2p1) setsWonP2++;
                  if (setsWonP1 == 2 || setsWonP2 == 2) {
                    superTieBreakValue = "";
                  }
                  final match = MatchModel(
                    player1Id: player1!.id ?? '',
                    player2Id: player2!.id ?? '',
                    player1Name: player1!.name,
                    player2Name: player2!.name,
                    set1: _buildSet(set1p1, set1p2),
                    set2: _buildSet(set2p1, set2p2),
                    superTieBreak: superTieBreakValue,
                    season: season,
                    playedAt: selectedDate ?? DateTime.now(),
                    winnerId: _determineWinnerId(),
                  );

                  await firestoreService.addMatch(match);

                  if (!mounted) return;

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Meč je spremljen'),
                    ),
                  );

                  Navigator.pop(context);
                },
                child: const Text('SAVE MATCH'),
              ),
            ],
          );
        },
      ),
    );
  }
}