import 'package:flutter/material.dart';
import '../models/match_model.dart';
import '../services/firestore_service.dart';

class ViewerMatchesPage extends StatelessWidget {
  const ViewerMatchesPage({super.key});

  String _buildScore(MatchModel match) {
    if (match.superTieBreak.isNotEmpty) {
      return '${match.season} • ${match.set1}, ${match.set2}, ${match.superTieBreak}';
    }
    return '${match.season} • ${match.set1}, ${match.set2}';
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.'
        '${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final firestoreService = FirestoreService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Matches'),
        centerTitle: true,
      ),
      body: StreamBuilder<List<MatchModel>>(
        stream: firestoreService.getMatches(),
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

          final matches = snapshot.data ?? []
            ..sort((a, b) => b.playedAt.compareTo(a.playedAt));

          if (matches.isEmpty) {
            return const Center(
              child: Text('Nema mečeva.'),
            );
          }

          return ListView.builder(
            itemCount: matches.length,
            itemBuilder: (context, index) {
              final match = matches[index];

              return Card(
                child: ListTile(
                  title: Text('${match.player1Name} vs ${match.player2Name}'),
                  subtitle: Text(
                    '${_buildScore(match)}\n${_formatDate(match.playedAt)}',
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