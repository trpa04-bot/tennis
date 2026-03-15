import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ArchivedPlayersPage extends StatelessWidget {
  const ArchivedPlayersPage({super.key});

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

  String _formatArchivedAt(dynamic archivedAt) {
    if (archivedAt is Timestamp) {
      final date = archivedAt.toDate();
      return '${date.day.toString().padLeft(2, '0')}.'
          '${date.month.toString().padLeft(2, '0')}.'
          '${date.year}';
    }
    return '-';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Arhiva igrača'),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
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
                      Text('Arhivirano: ${_formatArchivedAt(archivedAt)}'),
                    ],
                  ),
                  isThreeLine: true,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
