import 'package:flutter/material.dart';
import '../utils/league_utils.dart';
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
  final ScrollController _leagueTabsController = ScrollController();

  @override
  void dispose() {
    _leagueTabsController.dispose();
    super.dispose();
  }

  String _leagueLabel(String league) => LeagueUtils.label(league);

  String _normalizeLeague(String league) => LeagueUtils.normalize(league);

  Widget _leagueTabChip({
    required String value,
    required String label,
    required IconData icon,
    required int count,
  }) {
    final isSelected = selectedLeagueTab == value;
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: () {
        setState(() {
          selectedLeagueTab = value;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? scheme.primaryContainer : scheme.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isSelected ? scheme.primary : scheme.outlineVariant,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isSelected
                    ? scheme.primary.withValues(alpha: 0.16)
                    : scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
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
      appBar: AppBar(title: const Text('Players'), centerTitle: true),
      body: StreamBuilder<List<Player>>(
        stream: firestoreService.getPlayers(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Greška: ${snapshot.error}'));
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

          final allCount = players.length;
          final league1Count = players
              .where((p) => !p.frozen && _normalizeLeague(p.league) == '1')
              .length;
          final league2Count = players
              .where((p) => !p.frozen && _normalizeLeague(p.league) == '2')
              .length;
          final league3Count = players
              .where((p) => !p.frozen && _normalizeLeague(p.league) == '3')
              .length;
          final league4Count = players
              .where((p) => !p.frozen && _normalizeLeague(p.league) == '4')
              .length;

          filteredPlayers.sort((a, b) => a.name.compareTo(b.name));

          if (players.isEmpty) {
            return const Center(child: Text('Nema igrača.'));
          }

          return Column(
            children: [
              const SizedBox(height: 12),
              SizedBox(
                height: 48,
                child: ListView(
                  controller: _leagueTabsController,
                  primary: false,
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    _leagueTabChip(
                      value: 'all',
                      label: 'Svi',
                      icon: Icons.groups,
                      count: allCount,
                    ),
                    const SizedBox(width: 8),
                    _leagueTabChip(
                      value: '1',
                      label: 'Roland Garros',
                      icon: Icons.looks_one,
                      count: league1Count,
                    ),
                    const SizedBox(width: 8),
                    _leagueTabChip(
                      value: '2',
                      label: 'Australian Open',
                      icon: Icons.looks_two,
                      count: league2Count,
                    ),
                    const SizedBox(width: 8),
                    _leagueTabChip(
                      value: '3',
                      label: 'Wimbledon',
                      icon: Icons.looks_3,
                      count: league3Count,
                    ),
                    const SizedBox(width: 8),
                    _leagueTabChip(
                      value: '4',
                      label: 'US Open',
                      icon: Icons.looks_4,
                      count: league4Count,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: filteredPlayers.isEmpty
                    ? const Center(child: Text('Nema igrača u odabranoj ligi.'))
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
                              trailing: const Icon(
                                Icons.arrow_forward_ios,
                                size: 16,
                              ),
                              onTap: () {
                                if (player.id == null || player.id!.isEmpty) {
                                  return;
                                }

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
