import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/player.dart';
import '../models/round_robin_models.dart';
import '../services/firestore_service.dart';
import '../services/round_robin_service.dart';
import '../utils/file_download.dart';
import '../utils/league_utils.dart';

const int _kMaxRounds = 14;

class MatchSheetPdfPage extends StatefulWidget {
  const MatchSheetPdfPage({super.key});

  @override
  State<MatchSheetPdfPage> createState() => _MatchSheetPdfPageState();
}

class _MatchSheetPdfPageState extends State<MatchSheetPdfPage> {
  final _firestoreService = FirestoreService();
  final _roundRobinService = RoundRobinService();

  String _selectedSeason = 'Winter 2026';
  bool _generating = false;

  static const List<String> _seasons = ['Winter 2026', 'Summer 2026'];

  // ── helpers ──────────────────────────────────────────────────────────────

  List<Player> _playersForLeague(List<Player> all, String key) =>
      all
          .where(
            (p) =>
                LeagueUtils.normalize(p.league) == key &&
                !p.archived &&
                !p.frozen,
          )
          .toList()
        ..sort((a, b) => a.name.compareTo(b.name));

  int _seasonYear(String s) {
    final parts = s.split(' ');
    return parts.length == 2 ? (int.tryParse(parts[1]) ?? 2026) : 2026;
  }

