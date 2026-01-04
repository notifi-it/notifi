import 'dart:io';

import 'package:akar_icons_flutter/akar_icons_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notifi/main.dart';
import 'package:notifi/notifications/db_provider.dart';
import 'package:notifi/notifications/notification.dart';
import 'package:notifi/notifications/notifis.dart';
import 'package:notifi/screens/home.dart';
import 'package:notifi/screens/settings.dart';
import 'package:notifi/user.dart';
import 'package:notifi/utils/utils.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

final String lorem = 'Lorem ipsum dolor sit amet, consectetur adipiscing elit. '
    'Nullam in bibendum est. Duis lacinia, nulla a vulputate cursus, '
    'lectus dui dictum eros, vitae fermentum diam ex vel felis. '
    'Suspendisse augue magna, euismod ac consequat quis, laoreet ut ante. '
    'Quisque at ligula in risus '
    'Nullam in bibendum est. Duis lacinia, nulla a vulputate cursus, '
    'lectus dui dictum eros, vitae fermentum diam ex vel felis. '
    'Suspendisse augue magna, euismod ac consequat quis, laoreet ut ante. '
    'Quisque at ligula in risus ';
final double width = 1200;
final TextTheme textTheme = getTextTheme();

void main() {
  const String time = '2006-01-02 15:04:05';
  // original 2400.0, 1800.0
  const Size physicalSizeTestValue = Size(2200, 1200);

  group('Test Screens', () {
    testWidgets('No Notifications', (WidgetTester tester) async {
      await pumpWidgetWithNotification(tester, null);
      // first page should show no notifications
      expect(find.byKey(Key('no-notifications')), findsOneWidget);

      await goldenAssert(
          find.byType(HomeScreen), 'screen/no-notifications.png');
    });

    testWidgets('Single Notification', (WidgetTester tester) async {
      await pumpWidgetWithNotification(
          tester,
          NotificationUI(
            title: 'title of notification',
            uuid: '',
            time: time,
          ));
      // first page should show no notifications
      expect(find.text('title of notification'), findsOneWidget);

      await goldenAssert(find.byType(HomeScreen), 'screen/notification.png');
    });

    testWidgets('Test Settings Navigation', (WidgetTester tester) async {
      tester.binding.window.physicalSizeTestValue = Size(2200, 4200);
      await pumpWidgetWithNotification(tester, null);

      // open settings
      await tester.tap(find.byIcon(AkarIcons.gear));
      await tester.pump();
      // not sure why I have to do twice
      await tester.pump(const Duration(seconds: 1));

      // should show that there are new credentials
      expect(find.text('Create New Credentials'), findsOneWidget);

      await goldenAssert(find.byType(SettingsScreen), 'screen/settings.png');
    });

    // TODO test log navigation
  });

  group('Test Notifications', () {
    const List<String> titles = <String>[
      'title of notification',
      'title of notification title of notification titl'
    ];
    const List<String> messages = <String>[
      '',
      'message of notification',
      'notification '
          'message of notification  message of notification message '
          'of notification message of notification message of notification of '
          'notification message of notification of notificati'
    ];
    const List<String> links = <String>['', 'https://max.me.uk/'];
    const List<String> images = <String>['', 'https://max.me.uk/someimage.jpg'];

    String longTtl, longMsg;
    int cnt = 0;

    // got from printing _messageKey.currentContext.size.width
    double width = 666.33;

    // get long title
    // ignore: literal_only_boolean_expressions
    while (true) {
      cnt += 1;
      String str = lorem.substring(0, cnt);
      if (hasTextOverflow(str, textTheme.displayLarge, maxWidth: width - 15)) {
        // 15 == iconsize
        longTtl = str;
        break;
      }
    }

    // get long message
    // ignore: literal_only_boolean_expressions
    while (true) {
      cnt += 1;
      String str = lorem.substring(0, cnt);
      if (hasTextOverflow(str, textTheme.bodyLarge,
          maxWidth: width, maxLines: 3)) {
        longMsg = str;
        break;
      }
    }

    group('Test Notification Combinations', () {
      for (int a = 0; a < titles.length; a++) {
        for (int b = 0; b < messages.length; b++) {
          for (int c = 0; c < links.length; c++) {
            for (int d = 0; d < images.length; d++) {
              final NotificationUI n = NotificationUI(
                title: titles[a],
                message: messages[b],
                link: links[c],
                image: images[d],
                time: time,
                uuid: '',
              );
              final String name = 'title_$a-message_$b-links_$c-images_$d';
              testWidgets(name, (WidgetTester tester) async {
                tester.binding.window.physicalSizeTestValue =
                    physicalSizeTestValue;

                await pumpWidgetWithNotification(tester, n);
                await tester.pump();

                await goldenAssert(
                    find.byType(NotificationUI), 'notification/$name.png');
              });
            }
          }
        }
      }
    });

    testWidgets('Test Mark As Read', (WidgetTester tester) async {
      final NotificationUI n = NotificationUI(
        title: titles[0],
        time: time,
        uuid: '',
      );
      await pumpWidgetWithNotification(tester, n);
      await tester.pump();

      expect(n.isRead, false);
      expect(find.text('1'), findsOneWidget);

      // mark read
      await tester.tap(find.byIcon(AkarIcons.check));
      await tester.pump();

      expect(n.isRead, true);

      await goldenAssert(
          find.byType(NotificationUI), 'notification/is_read.png');
    });

    testWidgets('Test Expand Action', (WidgetTester tester) async {
      final NotificationUI n = NotificationUI(
        title: longTtl,
        message: longMsg,
        time: time,
        uuid: '',
      );
      await pumpWidgetWithNotification(tester, n);
      await tester.pump();
      await tester.pumpAndSettle();

      expect(n.isExpanded, false);
      expect(n.isRead, false);
      expect(find.text('1'), findsOneWidget);

      // expand
      await tester.tap(find.byKey(Key('toggle-expand')));
      await tester.pumpAndSettle();

      expect(n.isExpanded, true);
      expect(n.isRead, true);

      await goldenAssert(
          find.byType(NotificationUI), 'notification/is_expanded.png');
    });

    group('Test Expand Combinations', () {
      final Map<String, NotificationUI> inputsToBeExpected =
          <String, NotificationUI>{
        'title': NotificationUI(
          time: time,
          uuid: '',
          title: longTtl,
        ),
        'message': NotificationUI(
          time: time,
          uuid: '',
          title: 'foo',
          message: longMsg,
        ),
        'title-message': NotificationUI(
          time: time,
          uuid: '',
          title: longTtl,
          message: longMsg,
        ),
      };
      inputsToBeExpected.forEach((String name, NotificationUI notification) {
        testWidgets(name, (WidgetTester tester) async {
          await pumpWidgetWithNotification(tester, notification);
          await tester.pump();

          expect(find.byIcon(AkarIcons.enlarge), findsOneWidget);
        });
      });
    });

    group('Test No Expand Combinations', () {
      final Map<String, NotificationUI> inputsToBeExpected =
          <String, NotificationUI>{
        'title': NotificationUI(
          time: time,
          uuid: '',
          title: longTtl.substring(0, longTtl.length - 1),
        ),
        'message': NotificationUI(
          time: time,
          uuid: '',
          title: 'foo',
          message: longMsg.substring(0, longMsg.length - 1),
        ),
        'title-message': NotificationUI(
          time: time,
          uuid: '',
          title: longTtl.substring(0, longTtl.length - 1),
          message: longMsg.substring(0, longMsg.length - 1),
        ),
      };
      inputsToBeExpected.forEach((String name, NotificationUI notification) {
        testWidgets(name, (WidgetTester tester) async {
          await pumpWidgetWithNotification(tester, notification);
          await tester.pump();

          expect(find.byIcon(AkarIcons.enlarge), findsNothing);
        });
      });
    });
  });
}

