import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../utils/browser_reload.dart';
import 'league_management_page.dart';
import 'league_table_page.dart';
import 'login_page.dart';
import 'matches_page.dart';
import 'players_page.dart';
import 'playoff_bracket_page.dart';
import 'promotions_page.dart';
import 'schedule_page.dart';
import 'match_sheet_pdf_page.dart';
import 'settings_page.dart';
import 'viewer_matches_page.dart';
import 'viewer_players_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService.instance.authStateChanges(),
      builder: (context, snapshot) {
        final isAdmin = AuthService.instance.isAdmin;

        if (isAdmin) {
          return const AdminHomePage();
        }

        return const ViewerHomePage();
      },
    );
  }
}

class AdminHomePage extends StatefulWidget {
  const AdminHomePage({super.key, this.pages});

  final List<Widget>? pages;

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  int selectedIndex = 0;

  List<Widget> get pages =>
      widget.pages ??
      [
        AdminWelcomePage(),
        PlayersPage(),
        MatchesPage(),
        LeagueTablePage(),
        ActivityFeedPage(),
        PlayoffBracketPage(),
        SchedulePage(),
        LeagueManagementPage(),
        PromotionsPage(),
        MatchSheetPdfPage(),
        SettingsPage(),
      ];

  @override
  Widget build(BuildContext context) {
    final List<_AdminNavItem> navItems = [
      const _AdminNavItem('Home', Icons.home_outlined, Icons.home),
      const _AdminNavItem('Players', Icons.people_outline, Icons.people),
      const _AdminNavItem(
        'Matches',
        Icons.sports_tennis_outlined,
        Icons.sports_tennis,
      ),
      const _AdminNavItem(
        'Table',
        Icons.leaderboard_outlined,
        Icons.leaderboard,
      ),
      const _AdminNavItem(
        'Feed',
        Icons.dynamic_feed_outlined,
        Icons.dynamic_feed,
      ),
      const _AdminNavItem(
        'Playoff',
        Icons.emoji_events_outlined,
        Icons.emoji_events,
      ),
      const _AdminNavItem(
        'Schedule',
        Icons.calendar_month_outlined,
        Icons.calendar_month,
      ),
      const _AdminNavItem(
        'Manage',
        Icons.swap_horiz_outlined,
        Icons.swap_horiz,
      ),
      const _AdminNavItem(
        'Promote',
        Icons.trending_up_outlined,
        Icons.trending_up,
      ),
      const _AdminNavItem('Print', Icons.print_outlined, Icons.print),
      const _AdminNavItem('Settings', Icons.settings_outlined, Icons.settings),
    ];

    double iconBarHeight = 80;

    return Scaffold(
      body: pages[selectedIndex],
      bottomNavigationBar: Container(
        color: Theme.of(context).colorScheme.surface,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        child: SizedBox(
          height: iconBarHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: navItems.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final item = navItems[index];
              final isSelected = selectedIndex == index;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    selectedIndex = index;
                  });
                },
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isSelected ? item.selectedIcon : item.icon,
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).iconTheme.color,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.label,
                      style: TextStyle(
                        fontSize: 12,
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).textTheme.bodyMedium?.color,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _AdminNavItem {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  const _AdminNavItem(this.label, this.icon, this.selectedIcon);
}

class ViewerHomePage extends StatefulWidget {
  const ViewerHomePage({super.key, this.pages});

  final List<Widget>? pages;

  @override
  State<ViewerHomePage> createState() => _ViewerHomePageState();
}

class _ViewerHomePageState extends State<ViewerHomePage> {
  int selectedIndex = 0;

  List<Widget> get pages =>
      widget.pages ??
      [
        ViewerWelcomePage(),
        ViewerPlayersPage(),
        ViewerMatchesPage(),
        LeagueTablePage(),
        ActivityFeedPage(),
        // PlayoffBracketPage(), // SAKRIVENO ZA VIEWER MOD
        SchedulePage(),
        LeagueManagementPage(),
        PromotionsPage(),
        MatchSheetPdfPage(),
        SettingsPage(),
      ];

