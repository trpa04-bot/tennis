import 'package:flutter/material.dart';
import '../models/player.dart';
import '../services/firestore_service.dart';
import 'player_details_page.dart';

class ViewerPlayersPage extends StatelessWidget {
  const ViewerPlayersPage({super.key});

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
    final firestoreService = FirestoreService();

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

          final players = snapshot.data ?? []
            ..sort((a, b) => a.name.compareTo(b.name));

          if (players.isEmpty) {
            return const Center(
              child: Text('Nema igrača.'),
            );
          }

          return ListView.builder(
            itemCount: players.length,
            itemBuilder: (context, index) {
              final player = players[index];

              return Card(
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.person),
                  ),
                  title: Text(player.name),
                  subtitle: Text(
                    '${_leagueLabel(player.league)} • Rating ${player.rating}',
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    if (player.id == null || player.id!.isEmpty) return;

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PlayerDetailsPage(
                          playerId: player.id!,
                          playerName: player.name,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}