Future<void> goldenAssert(Finder finder, String imagePath) async {
  if (!Platform.isMacOS) {
    // ignore: avoid_print
    print('Skipping $imagePath assert');
    return;
  }

  return await expectLater(
      finder, matchesGoldenFile('golden-asserts/${imagePath}'));
}

Future<void> pumpWidgetWithNotification(
    WidgetTester tester, NotificationUI notification) async {
  WidgetsFlutterBinding.ensureInitialized();

  // CHANNEL MOCKS
  const MethodChannel('plugins.flutter.io/path_provider')
      .setMockMethodCallHandler((MethodCall methodCall) async {
    if (methodCall.method == 'getApplicationDocumentsDirectory') {
      return '';
    }
    if (methodCall.method == 'getLibraryDirectory') {
      return '';
    }
  });

  const MethodChannel('com.tekartik.sqflite')
      .setMockMethodCallHandler((MethodCall methodCall) async {
    if (methodCall.method == 'openDatabase') {
      return await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    }
    if (methodCall.method == 'getDatabasesPath') {
      return '';
    }
  });

  const MethodChannel('plugins.it_nomads.com/flutter_secure_storage')
      .setMockMethodCallHandler((MethodCall methodCall) async {
    if (methodCall.method == 'read') {
      return '{"UUID": "foo", "credentials": "bar", "credentialKey": "baz"}';
    }
  });

  const MethodChannel('vibration')
      .setMockMethodCallHandler((MethodCall methodCall) async {});
  // finished MOCKS

  final DBProvider db = DBProvider('test.db');
  final List<NotificationUI> notifications =
      List<NotificationUI>.empty(growable: true);
  notifications.add(notification);

  await loadDotEnv();

  await tester.pumpWidget(MultiProvider(
    providers: <SingleChildWidget>[
      ChangeNotifierProvider<TableNotifier>(create: (_) => TableNotifier()),
      ChangeNotifierProxyProvider<TableNotifier, Notifications>(
        create: (BuildContext context) => Notifications(notifications, db,
            Provider.of<TableNotifier>(context, listen: false)),
        update: (BuildContext context, TableNotifier tableNotifier,
                Notifications user) =>
            user..setTableNotifier(tableNotifier),
      ),
      ChangeNotifierProxyProvider<Notifications, User>(
        create: (BuildContext context) =>
            User(Provider.of<Notifications>(context, listen: false), null),
        update:
            (BuildContext context, Notifications notifications, User user) =>
                user..setNotifications(notifications),
      ),
    ],
    child: const MyApp(),
  ));
}