  @override
  Widget build(BuildContext context) {
    final List<_AdminNavItem> navItems = [
      const _AdminNavItem('Home', Icons.home_outlined, Icons.home),
      const _AdminNavItem('Players', Icons.people_outline, Icons.people),
      const _AdminNavItem(
        'Matches',
        Icons.sports_tennis_outlined,
        Icons.sports_tennis,
      ),
      const _AdminNavItem(
        'Table',
        Icons.leaderboard_outlined,
        Icons.leaderboard,
      ),
      const _AdminNavItem(
        'Feed',
        Icons.dynamic_feed_outlined,
        Icons.dynamic_feed,
      ),
      // const _AdminNavItem(
      //   'Playoff',
      //   Icons.emoji_events_outlined,
      //   Icons.emoji_events,
      // ), // SAKRIVENO ZA VIEWER MOD
      const _AdminNavItem(
        'Schedule',
        Icons.calendar_month_outlined,
        Icons.calendar_month,
      ),
      const _AdminNavItem(
        'Manage',
        Icons.swap_horiz_outlined,
        Icons.swap_horiz,
      ),
      const _AdminNavItem(
        'Promote',
        Icons.trending_up_outlined,
        Icons.trending_up,
      ),
      const _AdminNavItem('Print', Icons.print_outlined, Icons.print),
      const _AdminNavItem('Settings', Icons.settings_outlined, Icons.settings),
    ];

    int columns = (navItems.length / 2).ceil();
    double iconBarHeight = 112;

    return Scaffold(
      body: pages[selectedIndex],
      bottomNavigationBar: Container(
        color: Theme.of(context).colorScheme.surface,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        child: SizedBox(
          height: iconBarHeight,
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisSpacing: 0,
              crossAxisSpacing: 0,
              childAspectRatio: 1.3,
            ),
            itemCount: navItems.length,
            itemBuilder: (context, index) {
              final item = navItems[index];
              final isSelected = selectedIndex == index;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    selectedIndex = index;
                  });
                },
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isSelected ? item.selectedIcon : item.icon,
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).iconTheme.color,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.label,
                      style: TextStyle(
                        fontSize: 12,
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).textTheme.bodyMedium?.color,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class AdminWelcomePage extends StatelessWidget {
  const AdminWelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final email = FirebaseAuth.instance.currentUser?.email ?? '';
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text('TENISKA', style: TextStyle(fontSize: 12.75)),
            Text('AKADEMIJA', style: TextStyle(fontSize: 12.75)),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Logout to viewer',
            onPressed: () async {
              await AuthService.instance.signOutToViewer();
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              scheme.surface,
              scheme.primaryContainer.withValues(alpha: 0.18),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Admin: $email',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text('Zadnja događanja u ligi na jednom mjestu.'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ViewerWelcomePage extends StatelessWidget {
  const ViewerWelcomePage({super.key});

  Widget _viewerLogo(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: 212,
      height: 212,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [colorScheme.primary, colorScheme.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(5),
        child: ClipOval(
          child: Image.asset(
            'assets/tk_jogi_logo.jpeg',
            fit: BoxFit.cover,
            width: 230,
            height: 230,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('TENISKA', style: TextStyle(fontSize: 19.5)),
            Text('AKADEMIJA', style: TextStyle(fontSize: 19.5)),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () async {
              final didReload = await tryReloadApp();
              if (!didReload && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Refresh je dostupan samo na webu.'),
                  ),
                );
              }
            },
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Admin login',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LoginPage()),
              );
            },
            icon: const Icon(Icons.admin_panel_settings),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              colorScheme.surface,
              colorScheme.primaryContainer.withValues(alpha: 0.28),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 28,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _viewerLogo(context),
                    const SizedBox(height: 18),
                    Text(
                      'Dobrodošli u aplikaciju',
                      style: TextStyle(
                        fontSize: 14,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'TK JOGI',
                      style: TextStyle(
                        fontSize: 24, // smanjeno za ~30%
                        fontWeight: FontWeight.w800,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Teniska liga Zagreb',
                      style: TextStyle(
                        fontSize: 16,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'App developed by Trpimir Šugar',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '"Zbog ljubavi prema tenisu i sportu"',
                      style: TextStyle(
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    Divider(color: colorScheme.outlineVariant),
                    const SizedBox(height: 12),
                    const Text(
                      'Pregledaj igrače, mečeve i tablicu lige.',
                      textAlign: TextAlign.center,
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
}

class ActivityFeedPage extends StatelessWidget {
  const ActivityFeedPage({super.key, this.activityFeedStream});

  final Stream<List<ActivityFeedItem>>? activityFeedStream;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('News Feed'), centerTitle: true),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              scheme.surface,
              scheme.primaryContainer.withValues(alpha: 0.18),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [_ActivityFeedCard(activityFeedStream: activityFeedStream)],
        ),
      ),
    );
  }
}

class _ActivityFeedCard extends StatelessWidget {
  const _ActivityFeedCard({this.activityFeedStream});

  final Stream<List<ActivityFeedItem>>? activityFeedStream;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final stream = activityFeedStream ?? FirestoreService().getActivityFeed();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.dynamic_feed_outlined),
                const SizedBox(width: 8),
                Text(
                  'Activity Feed',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Najnoviji mečevi, badgevi i pomaci na tablici.',
              style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.7)),
            ),
            const SizedBox(height: 14),
            StreamBuilder<List<ActivityFeedItem>>(
              stream: stream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                if (snapshot.hasError) {
                  return Text('Greška: ${snapshot.error}');
                }

                final items = snapshot.data ?? [];
                if (items.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('Feed će se pojaviti nakon prvih aktivnosti.'),
                  );
                }

                return Column(
                  children: items.map((item) {
                    final visuals = _feedVisuals(item.icon, scheme);
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: visuals.$2.withValues(alpha: 0.14),
                        child: Icon(visuals.$1, color: visuals.$2, size: 20),
                      ),
                      title: Text(
                        item.title,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        '${item.subtitle} • ${_formatFeedDate(item.timestamp)}',
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  (IconData, Color) _feedVisuals(ActivityFeedIcon icon, ColorScheme scheme) {
    switch (icon) {
      case ActivityFeedIcon.match:
        return (Icons.sports_tennis, scheme.primary);
      case ActivityFeedIcon.achievement:
        return (Icons.workspace_premium, Colors.amber.shade700);
      case ActivityFeedIcon.rankUp:
        return (Icons.arrow_upward, Colors.blue);
      case ActivityFeedIcon.rankDown:
        return (Icons.arrow_downward, Colors.red);
    }
  }

  String _formatFeedDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.'
        '${date.year}';
  }
}
