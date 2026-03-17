import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/player.dart';
import '../services/firestore_service.dart';
import 'archived_players_page.dart';
import 'player_details_page.dart';

class PlayersPage extends StatefulWidget {
  const PlayersPage({super.key});

  @override
  State<PlayersPage> createState() => _PlayersPageState();
}

class _PlayersPageState extends State<PlayersPage> {
  String selectedLeagueTab = 'all';

  final FirestoreService firestoreService = FirestoreService();

  int _defaultRatingForLeague(String league) {
    switch (_normalizeLeague(league)) {
      case '1':
        return 1500;
      case '2':
        return 1000;
      case '3':
        return 500;
      case '4':
        return 0;
      default:
        return 0;
    }
  }

  void _editPlayerDialog(Player player) {
    _openPlayerDialog(player: player);
  }

  void _openAddPlayerDialog() {
    _openPlayerDialog();
  }

  void _openPlayerDialog({Player? player}) {
    final isEditing = player != null;
    final pageContext = context;
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: player?.name ?? '');
    final ratingController = TextEditingController(
      text: isEditing ? player.rating.toString() : '',
    );
    String selectedLeague = player?.league ?? '1';
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> handleSubmit() async {
              if (isSaving) return;
              if (!(formKey.currentState?.validate() ?? false)) return;

              final name = nameController.text.trim();
              final parsedRating = int.tryParse(ratingController.text.trim()) ?? 0;
              final appliedRating = isEditing
                  ? parsedRating
                  : (parsedRating > 0
                      ? parsedRating
                      : _defaultRatingForLeague(selectedLeague));

              setDialogState(() {
                isSaving = true;
              });

              try {
                if (isEditing) {
                  final updated = await firestoreService.updatePlayer(
                    Player(
                      id: player.id,
                      name: name,
                      rating: appliedRating,
                      league: selectedLeague,
                      frozen: player.frozen,
                      archived: player.archived,
                      achievements: player.achievements,
                    ),
                  );

                  if (!pageContext.mounted) return;

                  if (!updated) {
                    ScaffoldMessenger.of(pageContext).showSnackBar(
                      const SnackBar(
                        content: Text('Promjene nisu spremljene. Pokušaj ponovno.'),
                      ),
                    );
                    return;
                  }
                } else {
                  await firestoreService.addPlayer(
                    Player(
                      name: name,
                      rating: appliedRating,
                      league: selectedLeague,
                    ),
                  );
                }

                if (!pageContext.mounted) return;

                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(pageContext).showSnackBar(
                  SnackBar(
                    content: Text(
                      isEditing
                          ? 'Igrač ažuriran. Novi rating: $appliedRating'
                          : 'Igrač dodan. Početni rating: $appliedRating',
                    ),
                  ),
                );
              } catch (_) {
                if (!pageContext.mounted) return;

                ScaffoldMessenger.of(pageContext).showSnackBar(
                  SnackBar(
                    content: Text(
                      isEditing
                          ? 'Greška pri spremanju igrača.'
                          : 'Greška pri dodavanju igrača.',
                    ),
                  ),
                );
              } finally {
                if (dialogContext.mounted) {
                  setDialogState(() {
                    isSaving = false;
                  });
                }
              }
            }

