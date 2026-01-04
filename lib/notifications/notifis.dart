import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_app_icon_badge/flutter_app_icon_badge.dart';
import 'package:notifi/notifications/db_provider.dart';
import 'package:notifi/notifications/notification.dart';
import 'package:notifi/utils/utils.dart';

class Notifications extends ChangeNotifier {
  Notifications(this.notifications, this.db, this.tableNotifier,
      {this.canBadge = false}) {
    setUnreadCnt();
  }

  TableNotifier tableNotifier;
  DBProvider db;
  final bool canBadge; // is allowed to set badge on app icon
  List<NotificationUI> notifications = List<NotificationUI>.empty();
  GlobalKey<AnimatedListState> tableKey = GlobalKey<AnimatedListState>();
  ScrollController tableController = ScrollController();
  ValueNotifier<int> notificationCnt = ValueNotifier<int>(0);

  @override
  void dispose() {
    notificationCnt.dispose();
    super.dispose();
  }

  // ignore: use_setters_to_change_properties
  void setTableNotifier(TableNotifier tableNotifier) {
    this.tableNotifier = tableNotifier;
  }

  int get length => notifications.length;

  NotificationUI get(int index) {
    return notifications[index];
  }

  void scrollToTop() {
    if (tableController.hasClients) {
      tableController.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  void setUnreadCnt() {
    int cnt = 0;
    for (int i = 0; i < notifications.length; i++) {
      if (!notifications[i].isRead) {
        cnt++;
      }
    }

    if (cnt > 0) {
      MenuBarIcon.set('red');
    } else {
      MenuBarIcon.set('grey');
    }

    if (canBadge) {
      FlutterAppIconBadge.updateBadge(cnt);
    }

    notificationCnt.value = cnt;
  }

  Future<int> add(NotificationUI notification) async {
    int id;
    try {
      id = await db.store(notification);
    } catch (e) {
      L.e('Problem storing notification in db: $e');
      return -1;
    }

    notification.id = id;
    notifications.insert(0, notification);
    if (notifications.length == 1) {
      tableNotifier.notify();
    }
    notifications.sort((NotificationUI b, NotificationUI a) =>
        a.dttmTime.compareTo(b.dttmTime));

    return id;
  }

  Future<void> delete(int index) async {
    final NotificationUI notification = notifications[index];
    await db.delete(notification.id);
    notifications.removeAt(index);
    setUnreadCnt();
    if (notifications.isEmpty) {
      tableNotifier.notify();
    } else {
      // animate out notification
      tableKey.currentState?.removeItem(index,
          (BuildContext context, Animation<double> animation) {
        final Animation<Offset> _offsetAnimation = Tween<Offset>(
          begin: const Offset(-0.2, 0.0),
          end: const Offset(-1, 0),
        ).animate(ReverseAnimation(animation));

        return SlideTransition(
          position: _offsetAnimation,
          child: notification,
        );
      });
    }
  }

  Future<void> deleteAll() async {
    HapticFeedback.vibrate();
    await db.deleteAll();
    notifications.clear();
    tableKey = GlobalKey<AnimatedListState>();
    tableNotifier.notify();
    setUnreadCnt();
  }

  Future<void> markRead(int index, {required bool isRead}) async {
    HapticFeedback.lightImpact();
    notifications[index].read = isRead;
    await db.markRead(notifications[index].id, isRead: isRead);
    setUnreadCnt();
  }

  Future<void> toggleRead(int index) async {
    final NotificationUI notification = notifications[index];
    markRead(index, isRead: !notification.isRead);
  }

  Future<void> readAll() async {
    bool hasMarkedRead = false;
    for (int i = 0; i < notifications.length; i++) {
      if (!notifications[i].read) hasMarkedRead = true;
      notifications[i].read = true;
    }

    if (hasMarkedRead) {
      HapticFeedback.heavyImpact();
      await db.markAllRead();
      setUnreadCnt();
      notifyListeners(); // redraw all notifications
    }
  }
}

class TableNotifier extends ChangeNotifier {
  void notify() {
    notifyListeners();
  }
}

class UnreadCntNotifier extends ChangeNotifier {
  void notify() {
    notifyListeners();
  }
}
