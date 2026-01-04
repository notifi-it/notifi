import 'dart:async';
import 'dart:io';

import 'package:notifi/notifications/notification.dart';
import 'package:notifi/utils/utils.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

class DBProvider {
  DBProvider(this.dbPath, {this.fillWithNotifications = false});

  final String _table = 'notifications';
  final String dbPath;
  Database? _db;
  bool fillWithNotifications;

  Future<Database> initDB() async {
    if (_db != null) {
      return _db!;
    }

    Directory dir;
    if (isTest) {
      dir = Directory('/');
    } else if (Platform.isAndroid || Platform.isLinux) {
      dir = await getApplicationSupportDirectory();
    } else {
      dir = await getLibraryDirectory();
    }
    dir = Directory(join(dir.path, 'notifi/'));
    dir.create(recursive: true);

    String path = join(dir.path, dbPath);
    L.i('DB path: $path');

    _db = await openDatabase(path, onCreate: (Database db, int version) {
      return db.execute('''
        CREATE TABLE IF NOT EXISTS $_table (
          _id integer primary key autoincrement, 
          UUID text unique not null,
          title text not null,
          time text not null,
          message text,
          image text,
          link text,
          read integer default 0
        );
        ''');
    }, version: 1);
    if (fillWithNotifications) {
      await _insertDummyNotifications();
    }
    return _db!;
  }

  Future<int> store(NotificationUI notification) async {
    final Database db = await initDB();
    return db.rawInsert('''
        INSERT INTO $_table 
          (UUID, title, time, message, image, link, read)
        VALUES 
          (?, ?, ?, ?, ?, ?, ?)
        ''', <dynamic>[
      notification.uuid,
      notification.title,
      notification.time,
      notification.message,
      notification.image,
      notification.link,
      notification.read ? 1 : 0,
    ]);
  }

  Future<int> delete(int id) async {
    final Database db = await initDB();
    return db.delete(_table, where: '_id = ?', whereArgs: <int>[id]);
  }

  Future<int> deleteAll() async {
    final Database db = await initDB();
    return db.rawDelete('DELETE FROM $_table');
  }

  Future<int> markRead(int id, {required bool isRead}) async {
    if (isTest) return -1;
    int read = 0;
    if (isRead) read = 1;
    final Database db = await initDB();
    return db
        .rawUpdate('UPDATE $_table SET read=? WHERE _id=?', <int>[read, id]);
  }

  Future<int> markAllRead() async {
    final Database db = await initDB();
    return db.rawUpdate('UPDATE $_table SET read=?', <int>[1]);
  }

  Future<List<NotificationUI>> getAll() async {
    final List<NotificationUI> notifications =
        List<NotificationUI>.empty(growable: true);
    final Database db = await initDB();

    final List<Map<String, dynamic>> rows = await db.rawQuery('''
    SELECT * FROM notifications ORDER BY _id DESC''');

    for (int i = 0; i < rows.length; i++) {
      bool isRead = false;
      if (rows[i]['read'] == 1) {
        isRead = true;
      }

      notifications.add(NotificationUI(
        id: rows[i]['_id'] as int,
        uuid: rows[i]['UUID'] as String,
        time: rows[i]['time'] as String,
        title: rows[i]['title'] as String,
        message: rows[i]['message'] as String,
        image: rows[i]['image'] as String,
        link: rows[i]['link'] as String,
        read: isRead,
      ));
    }
    return notifications;
  }

  Future<void> _insertDummyNotifications() async {
    DateTime now = DateTime.now().toUtc();

    await store(NotificationUI(
      id: 1,
      uuid: Uuid().v4(),
      title: 'Backup Finished',
      message: 'Took 512 seconds',
      time: now.subtract(Duration(days: 5)).toString(),
    ));

    await store(NotificationUI(
      id: 2,
      uuid: Uuid().v4(),
      title: 'Sensor Alert!',
      message: 'Activity By The Front 🚪',
      time: now.subtract(Duration(days: 1)).toString(),
    ));

    await store(NotificationUI(
      id: 3,
      uuid: Uuid().v4(),
      title: 'Server Login',
      message: 'IP: 35.177.218.15 (London)',
      read: true,
      time: now.subtract(Duration(days: 2)).toString(),
    ));

    await store(NotificationUI(
      id: 4,
      uuid: Uuid().v4(),
      title: 'RTX back in stock',
      message: '£719.99',
      link: 'https://www.currys.co.uk/',
      time: now.subtract(Duration(minutes: 50)).toString(),
    ));

    await store(NotificationUI(
      id: 5,
      uuid: Uuid().v4(),
      title: 'Quote from Edward Snowden',
      message:
          // ignore: lines_longer_than_80_chars
          'Nothing to hide argument: "Arguing that you don\'t care about the right to privacy because you have nothing to hide is no different than saying you don\'t care about free speech because you have nothing to say." - Edward Snowden.',
      time: now.subtract(Duration(minutes: 10)).toString(),
    ));

    await store(NotificationUI(
      id: 6,
      uuid: Uuid().v4(),
      title: 'BTC @ £50,000',
      time: now.subtract(Duration(minutes: 2)).toString(),
    ));

    await store(NotificationUI(
      id: 7,
      uuid: Uuid().v4(),
      title: 'Daily Logo Inspiration',
      message: 'notifi Logo',
      image: 'https://notifi.it/images/logo.png',
      time: now.subtract(Duration(minutes: 1)).toString(),
    ));

    await store(NotificationUI(
      id: 8,
      uuid: Uuid().v4(),
      title: 'Juventus 3 Inter 0',
      message: 'MOTM: Chiesa',
      read: true,
      time: now.subtract(Duration(milliseconds: 10)).toString(),
    ));
  }
}
