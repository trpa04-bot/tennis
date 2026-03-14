import 'package:flutter/material.dart';

import '../models/player.dart';
import '../services/firestore_service.dart';
import 'player_details_page.dart';

class PlayersPage extends StatefulWidget {
  const PlayersPage({super.key});

  @override
  State<PlayersPage> createState() => _PlayersPageState();
}

class _PlayersPageState extends State<PlayersPage> {
    void _editPlayerDialog(Player player) {
      final nameController = TextEditingController(text: player.name);
      final ratingController = TextEditingController(text: player.rating.toString());
      String selectedLeague = player.league;

      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Uredi igrača'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Ime'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: ratingController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Rating'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedLeague,
                    decoration: const InputDecoration(labelText: 'Liga'),
                    items: const [
                      DropdownMenuItem(value: '1', child: Text('1. liga')),
                      DropdownMenuItem(value: '2', child: Text('2. liga')),
                      DropdownMenuItem(value: '3', child: Text('3. liga')),
                      DropdownMenuItem(value: '4', child: Text('4. liga')),
                    ],
                    onChanged: (value) {
                      selectedLeague = value ?? '1';
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Odustani'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final name = nameController.text.trim();
                  final rating = int.tryParse(ratingController.text.trim()) ?? 0;
                  if (name.isEmpty) return;
                  final updatedPlayer = Player(
                    id: player.id,
                    name: name,
                    rating: rating,
                    league: selectedLeague,
                  );
                  await firestoreService.updatePlayer(updatedPlayer);
                  if (context.mounted) Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Igrač ažuriran')),
                  );
                },
                child: const Text('Spremi'),
              ),
            ],
          );
        },
      );
    }
  final FirestoreService firestoreService = FirestoreService();

  void _openAddPlayerDialog() {
    final nameController = TextEditingController();
    final ratingController = TextEditingController();
    String selectedLeague = '1';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Player'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: ratingController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Rating'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedLeague,
                  decoration: const InputDecoration(labelText: 'League'),
                  items: const [
                    DropdownMenuItem(value: '1', child: Text('1. liga')),
                    DropdownMenuItem(value: '2', child: Text('2. liga')),
                    DropdownMenuItem(value: '3', child: Text('3. liga')),
                    DropdownMenuItem(value: '4', child: Text('4. liga')),
                  ],
                  onChanged: (value) {
                    selectedLeague = value ?? '1';
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                final rating = int.tryParse(ratingController.text.trim()) ?? 0;

                if (name.isEmpty) return;

                final player = Player(
                  name: name,
                  rating: rating,
                  league: selectedLeague,
                );

                await firestoreService.addPlayer(player);

                if (context.mounted) {
                  Navigator.pop(context);
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _confirmDelete(Player player) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Player'),
          content: Text('Delete ${player.name}?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (player.id != null && player.id!.isNotEmpty) {
                  await firestoreService.deletePlayer(player.id!);
                }

                if (context.mounted) {
                  Navigator.pop(context);
                }
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  void _openPlayerDetails(Player player) {
    if (player.id == null || player.id!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Igrač nema ispravan ID.'),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlayerDetailsPage(
          playerId: player.id!,
          playerName: player.name,
        ),
      ),
    );
  }

  String _leagueLabel(String league) {
    switch (league) {
      case '1':
        return '1. liga';
      case '2':
        return '2. liga';
      case '3':
        return '3. liga';
      case '4':
        return '4. liga';
      default:
        return league;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Players'),
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

          if (players.isEmpty) {
            return const Center(
              child: Text('Nema igrača. Dodaj prvog igrača.'),
            );
          }

          return ListView.builder(
            itemCount: players.length,
            itemBuilder: (context, index) {
              final player = players[index];

              return Card(
                margin: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.person),
                  ),
                  title: Text(player.name),
                  subtitle: Text(
                    '${_leagueLabel(player.league)} • Rating ${player.rating}',
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') {
                        _editPlayerDialog(player);
                      } else if (value == 'delete') {
                        _confirmDelete(player);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Text('Uredi'),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Obriši'),
                      ),
                    ],
                  ),
                  isThreeLine: true,
                  onTap: () => _openPlayerDetails(player),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddPlayerDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}