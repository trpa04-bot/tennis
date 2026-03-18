import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tennis_club_app/screens/home_page.dart';
import 'package:tennis_club_app/services/firestore_service.dart';

void main() {
  Widget wrapApp(Widget child) {
    return MaterialApp(home: child);
  }

  List<Widget> viewerPages() {
    return const [
      Center(child: Text('viewer-home-page')),
      Center(child: Text('viewer-players-page')),
      Center(child: Text('viewer-matches-page')),
      Center(child: Text('viewer-table-page')),
      Center(child: Text('viewer-feed-page')),
    ];
  }

  List<Widget> adminPages() {
    return const [
      Center(child: Text('admin-home-page')),
      Center(child: Text('admin-players-page')),
      Center(child: Text('admin-matches-page')),
      Center(child: Text('admin-table-page')),
      Center(child: Text('admin-feed-page')),
      Center(child: Text('admin-playoff-page')),
      Center(child: Text('admin-schedule-page')),
      Center(child: Text('admin-manage-page')),
      Center(child: Text('admin-promote-page')),
    ];
  }

  testWidgets('viewer bottom navigation opens feed tab after table', (
    tester,
  ) async {
    await tester.pumpWidget(wrapApp(ViewerHomePage(pages: viewerPages())));

    expect(find.text('viewer-home-page'), findsOneWidget);

    await tester.tap(find.text('Feed'));
    await tester.pumpAndSettle();

    expect(find.text('viewer-feed-page'), findsOneWidget);

    await tester.tap(find.text('Table'));
    await tester.pumpAndSettle();

    expect(find.text('viewer-table-page'), findsOneWidget);
  });

  testWidgets('admin bottom navigation opens feed tab before playoff', (
    tester,
  ) async {
    await tester.pumpWidget(wrapApp(AdminHomePage(pages: adminPages())));

    expect(find.text('admin-home-page'), findsOneWidget);

    await tester.tap(find.text('Feed'));
    await tester.pumpAndSettle();

    expect(find.text('admin-feed-page'), findsOneWidget);

    await tester.tap(find.text('Playoff'));
    await tester.pumpAndSettle();

    expect(find.text('admin-playoff-page'), findsOneWidget);
  });

  testWidgets('activity feed page renders mocked items', (tester) async {
    final feedItem = ActivityFeedItem(
      timestamp: DateTime(2026, 3, 17),
      icon: ActivityFeedIcon.match,
      title: 'Igrač A pobijedio Igrača B',
      subtitle: '2:0',
    );

    await tester.pumpWidget(
      wrapApp(ActivityFeedPage(activityFeedStream: Stream.value([feedItem]))),
    );
    await tester.pumpAndSettle();

    expect(find.text('News Feed'), findsOneWidget);
    expect(find.text('Activity Feed'), findsOneWidget);
    expect(find.text('Igrač A pobijedio Igrača B'), findsOneWidget);
  });
}
