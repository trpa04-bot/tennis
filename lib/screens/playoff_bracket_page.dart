import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:pdf/widgets.dart' as pw;

import '../services/firestore_service.dart';
import '../utils/file_download.dart';

class PlayoffBracketPage extends StatefulWidget {
  const PlayoffBracketPage({super.key});

  @override
  State<PlayoffBracketPage> createState() => _PlayoffBracketPageState();
}

class _PlayoffBracketPageState extends State<PlayoffBracketPage> {
  final FirestoreService _firestoreService = FirestoreService();
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final GlobalKey _exportKey = GlobalKey();

  static const String _season = 'Winter 2026';

  late Future<_PlayoffData> _playoffFuture;

  CollectionReference<Map<String, dynamic>> get _playoffResults =>
      _db.collection('playoff_results');

  DocumentReference<Map<String, dynamic>> get _playoffConfig =>
      _db.collection('config').doc('playoff');

  @override
  void initState() {
    super.initState();
    _playoffFuture = _loadPlayoffData();
  }

  Future<_PlayoffData> _loadPlayoffData() async {
    final rolandGarros = await _firestoreService.getLeagueTableOnce(
      league: '1',
      season: _season,
    );
    final australianOpen = await _firestoreService.getLeagueTableOnce(
      league: '2',
      season: _season,
    );

    final selected = <_SeededPlayer>[
      ...rolandGarros
          .take(14)
          .toList()
          .asMap()
          .entries
          .map(
            (entry) => _SeededPlayer(
              overallSeed: entry.key + 1,
              sourceRank: entry.key + 1,
              sourceLeague: 'Roland Garros',
              row: entry.value,
            ),
          ),
      ...australianOpen
          .take(2)
          .toList()
          .asMap()
          .entries
          .map(
            (entry) => _SeededPlayer(
              overallSeed: 15 + entry.key,
              sourceRank: entry.key + 1,
              sourceLeague: 'Australian Open',
              row: entry.value,
            ),
          ),
    ];

    if (selected.length < 16) {
      return _PlayoffData(
        selectedPlayers: selected,
        picks: const [],
        isReady: false,
      );
    }

    final captains = selected.take(8).toList();
    final remaining = selected.skip(8).toList();
    final picks = <_PickPair>[];

    for (final captain in captains) {
      // Seeded captains pick from the remaining pool: #1 first, then #2, etc.
      // Current skeleton uses an ATP-style conservative approach: pick lowest remaining seed.
      final chosen = remaining.removeLast();
      picks.add(
        _PickPair(
          pickOrder: captain.overallSeed,
          captain: captain,
          opponent: chosen,
        ),
      );
    }

    return _PlayoffData(selectedPlayers: selected, picks: picks, isReady: true);
  }

  String _resultKey(String round, int index) => '${round}_$index';

  String _resultDocId(String round, int index) =>
      '${_season.replaceAll(' ', '_')}_${round}_$index';

  List<({String round, int index})> _downstreamMatches(
    String round,
    int index,
  ) {
    const rounds = ['r16', 'qf', 'sf', 'f'];
    final startIndex = rounds.indexOf(round);
    if (startIndex == -1 || startIndex == rounds.length - 1) {
      return const [];
    }

    final matches = <({String round, int index})>[];
    var nextIndex = index;
    for (var i = startIndex + 1; i < rounds.length; i++) {
      nextIndex = nextIndex ~/ 2;
      matches.add((round: rounds[i], index: nextIndex));
    }
    return matches;
  }

  Future<void> _deleteDownstreamMatches(
    WriteBatch batch,
    String round,
    int index,
  ) async {
    for (final match in _downstreamMatches(round, index)) {
      batch.delete(_playoffResults.doc(_resultDocId(match.round, match.index)));
    }
  }