  String _fmtTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}';

  String _fmtDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}.'
      '${dt.month.toString().padLeft(2, '0')}.'
      '${dt.year}.';

  // ── PDF generation ────────────────────────────────────────────────────────

  Future<void> _generate(List<Player> allPlayers) async {
    setState(() => _generating = true);
    try {
      await _buildAndDownload(allPlayers);
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _buildAndDownload(List<Player> allPlayers) async {
    final season = _selectedSeason;
    final year = _seasonYear(season);
    final isWinter = season.startsWith('Winter');

    // generate round-robin schedule for every league
    final schedules = <String, List<ScheduledRound>>{};
    for (final key in ['1', '2', '3', '4']) {
      final players = _playersForLeague(allPlayers, key);
      schedules[key] = isWinter
          ? _roundRobinService.generateWinterSchedule(
              players: players,
              league: key,
              seasonYear: year,
            )
          : _roundRobinService.generateSummerSchedule(
              players: players,
              league: key,
              seasonYear: year,
            );
    }

    int maxRounds = schedules.values
        .map((r) => r.length)
        .fold(0, (a, b) => a > b ? a : b);
    if (maxRounds == 0) maxRounds = 1;
    if (maxRounds > _kMaxRounds) maxRounds = _kMaxRounds;

    final doc = pw.Document();

    for (int i = 0; i < maxRounds; i++) {
      final roundNumber = i + 1;

      final roundData = <String, ScheduledRound?>{};
      DateTime? roundDate;
      for (final key in ['1', '2', '3', '4']) {
        final rounds = schedules[key]!;
        final round = i < rounds.length ? rounds[i] : null;
        roundData[key] = round;
        roundDate ??= round?.date;
      }

      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.symmetric(
            horizontal: 18 * PdfPageFormat.mm,
            vertical: 15 * PdfPageFormat.mm,
          ),
          build: (_) => _buildPage(
            roundNumber: roundNumber,
            season: season,
            roundDate: roundDate,
            roundData: roundData,
            isFirstPage: roundNumber == 1,
          ),
        ),
      );
    }

    final bytes = await doc.save();
    final ok = await downloadBytes(
      bytes: bytes,
      fileName: 'odigrani_mecevi_${season.replaceAll(' ', '_')}.pdf',
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

  // ── PDF page widget ───────────────────────────────────────────────────────

  pw.Widget _buildPage({
    required int roundNumber,
    required String season,
    required DateTime? roundDate,
    required Map<String, ScheduledRound?> roundData,
    required bool isFirstPage,
  }) {
    final dateStr = roundDate != null ? _fmtDate(roundDate) : '';

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        // ── main title on first page only ──
        if (isFirstPage) ...[
          pw.Center(
            child: pw.Text(
              'ODIGRANI MEČEVI',
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(height: 3),
          pw.Center(
            child: pw.Text(
              'Sezona: $season',
              style: const pw.TextStyle(fontSize: 11),
            ),
          ),
          pw.SizedBox(height: 10),
        ],

        // ── round header bar ──
        pw.Container(
          color: PdfColors.blueGrey800,
          padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 8),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'KOLO  $roundNumber',
                style: pw.TextStyle(
                  fontSize: 15,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
              ),
              if (dateStr.isNotEmpty)
                pw.Text(
                  dateStr,
                  style: const pw.TextStyle(
                    fontSize: 11,
                    color: PdfColors.white,
                  ),
                ),
            ],
          ),
        ),

        pw.SizedBox(height: 8),

        // ── league sections ──
        for (final key in ['1', '2', '3', '4']) ...[
          _buildLeagueSection(key, roundData[key]),
          pw.SizedBox(height: 7),
        ],
      ],
    );
  }

  static PdfColor _leagueColor(String key) {
    switch (key) {
      case '1':
        return PdfColors.orange700; // Roland Garros – clay
      case '2':
        return PdfColors.blue700; // Australian Open – hard
      case '3':
        return PdfColors.green700; // Wimbledon – grass
      case '4':
        return PdfColors.purple700; // US Open
      default:
        return PdfColors.blueGrey700;
    }
  }

  pw.Widget _buildLeagueSection(String leagueKey, ScheduledRound? round) {
    final leagueName = LeagueUtils.label(leagueKey);
    final headerColor = _leagueColor(leagueKey);
    final matches = round?.matches ?? <ScheduledMatchSlot>[];

    final rows = <pw.TableRow>[
      // column header row
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.grey200),
        children: [
          _hdrCell('Sat'),
          _hdrCell('Ter.'),
          _hdrCell('Igrač 1'),
          _hdrCell('1. set', center: true),
          _hdrCell('2. set', center: true),
          _hdrCell('STB', center: true),
          _hdrCell('Igrač 2'),
        ],
      ),
    ];

    if (matches.isEmpty) {
      rows.add(
        pw.TableRow(
          children: [
            _emptyCell(),
            _emptyCell(),
            _textCell('Nema mečeva za ovo kolo.'),
            _emptyCell(),
            _emptyCell(),
            _emptyCell(),
            _emptyCell(),
          ],
        ),
      );
    } else {
      for (final m in matches) {
        rows.add(
          pw.TableRow(
            children: [
              _textCell(_fmtTime(m.startAt), center: true),
              _textCell('${m.courtNumber}', center: true),
              _textCell(m.player1Name),
              _scoreCell(),
              _scoreCell(),
              _scoreCell(),
              _textCell(m.player2Name),
            ],
          ),
        );
      }
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Container(
          color: headerColor,
          padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 6),
          child: pw.Text(
            leagueName,
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
          ),
        ),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
          columnWidths: const {
            0: pw.FixedColumnWidth(34), // time
            1: pw.FixedColumnWidth(26), // court
            2: pw.FlexColumnWidth(3), // player 1
            3: pw.FixedColumnWidth(36), // set 1
            4: pw.FixedColumnWidth(36), // set 2
            5: pw.FixedColumnWidth(36), // STB
            6: pw.FlexColumnWidth(3), // player 2
          },
          children: rows,
        ),
      ],
    );
  }

  // ── table cell helpers ────────────────────────────────────────────────────

  pw.Widget _hdrCell(String text, {bool center = false}) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 3),
    child: pw.Text(
      text,
      textAlign: center ? pw.TextAlign.center : pw.TextAlign.left,
      style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
    ),
  );

  pw.Widget _textCell(String text, {bool center = false}) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 4),
    child: pw.Text(
      text,
      textAlign: center ? pw.TextAlign.center : pw.TextAlign.left,
      style: const pw.TextStyle(fontSize: 9),
    ),
  );

  pw.Widget _emptyCell() => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 5),
    child: pw.Container(height: 9),
  );

  /// Empty score box – just padding so the bordered cell is large enough to
  /// write a result in by hand.
  pw.Widget _scoreCell() => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 2),
    child: pw.Container(height: 9),
  );

  // ── Flutter UI ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Player>>(
      stream: _firestoreService.getPlayers(),
      builder: (context, snapshot) {
        final allPlayers = snapshot.data ?? [];
        final loading =
            snapshot.connectionState == ConnectionState.waiting &&
            allPlayers.isEmpty;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Print – Odigrani Mečevi'),
            centerTitle: true,
          ),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.picture_as_pdf,
                    size: 72,
                    color: Colors.blueGrey,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Generiraj PDF s listama za ručno upisivanje rezultata.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Svaka stranica A4 = jedno kolo, sve 4 lige.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  DropdownButton<String>(
                    value: _selectedSeason,
                    items: _seasons
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: _generating
                        ? null
                        : (v) {
                            if (v != null) {
                              setState(() => _selectedSeason = v);
                            }
                          },
                  ),
                  const SizedBox(height: 20),
                  if (loading)
                    const CircularProgressIndicator()
                  else if (_generating)
                    const Column(
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 10),
                        Text('Generiranje PDF-a…'),
                      ],
                    )
                  else
                    ElevatedButton.icon(
                      icon: const Icon(Icons.download),
                      label: const Text('Generiraj & Preuzmi PDF'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 14,
                        ),
                      ),
                      onPressed: () => _generate(allPlayers),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
