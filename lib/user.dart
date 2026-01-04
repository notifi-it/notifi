import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart' as d;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:notifi/notifications/notification.dart';
import 'package:notifi/notifications/notifis.dart';
import 'package:notifi/screens/utils/alert.dart';
import 'package:notifi/utils/local_notifications.dart';
import 'package:notifi/utils/utils.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'package:path/path.dart';

class User with ChangeNotifier {
  User(this._notifications, this._pushNotifications) {
    _user = UserStruct();
    setNotifications(_notifications);
  }

  late UserStruct _user;
  String? flutterToken;
  IOWebSocketChannel? _ws;
  late BuildContext _snackContext;

  Notifications _notifications;

  final FlutterLocalNotificationsPlugin? _pushNotifications;

  // ignore: use_setters_to_change_properties
  void setNotifications(Notifications _notifications) {
    this._notifications = _notifications;
  }

  String getCredentials() {
    return _user.credentials ?? '';
  }

  Future<void> loadUser() async {
    _user = UserStruct();
    final bool hadUser = await _user.load();

    // create new credentials if any are missing
    while (_user.isNull()) {
      // Create new credentials as the user does not have any.
      await setNewUser();

      setErr(hasErr: _user.isNull());
      if (_user.isNull()) {
        L.w('Attempting to create user again...');
        await Future<dynamic>.delayed(const Duration(seconds: 5));
      }
    }

    notifyListeners();

    if (hadUser && !isTest) {
      await initWSS();
    }
  }

  Future<bool> setNewUser() async {
    Map<String, dynamic> postData = <String, String>{};

    if (!_user.isNull()) {
      postData['UUID'] = _user.uuid;
      postData['current_credential_key'] = _user.credentialKey;
      postData['current_credentials'] = _user.credentials;
      if (shouldUseFirebase) {
        postData['firebase_token'] = await getFirebaseToken();
      }
      L.w('Replacing credentials: ${_user.credentials}');
    } else {
      postData['UUID'] = await getDeviceUUID();
    }

    final UserStruct newUser = await _newUserReq(postData);
    if (!newUser.isNull()) {
      // store user credentials
      if (await newUser.store()) {
        _user = newUser;
        notifyListeners();

        initWSS();
      }
    }
    return !newUser.isNull();
  }

  ////////
  // ws //
  ////////
  Future<void> initWSS({bool shouldDelay = false}) async {
    await closeWS(shouldDelay: shouldDelay);
    await connectToWS();
    _ws!.sink.add('.');
  }

  Future<void> connectToWS() async {
    final PackageInfo package = await PackageInfo.fromPlatform();
    final Map<String, dynamic> headers = <String, dynamic>{
      'Sec-Key': dotenv.env['SERVER_KEY'],
      'Uuid': _user.uuid,
      'Credentials': _user.credentials,
      'Key': _user.credentialKey,
      'Version': package.version,
      'OS': getOperatingSystemName(),
    };

    if (shouldUseFirebase) {
      headers['Firebase-Token'] = await getFirebaseToken();
    }

    L.i('Connecting to WS...');
    _ws = IOWebSocketChannel.connect(wsEndpoint,
        headers: headers, pingInterval: const Duration(seconds: 3));

    setErr(hasErr: false);
    bool _hasError = true;
    _ws!.stream.listen((dynamic streamData) async {
      _hasError = false;
      final List<String> notificationUUIDs = await _handleMessage(streamData);
      // confirm received UUIDs with server in chunks
      int chunkSize = 20;
      int numUUIDs = notificationUUIDs.length;
      for (int i = 0; i < numUUIDs; i += chunkSize) {
        int end = (i + chunkSize < numUUIDs) ? i + chunkSize : numUUIDs;
        _ws!.sink.add(jsonEncode(notificationUUIDs.sublist(i, end)));
      }
      // ignore: always_specify_types
    }, onError: (e) async {
      _hasError = true;
      L.w('Problem with WS: $e');
    }, onDone: () async {
      L.i('WS connection closed. ${_user.credentials}');
      setErr(hasErr: _hasError);
      await initWSS(shouldDelay: _hasError);
    }, cancelOnError: false);
  }

  Future<void> closeWS({bool shouldDelay = false}) async {
    L.i('Closing already open WS...');
    _ws!.sink.close(status.normalClosure, 'new code!');
    _ws = null;
    await Future<dynamic>.delayed(Duration(seconds: shouldDelay ? 10 : 2));
  }

  Future<UserStruct> _newUserReq(Map<String, dynamic> data) async {
    L.i('Creating new credentials...');
    final d.Dio dio = d.Dio();
    Response<dynamic> response;
    try {
      response = await dio.post(codeEndpoint,
          data: data,
          options: d.Options(headers: <String, dynamic>{
            'Sec-Key': dotenv.env['SERVER_KEY'],
          }, contentType: d.Headers.formUrlEncodedContentType));
    } on DioException catch (e, _) {
      // ignore: always_specify_types
      final d.Response? resp = e.response;
      L.e('Problem fetching user code: ${resp?.statusCode} ${resp}');
      return UserStruct();
    }

    if (response.statusCode != HttpStatus.ok) {
      L.e('Problem fetching new code from server: $response');
      return UserStruct();
    }

    // decode response
    Map<String, dynamic> credentialsMap;
    try {
      credentialsMap =
          json.decode(response.data as String) as Map<String, dynamic>;
    } catch (e) {
      L.e('Problem decoding new code from server: $e - ${response}');
      return UserStruct();
    }

    return UserStruct(
      uuid: data['UUID'] as String,
      credentials: credentialsMap['credentials'] as String,
      credentialKey: credentialsMap['credential_key'] as String,
    );
  }