  Stream<Map<String, _MatchState>> _resultStream() {
    return _playoffResults.where('season', isEqualTo: _season).snapshots().map((
      snapshot,
    ) {
      final map = <String, _MatchState>{};
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final round = data['round']?.toString() ?? '';
        final indexRaw = data['index'];
        final index = int.tryParse(indexRaw?.toString() ?? '');
        if (round.isEmpty || index == null) continue;
        map[_resultKey(round, index)] = _MatchState(
          winnerId: data['winnerId']?.toString() ?? '',
          winnerName: data['winnerName']?.toString() ?? '',
          scoreLabel: data['scoreLabel']?.toString() ?? '',
          playerAId: data['playerAId']?.toString() ?? '',
          playerBId: data['playerBId']?.toString() ?? '',
        );
      }
      return map;
    });
  }

  Future<void> _saveResult({
    required String round,
    required int index,
    required _BracketPlayer winner,
    required String scoreLabel,
  }) async {
    final batch = _db.batch();
    batch.set(_playoffResults.doc(_resultDocId(round, index)), {
      'season': _season,
      'round': round,
      'index': index,
      'winnerId': winner.playerId,
      'winnerName': winner.playerName,
      'scoreLabel': scoreLabel,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await _deleteDownstreamMatches(batch, round, index);
    await batch.commit();
  }

  Future<void> _savePlayersOverride({
    required _BracketMatch match,
    required _BracketPlayer? playerA,
    required _BracketPlayer? playerB,
  }) async {
    final batch = _db.batch();
    batch.set(
      _playoffResults.doc(_resultDocId(match.round, match.index)),
      {
        'season': _season,
        'round': match.round,
        'index': match.index,
        'playerAId': playerA?.playerId ?? '',
        'playerBId': playerB?.playerId ?? '',
        'winnerId': FieldValue.delete(),
        'winnerName': FieldValue.delete(),
        'scoreLabel': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    await _deleteDownstreamMatches(batch, match.round, match.index);
    await batch.commit();
  }

  Future<void> _resetResult(_BracketMatch match) async {
    final batch = _db.batch();
    batch.set(
      _playoffResults.doc(_resultDocId(match.round, match.index)),
      {
        'season': _season,
        'round': match.round,
        'index': match.index,
        'winnerId': FieldValue.delete(),
        'winnerName': FieldValue.delete(),
        'scoreLabel': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    await _deleteDownstreamMatches(batch, match.round, match.index);
    await batch.commit();
  }

  Stream<bool> _lockStream() {
    return _playoffConfig.snapshots().map(
      (doc) => doc.data()?['locked'] == true,
    );
  }

  Future<void> _setBracketLocked(bool locked) async {
    await _playoffConfig.set({
      'locked': locked,
      if (locked)
        'lockedAt': FieldValue.serverTimestamp()
      else
        'unlockedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _confirmLockToggle(bool isLocked) async {
    final shouldLock = !isLocked;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            shouldLock ? 'Zaključaj doigravanje?' : 'Otključaj doigravanje?',
          ),
          content: Text(
            shouldLock
                ? 'Kad je zaključano, nema uređivanja parova i rezultata.'
                : 'Otključavanje vraća mogućnost uređivanja parova i rezultata.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Odustani'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(shouldLock ? 'Zaključaj' : 'Otključaj'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;
    await _setBracketLocked(shouldLock);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          shouldLock
              ? 'Doigravanje je zaključano.'
              : 'Doigravanje je otključano.',
        ),
      ),
    );
  }

  Future<Uint8List?> _captureBracketPng() async {
    final boundaryContext = _exportKey.currentContext;
    if (boundaryContext == null) return null;

    final boundary =
        boundaryContext.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;

    final image = await boundary.toImage(pixelRatio: 3);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }

  Future<void> _exportAsImage() async {
    final pngBytes = await _captureBracketPng();
    if (pngBytes == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Export nije uspio. Pokušaj ponovno.')),
      );
      return;
    }

    final ok = await downloadBytes(
      bytes: pngBytes,
      fileName: 'playoff_${_season.replaceAll(' ', '_')}.png',
      mimeType: 'image/png',
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Slika je preuzeta.'
              : 'Preuzimanje slike nije podržano na ovoj platformi.',
        ),
      ),
    );
  }

  Future<void> _exportAsPdf() async {
    final pngBytes = await _captureBracketPng();
    if (pngBytes == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Export nije uspio. Pokušaj ponovno.')),
      );
      return;
    }

    final doc = pw.Document();
    final imageProvider = pw.MemoryImage(pngBytes);

    doc.addPage(
      pw.Page(
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Winter 2026 Playoff', style: pw.TextStyle(fontSize: 18)),
              pw.SizedBox(height: 10),
              pw.Image(imageProvider),
            ],
          );
        },
      ),
    );

    final bytes = await doc.save();
    final ok = await downloadBytes(
      bytes: bytes,
      fileName: 'playoff_${_season.replaceAll(' ', '_')}.pdf',
      mimeType: 'application/pdf',
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'PDF je preuzet.'
              : 'Preuzimanje PDF-a nije podržano na ovoj platformi.',
        ),
      ),
    );
  }

  Future<void> _showPlayersDialog(
    _BracketMatch match,
    List<_BracketPlayer> selectablePlayers,
    bool isLocked,
  ) async {
    if (isLocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Doigravanje je zaključano.')),
      );
      return;
    }

    _BracketPlayer? byId(String? id) {
      if (id == null || id.isEmpty) return null;
      for (final player in selectablePlayers) {
        if (player.playerId == id) return player;
      }
      return null;
    }

    _BracketPlayer? selectedA = match.playerA;
    _BracketPlayer? selectedB = match.playerB;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                'Odabir igrača • ${match.roundLabel} #${match.index + 1}',
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: selectedA?.playerId,
                    decoration: const InputDecoration(labelText: 'Igrač A'),
                    items: selectablePlayers
                        .map(
                          (player) => DropdownMenuItem<String>(
                            value: player.playerId,
                            child: Text(player.displayName),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setDialogState(() {
                        selectedA = byId(value) ?? selectedA;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedB?.playerId,
                    decoration: const InputDecoration(labelText: 'Igrač B'),
                    items: selectablePlayers
                        .map(
                          (player) => DropdownMenuItem<String>(
                            value: player.playerId,
                            child: Text(player.displayName),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setDialogState(() {
                        selectedB = byId(value) ?? selectedB;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Odustani'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (selectedA == null || selectedB == null) return;
                    final navigator = Navigator.of(context);
                    final messenger = ScaffoldMessenger.of(this.context);
                    if (selectedA!.playerId == selectedB!.playerId) {
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Igrač ne može igrati sam protiv sebe.',
                          ),
                        ),
                      );
                      return;
                    }
                    await _savePlayersOverride(
                      match: match,
                      playerA: selectedA,
                      playerB: selectedB,
                    );
                    if (!mounted) return;
                    navigator.pop();
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Par je spremljen.')),
                    );
                  },
                  child: const Text('Spremi'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showResultDialog(_BracketMatch match, bool isLocked) async {
    if (isLocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Doigravanje je zaključano.')),
      );
      return;
    }

    if (match.playerA == null || match.playerB == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pričekaj da se popune oba igrača u ovom meču.'),
        ),
      );
      return;
    }

    _BracketPlayer? selectedWinner =
        match.result?.winnerId == match.playerA!.playerId
        ? match.playerA
        : match.result?.winnerId == match.playerB!.playerId
        ? match.playerB
        : null;
    String selectedScore = match.result?.scoreLabel.isNotEmpty == true
        ? match.result!.scoreLabel
        : '2:0';

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                'Unos rezultata • ${match.roundLabel} #${match.index + 1}',
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: Text(match.playerA!.playerName),
                        selected:
                            selectedWinner?.playerId == match.playerA!.playerId,
                        onSelected: (selected) {
                          if (!selected) return;
                          setDialogState(() {
                            selectedWinner = match.playerA;
                          });
                        },
                      ),
                      ChoiceChip(
                        label: Text(match.playerB!.playerName),
                        selected:
                            selectedWinner?.playerId == match.playerB!.playerId,
                        onSelected: (selected) {
                          if (!selected) return;
                          setDialogState(() {
                            selectedWinner = match.playerB;
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: ['2:0', '2:1'].map((score) {
                      return ChoiceChip(
                        label: Text(score),
                        selected: selectedScore == score,
                        onSelected: (_) {
                          setDialogState(() {
                            selectedScore = score;
                          });
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Odustani'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (selectedWinner == null) return;
                    final navigator = Navigator.of(context);
                    final messenger = ScaffoldMessenger.of(this.context);
                    await _saveResult(
                      round: match.round,
                      index: match.index,
                      winner: selectedWinner!,
                      scoreLabel: selectedScore,
                    );
                    if (!mounted) return;
                    navigator.pop();
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Rezultat spremljen.')),
                    );
                  },
                  child: const Text('Spremi'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  _BracketPlayer? _winnerFrom(_BracketMatch match) {
    if (match.result == null) return null;
    if (match.playerA?.playerId == match.result!.winnerId) return match.playerA;
    if (match.playerB?.playerId == match.result!.winnerId) return match.playerB;
    return null;
  }

  _BracketModel _buildBracket(
    List<_PickPair> picks,
    Map<String, _MatchState> states,
    List<_BracketPlayer> selectablePlayers,
  ) {
    _BracketPlayer? byId(String id) {
      if (id.isEmpty) return null;
      for (final player in selectablePlayers) {
        if (player.playerId == id) return player;
      }
      return null;
    }

    final r16 = <_BracketMatch>[];
    for (int i = 0; i < picks.length; i++) {
      final pair = picks[i];
      final state = states[_resultKey('r16', i)];
      r16.add(
        _BracketMatch(
          round: 'r16',
          roundLabel: 'R16',
          index: i,
          playerA:
              byId(state?.playerAId ?? '') ??
              _BracketPlayer.fromSeeded(pair.captain),
          playerB:
              byId(state?.playerBId ?? '') ??
              _BracketPlayer.fromSeeded(pair.opponent),
          result: state,
        ),
      );
    }

    final qf = <_BracketMatch>[];
    for (int i = 0; i < 4; i++) {
      final m1 = r16[i * 2];
      final m2 = r16[i * 2 + 1];
      final state = states[_resultKey('qf', i)];
      qf.add(
        _BracketMatch(
          round: 'qf',
          roundLabel: 'QF',
          index: i,
          playerA: byId(state?.playerAId ?? '') ?? _winnerFrom(m1),
          playerB: byId(state?.playerBId ?? '') ?? _winnerFrom(m2),
          result: state,
        ),
      );
    }

    final sf = <_BracketMatch>[];
    for (int i = 0; i < 2; i++) {
      final m1 = qf[i * 2];
      final m2 = qf[i * 2 + 1];
      final state = states[_resultKey('sf', i)];
      sf.add(
        _BracketMatch(
          round: 'sf',
          roundLabel: 'SF',
          index: i,
          playerA: byId(state?.playerAId ?? '') ?? _winnerFrom(m1),
          playerB: byId(state?.playerBId ?? '') ?? _winnerFrom(m2),
          result: state,
        ),
      );
    }

    final finalState = states[_resultKey('f', 0)];
    final finalMatch = _BracketMatch(
      round: 'f',
      roundLabel: 'Final',
      index: 0,
      playerA: byId(finalState?.playerAId ?? '') ?? _winnerFrom(sf[0]),
      playerB: byId(finalState?.playerBId ?? '') ?? _winnerFrom(sf[1]),
      result: finalState,
    );

    return _BracketModel(r16: r16, qf: qf, sf: sf, finalMatch: finalMatch);
  }

  Widget _heroHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF031633), Color(0xFF0B2D5A), Color(0xFF154A8D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: const Color(0xFFCEA24A).withValues(alpha: 0.65),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x44000000),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Color(0xFFF2CF7D), Color(0xFFB9872A)],
              ),
            ),
            child: const Icon(Icons.emoji_events, color: Color(0xFF13264D)),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Winter 2026 Playoff',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Top 16 elimination bracket • ATP style skeleton',
                  style: TextStyle(color: Color(0xFFD7E5FF), fontSize: 13.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPickFlow(List<_PickPair> picks) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE4E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Captain Picks (1-8)',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          ...picks.map(
            (pair) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0A2F61),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '#${pair.pickOrder}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${pair.captain.row.playerName} picks ${pair.opponent.row.playerName}',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeedingOverview(List<_SeededPlayer> players) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE4E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Selected 16',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          ...players.map(
            (player) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 36,
                    child: Text(
                      '#${player.overallSeed}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Expanded(child: Text(player.row.playerName)),
                  Text(
                    '${player.sourceLeague} #${player.sourceRank}',
                    style: const TextStyle(
                      color: Color(0xFF5C6A80),
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoundSection(
    String title,
    List<_BracketMatch> matches,
    List<_BracketPlayer> selectablePlayers,
    bool isLocked,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF081E3F),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          ...matches.map(
            (match) => _buildMatchCard(match, selectablePlayers, isLocked),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchCard(
    _BracketMatch match,
    List<_BracketPlayer> selectablePlayers,
    bool isLocked,
  ) {
    final canEdit = match.playerA != null && match.playerB != null;
    final winner = _winnerFrom(match);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0E2D59),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF345C99)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  match.playerA?.displayName ?? 'TBD',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Text('vs', style: TextStyle(color: Color(0xFFD6E6FF))),
              ),
              Expanded(
                child: Text(
                  match.playerB?.displayName ?? 'TBD',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  winner == null
                      ? 'Rezultat nije unesen'
                      : 'Winner: ${winner.playerName} (${match.result!.scoreLabel})',
                  style: const TextStyle(
                    color: Color(0xFFD9E7FF),
                    fontSize: 12.5,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () =>
                    _showPlayersDialog(match, selectablePlayers, isLocked),
                icon: const Icon(Icons.people_alt_outlined, size: 18),
                label: const Text('Igrači'),
              ),
              TextButton.icon(
                onPressed: canEdit
                    ? () => _showResultDialog(match, isLocked)
                    : null,
                icon: const Icon(Icons.edit_note, size: 18),
                label: const Text('Rezultat'),
              ),
              PopupMenuButton<String>(
                enabled: !isLocked,
                onSelected: (value) async {
                  if (value == 'reset_result') {
                    await _resetResult(match);
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Rezultat je resetiran.')),
                    );
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem<String>(
                    value: 'reset_result',
                    child: Text('Reset rezultata'),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChampionCard(_BracketMatch finalMatch) {
    final champion = _winnerFrom(finalMatch);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [Color(0xFF102A52), Color(0xFF1E4B86)],
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.workspace_premium,
            color: Color(0xFFF2CF7D),
            size: 30,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              champion == null
                  ? 'Champion: TBD'
                  : 'Champion: ${champion.playerName}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_PlayoffData>(
      future: _playoffFuture,
      builder: (context, snapshot) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Playoff'),
            centerTitle: true,
            actions: [
              StreamBuilder<bool>(
                stream: _lockStream(),
                builder: (context, lockSnapshot) {
                  final isLocked = lockSnapshot.data ?? false;
                  return IconButton(
                    tooltip: isLocked
                        ? 'Otključaj doigravanje'
                        : 'Zaključaj doigravanje',
                    onPressed: () => _confirmLockToggle(isLocked),
                    icon: Icon(isLocked ? Icons.lock : Icons.lock_open),
                  );
                },
              ),
              PopupMenuButton<String>(
                tooltip: 'Export',
                onSelected: (value) async {
                  if (value == 'export_png') {
                    await _exportAsImage();
                  }
                  if (value == 'export_pdf') {
                    await _exportAsPdf();
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem<String>(
                    value: 'export_png',
                    child: Text('Export PNG'),
                  ),
                  PopupMenuItem<String>(
                    value: 'export_pdf',
                    child: Text('Export PDF'),
                  ),
                ],
              ),
            ],
          ),
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFF3F6FC), Color(0xFFE9EEF7)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _heroHeader(context),
                const SizedBox(height: 12),
                if (snapshot.connectionState == ConnectionState.waiting)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (snapshot.hasError)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('Greška: ${snapshot.error}'),
                    ),
                  )
                else if (!(snapshot.data?.isReady ?? false))
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Nema dovoljno igrača za playoff (potrebno 16, dostupno ${snapshot.data?.selectedPlayers.length ?? 0}).',
                      ),
                    ),
                  )
                else ...[
                  StreamBuilder<bool>(
                    stream: _lockStream(),
                    builder: (context, lockSnapshot) {
                      final isLocked = lockSnapshot.data ?? false;

                      return StreamBuilder<Map<String, _MatchState>>(
                        stream: _resultStream(),
                        builder: (context, resultSnapshot) {
                          if (resultSnapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }

                          final states = resultSnapshot.data ?? const {};
                          final selectablePlayers = snapshot
                              .data!
                              .selectedPlayers
                              .map(_BracketPlayer.fromSeeded)
                              .toList();
                          final bracket = _buildBracket(
                            snapshot.data!.picks,
                            states,
                            selectablePlayers,
                          );

                          return RepaintBoundary(
                            key: _exportKey,
                            child: Column(
                              children: [
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isLocked
                                          ? const Color(0xFFFFE8E8)
                                          : const Color(0xFFE6F4EA),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      isLocked
                                          ? 'Status: Zaključano'
                                          : 'Status: Otključano',
                                      style: TextStyle(
                                        color: isLocked
                                            ? const Color(0xFF9F2B2B)
                                            : const Color(0xFF1A7F37),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _buildSeedingOverview(
                                  snapshot.data!.selectedPlayers,
                                ),
                                const SizedBox(height: 12),
                                _buildPickFlow(snapshot.data!.picks),
                                const SizedBox(height: 12),
                                _buildRoundSection(
                                  'Round of 16',
                                  bracket.r16,
                                  selectablePlayers,
                                  isLocked,
                                ),
                                const SizedBox(height: 12),
                                _buildRoundSection(
                                  'Quarterfinals',
                                  bracket.qf,
                                  selectablePlayers,
                                  isLocked,
                                ),
                                const SizedBox(height: 12),
                                _buildRoundSection(
                                  'Semifinals',
                                  bracket.sf,
                                  selectablePlayers,
                                  isLocked,
                                ),
                                const SizedBox(height: 12),
                                _buildRoundSection(
                                  'Final',
                                  [bracket.finalMatch],
                                  selectablePlayers,
                                  isLocked,
                                ),
                                const SizedBox(height: 12),
                                _buildChampionCard(bracket.finalMatch),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PlayoffData {
  final List<_SeededPlayer> selectedPlayers;
  final List<_PickPair> picks;
  final bool isReady;

  const _PlayoffData({
    required this.selectedPlayers,
    required this.picks,
    required this.isReady,
  });
}

class _SeededPlayer {
  final int overallSeed;
  final int sourceRank;
  final String sourceLeague;
  final LeagueTableRow row;

  const _SeededPlayer({
    required this.overallSeed,
    required this.sourceRank,
    required this.sourceLeague,
    required this.row,
  });
}

class _PickPair {
  final int pickOrder;
  final _SeededPlayer captain;
  final _SeededPlayer opponent;

  const _PickPair({
    required this.pickOrder,
    required this.captain,
    required this.opponent,
  });
}

class _MatchState {
  final String winnerId;
  final String winnerName;
  final String scoreLabel;
  final String playerAId;
  final String playerBId;

  const _MatchState({
    required this.winnerId,
    required this.winnerName,
    required this.scoreLabel,
    required this.playerAId,
    required this.playerBId,
  });
}

class _BracketPlayer {
  final String playerId;
  final String playerName;
  final int seed;

  const _BracketPlayer({
    required this.playerId,
    required this.playerName,
    required this.seed,
  });

  factory _BracketPlayer.fromSeeded(_SeededPlayer player) {
    return _BracketPlayer(
      playerId: player.row.playerId,
      playerName: player.row.playerName,
      seed: player.overallSeed,
    );
  }

  String get displayName => '($seed) $playerName';
}

class _BracketMatch {
  final String round;
  final String roundLabel;
  final int index;
  final _BracketPlayer? playerA;
  final _BracketPlayer? playerB;
  final _MatchState? result;

  const _BracketMatch({
    required this.round,
    required this.roundLabel,
    required this.index,
    required this.playerA,
    required this.playerB,
    required this.result,
  });
}

class _BracketModel {
  final List<_BracketMatch> r16;
  final List<_BracketMatch> qf;
  final List<_BracketMatch> sf;
  final _BracketMatch finalMatch;

  const _BracketModel({
    required this.r16,
    required this.qf,
    required this.sf,
    required this.finalMatch,
  });
}
