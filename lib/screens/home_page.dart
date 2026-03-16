import 'dart:ui';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../utils/browser_reload.dart';
import 'archived_players_page.dart';
import 'league_management_page.dart';
import 'league_table_page.dart';
import 'login_page.dart';
import 'matches_page.dart';
import 'players_page.dart';
import 'promotions_page.dart';
import 'schedule_page.dart';
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
  const AdminHomePage({super.key});

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  int selectedIndex = 0;

  final List<Widget> pages = const [
    AdminWelcomePage(),
    PlayersPage(),
    ArchivedPlayersPage(),
    MatchesPage(),
    LeagueTablePage(),
    SchedulePage(),
    LeagueManagementPage(),
    PromotionsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: pages[selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Players',
          ),
          NavigationDestination(
            icon: Icon(Icons.archive_outlined),
            selectedIcon: Icon(Icons.archive),
            label: 'Arhiva',
          ),
          NavigationDestination(
            icon: Icon(Icons.sports_tennis_outlined),
            selectedIcon: Icon(Icons.sports_tennis),
            label: 'Matches',
          ),
          NavigationDestination(
            icon: Icon(Icons.leaderboard_outlined),
            selectedIcon: Icon(Icons.leaderboard),
            label: 'Table',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Schedule',
          ),
          NavigationDestination(
            icon: Icon(Icons.swap_horiz_outlined),
            selectedIcon: Icon(Icons.swap_horiz),
            label: 'Manage',
          ),
          NavigationDestination(
            icon: Icon(Icons.trending_up_outlined),
            selectedIcon: Icon(Icons.trending_up),
            label: 'Promote',
          ),
        ],
      ),
    );
  }
}

class ViewerHomePage extends StatefulWidget {
  const ViewerHomePage({super.key});

  @override
  State<ViewerHomePage> createState() => _ViewerHomePageState();
}

class _ViewerHomePageState extends State<ViewerHomePage> {
  int selectedIndex = 0;

  final List<Widget> pages = const [
    ViewerWelcomePage(),
    ViewerPlayersPage(),
    ViewerMatchesPage(),
    LeagueTablePage(canResetTrend: false),
    _ActivityFeedPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: pages[selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Players',
          ),
          NavigationDestination(
            icon: Icon(Icons.sports_tennis_outlined),
            selectedIcon: Icon(Icons.sports_tennis),
            label: 'Matches',
          ),
          NavigationDestination(
            icon: Icon(Icons.leaderboard_outlined),
            selectedIcon: Icon(Icons.leaderboard),
            label: 'Table',
          ),
          NavigationDestination(
            icon: Icon(Icons.dynamic_feed_outlined),
            selectedIcon: Icon(Icons.dynamic_feed),
            label: 'Feed',
          ),
        ],
      ),
    );
  }
}

class AdminWelcomePage extends StatelessWidget {
  const AdminWelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final email = FirebaseAuth.instance.currentUser?.email ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel'),
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
              Theme.of(context).colorScheme.surface,
              Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.18),
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
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    const Text('Zadnja događanja u ligi na jednom mjestu.'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const _ActivityFeedCard(),
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
          colors: [
            colorScheme.primary,
            colorScheme.secondary,
          ],
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
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPadding = screenWidth < 600 ? 16.0 : 24.0;
    final topPadding = screenWidth < 600 ? 8.0 : 20.0;

    return Scaffold(
      appBar: AppBar(
        title: const SizedBox.shrink(),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Refresh app',
            onPressed: () async {
              final didReload = await tryReloadApp();
              if (!didReload && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Osvježavanje nije podržano na ovoj platformi.'),
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
                MaterialPageRoute(
                  builder: (_) => const LoginPage(),
                ),
              );
            },
            icon: const Icon(Icons.admin_panel_settings),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/photo_2026-03-16_16-23-22.jpg',
            fit: BoxFit.cover,
            filterQuality: FilterQuality.low,
            errorBuilder: (context, error, stackTrace) =>
                const SizedBox.shrink(),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  colorScheme.surface.withValues(alpha: 0.70),
                  colorScheme.surface.withValues(alpha: 0.44),
                  colorScheme.primaryContainer.withValues(alpha: 0.60),
                ],
                stops: const [0.0, 0.45, 1.0],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black.withValues(alpha: 0.26),
                  Colors.black.withValues(alpha: 0.12),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.25, 0.65],
                begin: Alignment.topCenter,
                end: Alignment.center,
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -0.55),
                radius: 0.95,
                colors: [
                  Colors.black.withValues(alpha: 0.22),
                  Colors.black.withValues(alpha: 0.10),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.38, 1.0],
              ),
            ),
          ),
          ListView(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              topPadding,
              horizontalPadding,
              20,
            ),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          color: colorScheme.surface.withValues(alpha: 0.60),
                          border: Border.all(
                            color: colorScheme.onSurface.withValues(alpha: 0.08),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.10),
                              blurRadius: 18,
                              offset: const Offset(0, 10),
                            ),
                          ],
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
                                  fontSize: 18,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'TK JOGI',
                                style: TextStyle(
                                  fontSize: 34,
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
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActivityFeedPage extends StatelessWidget {
  const _ActivityFeedPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity Feed'),
        centerTitle: true,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Theme.of(context).colorScheme.surface,
              Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.18),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: const [
            _ActivityFeedCard(),
          ],
        ),
      ),
    );
  }
}

class _ActivityFeedCard extends StatelessWidget {
  const _ActivityFeedCard();

  @override
  Widget build(BuildContext context) {
    final firestoreService = FirestoreService();
    final scheme = Theme.of(context).colorScheme;

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
              style: TextStyle(
                color: scheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 14),
            StreamBuilder<List<ActivityFeedItem>>(
              stream: firestoreService.getActivityFeed(),
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
                    final (icon, color) = _feedVisuals(item.icon, scheme);
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: color.withValues(alpha: 0.14),
                        child: Icon(icon, color: color, size: 20),
                      ),
                      title: Text(
                        item.title,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text('${item.subtitle} • ${_formatFeedDate(item.timestamp)}'),
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