  Future<List<String>> _handleMessage(dynamic msg) async {
    setErr(hasErr: false);

    // json decode incoming ws message
    List<dynamic> notifications = <dynamic>[];
    try {
      notifications = json.decode(msg as String) as List<dynamic>;
    } catch (e) {
      L.e('Ignoring un-parsable incoming message from server: $msg: $e');
      return <String>[];
    }

    // parse notifications from websocket message
    final List<String> msgUUIDs = <String>[];
    NotificationUI? lastNotification;
    int lastID = -1;
    for (int i = 0; i < notifications.length; i++) {
      Map<String, dynamic> jsonMessage;
      try {
        jsonMessage =
            Map<String, dynamic>.from(notifications[i] as Map<String, dynamic>);
      } catch (e) {
        L.e('Ignoring un-parsable WS message: $msg: $e');
        return <String>[];
      }

      final NotificationUI notification = NotificationUI.fromJson(jsonMessage);

      // store notification
      final int id = await _notifications.add(notification);

      lastNotification = notification;
      lastID = id;

      msgUUIDs.add(notification.uuid);
    }

    if (lastID != -1) {
      // send push notification
      if (!Platform.isAndroid && _pushNotifications != null) {
        sendLocalNotification(_pushNotifications!, lastID, lastNotification!);
      }

      _notifications.scrollToTop();

      // animate in notification
      if (_notifications.tableKey.currentState != null) {
        for (int i = 0; i < msgUUIDs.length; i++) {
          if (i == msgUUIDs.length - 1) {
            _notifications.tableKey.currentState
                ?.insertItem(0, duration: const Duration(seconds: 1));
          } else {
            _notifications.tableKey.currentState?.insertItem(0);
          }
        }
      }
      _notifications.setUnreadCnt();

      // animate menu bar icon
      invokeMacMethod('animate');
    }
    return msgUUIDs;
  }

  // ignore: use_setters_to_change_properties
  void setSnackContext(BuildContext context) {
    _snackContext = context;
  }

  bool _tmpErr = false;

  void setErr({required bool hasErr}) {
    // wait for 1 second to make sure hasErr hasn't changed.
    // To prevent from stuttering.
    _tmpErr = hasErr;
    Future<dynamic>.delayed(const Duration(seconds: 2), () {
      if (_tmpErr == hasErr) {
        if (_tmpErr) {
          MenuBarIcon.setErr();
          showAlertSnackBar(_snackContext, 'Network Error! Tap to try again.');
        } else {
          MenuBarIcon.revertErr();
          ScaffoldMessenger.of(_snackContext).clearSnackBars();
        }
      }
    });
  }
}

class UserStruct {
  UserStruct({this.uuid, this.credentialKey, this.credentials}) {
    if (!Platform.isLinux) {
      _storage = const FlutterSecureStorage();
      if (!isTest) _key = 'notifi-${dotenv.env['KEY_STORE']}';
    }
  }

  FlutterSecureStorage? _storage;
  late String _key;

  String? uuid;
  String? credentialKey;
  String? credentials;

  bool isNull() {
    return credentialKey == null;
  }

  Future<bool> store() async {
    if (Platform.isLinux) {
      Directory dir = await getApplicationSupportDirectory();
      File file = File(join(dir.path, '${_key}.txt'));
      file.writeAsString(_toJson());
      return true;
    }

    try {
      await _storage?.write(key: _key, value: _toJson());
    } catch (e) {
      L.e(e.toString());
      return false;
    }
    return true;
  }

  Future<bool> load() async {
    String userJsonString;

    if (Platform.isLinux) {
      Directory dir = await getApplicationSupportDirectory();
      File file = File(join(dir.path, '${_key}.txt'));
      try {
        userJsonString = await file.readAsString();
      } catch (_) {
        return false;
      }
    } else {
      try {
        userJsonString = (await _storage?.read(key: _key))!;
      } catch (e) {
        L.e(e.toString());
        return false;
      }
    }

    try {
      final Map<String, dynamic> userJson =
          jsonDecode(userJsonString) as Map<String, dynamic>;

      uuid = userJson['UUID'] as String;
      credentials = userJson['credentials'] as String;
      credentialKey = userJson['credentialKey'] as String;
    } catch (error) {
      L.e(error.toString());
      return false;
    }
    return true;
  }

  String _toJson() {
    if (isNull()) throw 'Cannot encode unset user';
    return jsonEncode(<String, String>{
      'UUID': uuid!,
      'credentials': credentials!,
      'credentialKey': credentialKey!,
    });
  }
}
