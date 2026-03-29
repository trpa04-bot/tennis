// Skripta za masovni update Firestore kolekcije 'players' prema players_update.json
// Pokreni: flutter pub add cloud_firestore
// i zatim flutter run tools/firestore_bulk_update.dart

import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

Future<void> main() async {
  await Firebase.initializeApp();
  final firestore = FirebaseFirestore.instance;

  final file = File('players_update.json');
  final List<dynamic> data = jsonDecode(await file.readAsString());

  for (final player in data) {
    final name = player['name'] as String;
    final league = player['league'] as String;
    final played = player['played'] as int;
    final points = player['points'] as int;

    // Pronađi igrača po imenu (case-insensitive)
    final query = await firestore
        .collection('players')
        .where('name', isEqualTo: name)
        .get();

    if (query.docs.isNotEmpty) {
      // Update existing
      final doc = query.docs.first;
      await doc.reference.update({
        'league': league,
        'played': played,
        'points': points,
      });
      print('Updated: $name');
    } else {
      // Dodaj novog igrača
      await firestore.collection('players').add({
        'name': name,
        'league': league,
        'played': played,
        'points': points,
        'rating': 1000, // default rating
        'frozen': false,
        'archived': false,
        'achievements': {},
      });
      print('Added: $name');
    }
  }
  print('Bulk update complete!');
}
