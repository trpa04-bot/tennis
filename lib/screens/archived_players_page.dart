import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'player_details_page.dart';
import '../services/firestore_service.dart';

class ArchivedPlayersPage extends StatelessWidget {
  const ArchivedPlayersPage({super.key});

  static final FirestoreService _firestoreService = FirestoreService();

  String _leagueLabel(String league) {
    switch (league) {
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

  String _formatStatusDate(dynamic rawDate) {
    if (rawDate is Timestamp) {
      final date = rawDate.toDate();
      return '${date.day.toString().padLeft(2, '0')}.'
          '${date.month.toString().padLeft(2, '0')}.'
          '${date.year}';
    }
    return '-';
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Status igrača'),
          centerTitle: true,
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.archive_outlined), text: 'Arhiva'),
              Tab(icon: Icon(Icons.ac_unit_outlined), text: 'Zamrznuti'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('player_archive')
                  .orderBy('archivedAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text('Greška: ${snapshot.error}'),
                  );
                }

                final docs = snapshot.data?.docs ?? [];

                if (docs.isEmpty) {
                  return const Center(
                    child: Text('Arhiva je prazna.'),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = Map<String, dynamic>.from(
                      docs[index].data() as Map,
                    );

                    final name = data['name']?.toString() ?? 'Nepoznato';
                    final league = data['league']?.toString() ?? '';
                    final rating = int.tryParse(data['rating']?.toString() ?? '0') ?? 0;
                    final archivedAt = data['archivedAt'];
                    final stats = Map<String, dynamic>.from(
                      data['stats'] as Map? ?? <String, dynamic>{},
                    );

                    final played = int.tryParse(stats['played']?.toString() ?? '0') ?? 0;
                    final wins = int.tryParse(stats['wins']?.toString() ?? '0') ?? 0;
                    final losses = int.tryParse(stats['losses']?.toString() ?? '0') ?? 0;

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.archive_outlined),
                        ),
                        title: Text(name),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${_leagueLabel(league)} • Rating $rating'),
                            Text('Statistika: ${wins}W ${losses}L • $played mečeva'),
                            Text('Arhivirano: ${_formatStatusDate(archivedAt)}'),
                          ],
                        ),
                        isThreeLine: true,
                      ),
                    );
                  },
                );
              },
            ),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('players').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text('Greška: ${snapshot.error}'),
                  );
                }

                final docs = (snapshot.data?.docs ?? []).where((doc) {
                  final data = Map<String, dynamic>.from(doc.data() as Map);
                  final frozen = data['frozen'] == true;
                  final archived = data['archived'] == true;
                  return frozen && !archived;
                }).toList();

                if (docs.isEmpty) {
                  return const Center(
                    child: Text('Nema zamrznutih igrača.'),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = Map<String, dynamic>.from(docs[index].data() as Map);
                    final name = data['name']?.toString() ?? 'Nepoznato';
                    final league = data['league']?.toString() ?? '';
                    final rating = int.tryParse(data['rating']?.toString() ?? '0') ?? 0;
                    final frozenAt = data['frozenAt'];

                    final docId = docs[index].id;

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 12, 4, 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const CircleAvatar(
                                  child: Icon(Icons.ac_unit_outlined),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium,
                                      ),
                                      Text(
                                        '${_leagueLabel(league)} • Rating $rating',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                      ),
                                      Text(
                                        'Zamrznut: ${_formatStatusDate(frozenAt)}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton.icon(
                                  icon: const Icon(Icons.person_outline,
                                      size: 18),
                                  label: const Text('Profil'),
                                  onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => PlayerDetailsPage(
                                        playerId: docId,
                                        playerName: name,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                TextButton.icon(
                                  icon: const Icon(Icons.lock_open_outlined,
                                      size: 18),
                                  label: const Text('Odmrzni'),
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (_) => AlertDialog(
                                        title: const Text('Odmrzni igrača'),
                                        content: Text(
                                          'Jesi li siguran da želiš odmrznuti $name?',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, false),
                                            child: const Text('Odustani'),
                                          ),
                                          ElevatedButton(
                                            onPressed: () =>
                                                Navigator.pop(context, true),
                                            child: const Text('Odmrzni'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirm == true) {
                                      await _firestoreService
                                          .unfreezePlayer(docId);
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              '$name je odmrznut.',
                                            ),
                                          ),
                                        );
                                      }
                                    }
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