            return AlertDialog(
              title: Text(isEditing ? 'Uredi igrača' : 'Dodaj igrača'),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameController,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Ime',
                          hintText: 'Upiši ime igrača',
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Ime je obavezno.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: ratingController,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.done,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: InputDecoration(
                          labelText: 'Rating',
                          hintText: isEditing ? 'Unesi rating' : 'Ostavi prazno za zadani rating lige',
                        ),
                        validator: (value) {
                          final trimmed = value?.trim() ?? '';
                          if (isEditing && trimmed.isEmpty) {
                            return 'Rating je obavezan.';
                          }
                          if (trimmed.isNotEmpty && int.tryParse(trimmed) == null) {
                            return 'Rating mora biti broj.';
                          }
                          return null;
                        },
                        onFieldSubmitted: (_) => handleSubmit(),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: selectedLeague,
                        decoration: const InputDecoration(labelText: 'Liga'),
                        items: const [
                          DropdownMenuItem(value: '1', child: Text('1.(ROLAND GARROS)')),
                          DropdownMenuItem(value: '2', child: Text('2.(AUSTRALIAN OPEN)')),
                          DropdownMenuItem(value: '3', child: Text('3.(WIMBLEDON)')),
                          DropdownMenuItem(value: '4', child: Text('4.(US OPEN)')),
                        ],
                        onChanged: isSaving
                            ? null
                            : (value) {
                                setDialogState(() {
                                  selectedLeague = value ?? '1';
                                });
                              },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Odustani'),
                ),
                ElevatedButton(
                  onPressed: isSaving ? null : handleSubmit,
                  child: Text(isSaving ? 'Spremanje...' : 'Spremi'),
                ),
              ],
            );
          },
        );
      },
    ).whenComplete(() {
      nameController.dispose();
      ratingController.dispose();
    });
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

  Future<void> _freezePlayer(Player player) async {
    if (player.id == null || player.id!.isEmpty) return;

    await firestoreService.freezePlayer(player.id!);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${player.name} je zamrznut.')),
    );
  }

  Future<void> _unfreezePlayer(Player player) async {
    if (player.id == null || player.id!.isEmpty) return;

    await firestoreService.unfreezePlayer(player.id!);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${player.name} je odmrznut.')),
    );
  }

  Future<void> _archivePlayer(Player player) async {
    if (player.id == null || player.id!.isEmpty) return;

    await firestoreService.archivePlayer(player.id!);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${player.name} je arhiviran.')),
    );
  }

  Future<void> _rebuildActivityFeed() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rebuild Activity Feed'),
        content: const Text(
          'Ovo će izbrisati cijeli activity feed i ponovo ga izgraditi iz svih postojećih mečeva. Nastavi?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Odustani'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Rebuild'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text('Gradim feed...'),
          ],
        ),
      ),
    );

    await firestoreService.rebuildActivityFeed();

    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Activity feed je obnovljen!')),
    );
  }

  Future<void> _recalculateAchievements() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Retroaktivni achievementi'),
        content: const Text(
          'Ovo će izračunati achievemente za sve igrače na temelju dosadašnjih mečeva. Nastavi?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Odustani'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Izračunaj'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text('Računam achievemente...'),
          ],
        ),
      ),
    );

    await firestoreService.recalculateAllAchievements();

    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Achievementi su izračunati za sve igrače!')),
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

  String _normalizeLeague(String league) {
    final value = league.trim().toLowerCase();
    if (value == '1' || value == '1.(ROLAND GARROS)') return '1';
    if (value == '2' || value == '2.(AUSTRALIAN OPEN)') return '2';
    if (value == '3' || value == '3.(WIMBLEDON)') return '3';
    if (value == '4' || value == '4.(US OPEN)') return '4';
    return league;
  }

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
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Players'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Rebuild Activity Feed',
            icon: const Icon(Icons.history_outlined),
            onPressed: () => _rebuildActivityFeed(),
          ),
          IconButton(
            tooltip: 'Retroaktivni achievementi',
            icon: const Icon(Icons.workspace_premium_outlined),
            onPressed: () => _recalculateAchievements(),
          ),
          IconButton(
            tooltip: 'Arhiva igrača',
            icon: const Icon(Icons.archive_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ArchivedPlayersPage(),
                ),
              );
            },
          ),
        ],
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
            return const Center(
              child: Text('Nema igrača. Dodaj prvog igrača.'),
            );
          }

          return Column(
            children: [
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ArchivedPlayersPage(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.archive_outlined),
                    label: const Text('Arhiva igrača'),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 48,
                child: ListView(
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
                    ? const Center(
                        child: Text('Nema igrača u odabranoj ligi.'),
                      )
                    : ListView.builder(
                        itemCount: filteredPlayers.length,
                        itemBuilder: (context, index) {
                          final player = filteredPlayers[index];

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
                                '${_leagueLabel(player.league)} • Rating ${player.rating}${player.frozen ? ' • Zamrznut' : ''}',
                              ),
                              trailing: PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (value == 'edit') {
                                    _editPlayerDialog(player);
                                  } else if (value == 'delete') {
                                    _confirmDelete(player);
                                  } else if (value == 'freeze') {
                                    _freezePlayer(player);
                                  } else if (value == 'unfreeze') {
                                    _unfreezePlayer(player);
                                  } else if (value == 'archive') {
                                    _archivePlayer(player);
                                  }
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Text('Uredi'),
                                  ),
                                  PopupMenuItem(
                                    value: player.frozen ? 'unfreeze' : 'freeze',
                                    child: Text(player.frozen ? 'Odmrzni' : 'Zamrzni'),
                                  ),
                                  const PopupMenuItem(
                                    value: 'archive',
                                    child: Text('Arhiviraj'),
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
                      ),
              ),
            ],
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