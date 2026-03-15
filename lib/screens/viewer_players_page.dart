import 'package:flutter/material.dart';
import '../models/player.dart';
import '../services/firestore_service.dart';
import 'player_details_page.dart';

class ViewerPlayersPage extends StatefulWidget {
  const ViewerPlayersPage({super.key});

  @override
  State<ViewerPlayersPage> createState() => _ViewerPlayersPageState();
}

class _ViewerPlayersPageState extends State<ViewerPlayersPage> {
  String selectedLeagueTab = 'all';

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

  String _normalizeLeague(String league) {
    final value = league.trim().toLowerCase();
    if (value == '1' || value == '1. liga') return '1';
    if (value == '2' || value == '2. liga') return '2';
    if (value == '3' || value == '3. liga') return '3';
    if (value == '4' || value == '4. liga') return '4';
    return league;
  }

  Widget _leagueTabButton({
    required String value,
    required String label,
    required IconData icon,
  }) {
    final isSelected = selectedLeagueTab == value;

    return GestureDetector(
      onTap: () {
        setState(() {
          selectedLeagueTab = value;
        });
      },
      child: Container(
        width: 88,
        height: 88,
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).colorScheme.primaryContainer : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outlineVariant,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
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

            final players = (snapshot.data ?? [])
              .where((p) => !p.archived)
              .toList();

            final filteredPlayers = selectedLeagueTab == 'all'
              ? players
              : players
                .where(
                  (p) =>
                    !p.frozen &&
                    _normalizeLeague(p.league) == selectedLeagueTab,
                )
                .toList();

          filteredPlayers.sort((a, b) => a.name.compareTo(b.name));

          if (players.isEmpty) {
            return const Center(
              child: Text('Nema igrača.'),
            );
          }

          return Column(
            children: [
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  _leagueTabButton(value: 'all', label: 'All', icon: Icons.groups),
                  _leagueTabButton(value: '1', label: '1. liga', icon: Icons.looks_one),
                  _leagueTabButton(value: '2', label: '2. liga', icon: Icons.looks_two),
                  _leagueTabButton(value: '3', label: '3. liga', icon: Icons.looks_3),
                  _leagueTabButton(value: '4', label: '4. liga', icon: Icons.looks_4),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: filteredPlayers.isEmpty
                    ? const Center(
                        child: Text('Nema igrača u odabranoj ligi.'),
                      )
                    : ListView.builder(
                        itemCount: filteredPlayers.length,
                        itemBuilder: (context, index) {
                          final player = filteredPlayers[index];

                          return Card(
                            child: ListTile(
                              leading: const CircleAvatar(
                                child: Icon(Icons.person),
                              ),
                              title: Text(player.name),
                              subtitle: Text(
                                '${_leagueLabel(player.league)} • Rating ${player.rating}${player.frozen ? ' • Zamrznut' : ''}',
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
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}