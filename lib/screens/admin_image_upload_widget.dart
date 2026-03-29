import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
// import 'package:flutter_native_ocr/flutter_native_ocr.dart';
import '../models/match_model.dart';
import '../models/player.dart';
import '../services/firestore_service.dart';

class AdminImageUploadWidget extends StatefulWidget {
  const AdminImageUploadWidget({super.key});

  @override
  State<AdminImageUploadWidget> createState() => _AdminImageUploadWidgetState();
}

class _AdminImageUploadWidgetState extends State<AdminImageUploadWidget> {
  final FirestoreService _firestoreService = FirestoreService();
  List<Player>? _allPlayers;
  bool _savingMatch = false;
  bool _usingHandwritingOcr = false;
  @override
  void initState() {
    super.initState();
    _loadPlayers();
  }

  Future<void> _loadPlayers() async {
    final snap = await _firestoreService.players.get();
    if (!mounted) {
      return;
    }
    setState(() {
      _allPlayers = snap.docs
          .map(
            (doc) =>
                Player.fromMap(doc.data() as Map<String, dynamic>, id: doc.id),
          )
          .toList();
    });
  }

  Player? _findPlayerByName(String name) {
    if (_allPlayers == null) {
      return null;
    }
    final normalized = name.trim().toLowerCase();
    return _allPlayers!.firstWhere(
      (p) => p.name.trim().toLowerCase() == normalized,
      orElse: () => _allPlayers!.firstWhere(
        (p) =>
            normalized.contains(p.name.trim().toLowerCase()) ||
            p.name.trim().toLowerCase().contains(normalized),
        orElse: () =>
            Player(id: '', name: name, rating: 0, league: '', archived: false),
      ),
    );
  }

  Future<void> _parseAndSaveMatch() async {
    if (_ocrText == null || _ocrText!.isEmpty) {
      return;
    }
    setState(() {
      _savingMatch = true;
    });
    try {
      final lines = _ocrText!
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();
      String? player1, player2, result, winner, league, season;
      DateTime? date;

      // Podržava više formata: pokušaj prepoznati redove
      for (final line in lines) {
        final dateMatch = RegExp(
          r'(\d{1,2}[./-]\d{1,2}[./-]\d{2,4})',
        ).firstMatch(line);
        if (dateMatch != null) {
          final d = dateMatch
              .group(1)!
              .replaceAll('-', '.')
              .replaceAll('/', '.');
          date = DateTime.tryParse(d.split('.').reversed.join('-')) ?? date;
        }
        if (line.toLowerCase().contains('liga'))
          league = line.split(':').last.trim();
        if (line.toLowerCase().contains('sezona'))
          season = line.split(':').last.trim();
        if (line.toLowerCase().contains('pobjednik'))
          winner = line.split(':').last.trim();
        if (RegExp(r'\d+:\d+').hasMatch(line)) result = line;
        // Try to extract player names from lines with a dash
        if (line.contains('-')) {
          final parts = line.split('-');
          if (parts.length == 2) {
            player1 = parts[0].trim();
            player2 = parts[1].trim();
          }
        }
      }

      // Find Player objects
      final p1 = player1 != null ? _findPlayerByName(player1) : null;
      final p2 = player2 != null ? _findPlayerByName(player2) : null;
      if (p1 == null || p2 == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nije moguće pronaći igrače!')),
        );
        setState(() {
          _savingMatch = false;
        });
        return;
      }

      // Parse sets and winner
      String? set1, set2, stb, winnerId;
      if (result != null) {
        final setMatches = RegExp(r'(\d+:\d+)').allMatches(result);
        final sets = setMatches.map((m) => m.group(1)!).toList();
        if (sets.isNotEmpty) set1 = sets[0];
        if (sets.length > 1) set2 = sets[1];
        if (sets.length > 2) stb = sets[2];
      }
      if (winner != null) {
        if (p1.name.toLowerCase().contains(winner.toLowerCase())) {
          winnerId = p1.id;
        } else if (p2.name.toLowerCase().contains(winner.toLowerCase())) {
          winnerId = p2.id;
        }
      }

      final match = MatchModel(
        player1Id: p1.id ?? '',
        player2Id: p2.id ?? '',
        player1Name: p1.name,
        player2Name: p2.name,
        league: league ?? p1.league,
        set1: set1 ?? '',
        set2: set2 ?? '',
        superTieBreak: stb ?? '',
        season: season ?? 'Winter 2026',
        winnerId: winnerId ?? '',
        playedAt: date ?? DateTime.now(),
        simpleMode: false,
        resultLabel: result ?? '',
      );
      await _firestoreService.addMatch(match);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Meč automatski upisan!')));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Greška pri automatskom upisu: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _savingMatch = false;
        });
      }
    }
  }

  XFile? _image;
  bool _uploading = false;
  String? _uploadedUrl;
  String? _ocrText;
  final ImagePicker _picker = ImagePicker();

  Future<void> _runOcr() async {
    // TODO: Implement OCR logic here
    // For now, just set _ocrText to a placeholder
    setState(() {
      _ocrText = '';
    });
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _image = pickedFile;
      });
    }
  }

  Future<void> _uploadImage() async {
    if (_image == null) {
      return;
    }
    setState(() {
      _uploading = true;
    });
    try {
      final storageRef = FirebaseStorage.instance.ref().child(
        'match_results/${DateTime.now().millisecondsSinceEpoch}_${_image!.name}',
      );
      final uploadTask = storageRef.putFile(File(_image!.path));
      final snapshot = await uploadTask;
      final url = await snapshot.ref.getDownloadURL();
      if (!mounted) return;
      setState(() {
        _uploadedUrl = url;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Slika uspješno uploadana!')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Greška pri uploadu: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _uploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ElevatedButton.icon(
          onPressed: _pickImage,
          icon: const Icon(Icons.image),
          label: const Text('Odaberi sliku rezultata'),
        ),
        Row(
          children: [
            Checkbox(
              value: _usingHandwritingOcr,
              onChanged: (v) =>
                  setState(() => _usingHandwritingOcr = v ?? false),
            ),
            const Text('Koristi prepoznavanje rukopisa (handwriting OCR)'),
          ],
        ),
        if (_image != null) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Image.file(File(_image!.path), height: 120),
          ),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: _uploading ? null : _uploadImage,
                icon: const Icon(Icons.cloud_upload),
                label: _uploading
                    ? const Text('Učitavanje...')
                    : const Text('Uploadaj sliku'),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _runOcr,
                icon: const Icon(Icons.text_snippet),
                label: const Text('Pročitaj tekst (OCR)'),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _savingMatch ? null : _parseAndSaveMatch,
                icon: const Icon(Icons.save),
                label: _savingMatch
                    ? const Text('Spremanje...')
                    : const Text('Upiši meč automatski'),
              ),
            ],
          ),
        ],
        if (_uploadedUrl != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('URL slike: $_uploadedUrl'),
          ),
        if (_ocrText != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Prepoznati tekst:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(_ocrText!),
              ],
            ),
          ),
      ],
    );
  }
}
