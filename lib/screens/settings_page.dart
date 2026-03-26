import 'package:flutter/material.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../services/theme_service.dart';
import '../utils/app_themes.dart';
import 'unresolved_matches_repair_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool get isAdmin => AuthService.instance.isAdmin;
  final FirestoreService _firestoreService = FirestoreService();

  bool _isBackfillingMatchLeagues = false;
  MatchLeagueBackfillReport? _lastBackfillReport;

  Future<void> _changeTheme(AppTheme theme) async {
    try {
      await ThemeService.instance.setGlobalTheme(theme);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Tema promijenjena na ${theme.displayName}'),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tema nije spremljena. Provjeri vezu i admin pristup.'),
        ),
      );
    }
  }

  Color _getThemeColor(AppTheme theme) {
    return theme.seedColor;
  }

  Future<void> _runMatchLeagueBackfill() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Migriraj lige na stare mečeve?'),
          content: const Text(
            'Ovo će upisati polje league na postojeće mečeve gdje se liga može sigurno rekonstruirati iz trenutnih ili arhiviranih igrača.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Odustani'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Pokreni migraciju'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    setState(() {
      _isBackfillingMatchLeagues = true;
    });

    try {
      final report = await _firestoreService.backfillMissingMatchLeagues();
      if (!mounted) return;

      setState(() {
        _lastBackfillReport = report;
      });

      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            report.updated == 0
                ? 'Migracija je završila bez promjena.'
                : 'Migracija gotova: ažurirano ${report.updated} mečeva.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Migracija nije uspjela: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isBackfillingMatchLeagues = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeData = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Postavke'), centerTitle: true),
      body: SingleChildScrollView(
        primary: true,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isAdmin) ...[
              Text(
                'Odaberi temu aplikacije',
                style: themeData.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ValueListenableBuilder<AppTheme>(
                valueListenable: ThemeService.instance.getThemeNotifier(),
                builder: (context, selectedTheme, _) {
                  return GridView.count(
                    crossAxisCount: 3,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: 0.88,
                    children: [
                      for (final theme in AppTheme.values)
                        _buildThemeCard(theme, selectedTheme),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              Text(
                'Način teme',
                style: themeData.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              ValueListenableBuilder<ThemeMode>(
                valueListenable: ThemeService.instance.getThemeModeNotifier(),
                builder: (context, mode, _) {
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('Svijetla'),
                        selected: mode == ThemeMode.light,
                        onSelected: (selected) {
                          if (selected) {
                            ThemeService.instance.setThemeMode(ThemeMode.light);
                          }
                        },
                      ),
                      ChoiceChip(
                        label: const Text('Tamna'),
                        selected: mode == ThemeMode.dark,
                        onSelected: (selected) {
                          if (selected) {
                            ThemeService.instance.setThemeMode(ThemeMode.dark);
                          }
                        },
                      ),
                      ChoiceChip(
                        label: const Text('Automatski'),
                        selected: mode == ThemeMode.system,
                        onSelected: (selected) {
                          if (selected) {
                            ThemeService.instance.setThemeMode(
                              ThemeMode.system,
                            );
                          }
                        },
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: const Text('Vrati na zadanu temu'),
                  onPressed: () async {
                    await ThemeService.instance.resetToDefault();
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Vraćena zadana tema aplikacije.'),
                      ),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
            Text(
              'Migracija podataka',
              style: themeData.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Backfill match league',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Popunjava league na starim mečevima gdje se može pouzdano odrediti iz ID-a ili jedinstvenog imena igrača.',
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _isBackfillingMatchLeagues
                          ? null
                          : _runMatchLeagueBackfill,
                      icon: _isBackfillingMatchLeagues
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.data_thresholding),
                      label: Text(
                        _isBackfillingMatchLeagues
                            ? 'Migracija u tijeku...'
                            : 'Pokreni backfill',
                      ),
                    ),
                    if (_lastBackfillReport != null) ...[
                      const SizedBox(height: 12),
                      Text('Pregledano: ${_lastBackfillReport!.scanned}'),
                      Text('Ažurirano: ${_lastBackfillReport!.updated}'),
                      Text(
                        'Normalizirano postojećih: ${_lastBackfillReport!.normalizedExisting}',
                      ),
                      Text(
                        'Riješeno po ID-u: ${_lastBackfillReport!.resolvedByIds}',
                      ),
                      Text(
                        'Riješeno po imenu: ${_lastBackfillReport!.resolvedByNames}',
                      ),
                      Text(
                        'Preskočeno zbog konflikta: ${_lastBackfillReport!.skippedConflicts}',
                      ),
                      Text(
                        'Preskočeno bez pouzdanog odgovora: ${_lastBackfillReport!.skippedUnresolved}',
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Popravi mečeve bez lige',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Prikazuje mečeve kojima backfill nije mogao automatski odrediti ligu. Možeš ih ručno ispraviti.',
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => const UnresolvedMatchesRepairPage(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.build_outlined),
                      label: const Text('Otvori popis'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeCard(AppTheme theme, AppTheme selectedTheme) {
    final isSelected = selectedTheme == theme;
    final color = _getThemeColor(theme);
    final previewIsDark = theme == AppTheme.matchdark;

    return GestureDetector(
      onTap: () {
        _changeTheme(theme);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        child: Card(
          elevation: isSelected ? 8 : 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: isSelected
                ? BorderSide(color: color, width: 3)
                : BorderSide(
                    color: Theme.of(context).dividerColor.withOpacity(0.20),
                  ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (theme == AppTheme.matchdark)
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF031A35),
                          Color(0xFF18345F),
                          Color(0xFF28D98A),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  )
                else
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                const SizedBox(height: 8),
                Expanded(
                  child: Center(
                    child: Text(
                      theme.displayName,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: previewIsDark
                            ? Theme.of(context).textTheme.bodyLarge?.color
                            : null,
                      ),
                    ),
                  ),
                ),
                if (isSelected)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Icon(Icons.check_circle, color: color, size: 20),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}