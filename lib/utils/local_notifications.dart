import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:notifi/notifications/notification.dart';

Future<FlutterLocalNotificationsPlugin> initPushNotifications() async {
  final FlutterLocalNotificationsPlugin localNotifications =
      FlutterLocalNotificationsPlugin();

  InitializationSettings settings = InitializationSettings(
      android: AndroidInitializationSettings('app_icon'),
      iOS: DarwinInitializationSettings(defaultPresentAlert: false),
      macOS: DarwinInitializationSettings(
        defaultPresentAlert: false,
      ),
      linux: LinuxInitializationSettings(
          defaultActionName: 'defaultActionName',
          defaultSound: ThemeLinuxSound('message'),
          defaultIcon: AssetsLinuxIcon('images/bell.png')));

  await localNotifications.initialize(settings);

  await localNotifications
      .resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin>()
      ?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
  return localNotifications;
}

void sendLocalNotification(FlutterLocalNotificationsPlugin localNotification,
    int id, NotificationUI notification) {
  const DarwinNotificationDetails iOS = DarwinNotificationDetails();
  const DarwinNotificationDetails macOS = DarwinNotificationDetails();
  const NotificationDetails platformChannelSpecifics =
      NotificationDetails(iOS: iOS, macOS: macOS);

  localNotification.show(
      id, notification.title, notification.message, platformChannelSpecifics);
}
