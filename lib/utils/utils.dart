import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_emoji/flutter_emoji.dart';
import 'package:local_auth/local_auth.dart';
import 'package:notifi/utils/pallete.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart' as i;

const MethodChannel platform = MethodChannel('max.me.uk/notifications');
const String refKey = 'ref';
const String messageKey = 'msg';
final EmojiParser eParser = EmojiParser();

class Globals {
  static bool isIntegration = false;
}

bool get isTest {
  return Platform.environment.containsKey('FLUTTER_TEST');
}

Future<dynamic> invokeMacMethod(String method, [dynamic arguments]) async {
  if (Platform.isMacOS && !isTest) {
    try {
      return await platform.invokeMethod(method, arguments);
    } on PlatformException catch (e) {
      L.e("Failed to invoke method ($method): '${e.message}'.");
    }
  }
}

String currentIcon = '';
bool hasErr = false;

class MenuBarIcon {
  static Future<void> set(String icon) async {
    if (!hasErr) {
      await invokeMacMethod('${icon}_menu_icon');
    }
    if (icon != 'error') currentIcon = icon;
  }

  static Future<void> setErr() async {
    await set('error');
    hasErr = true;
  }

  static Future<void> revertErr() async {
    hasErr = false;
    String icon = currentIcon;
    if (currentIcon.isEmpty) icon = 'grey';
    await set(icon);
  }
}

Future<bool> loadDotEnv() async {
  if (isTest) {
    await dotenv.load();
    return true;
  } else {
    await dotenv.load();
    return dotenv.isEveryDefined(
        <String>['HOST', 'WS_HOST', 'KEY_STORE', 'TLS', 'SERVER_KEY', 'DEV']);
  }
}

String get wsEndpoint {
  return 'wss://${dotenv.env['WS_HOST']}/';
}

String get codeEndpoint {
  return '$httpEndpoint/code';
}

String get versionEndpoint {
  String develop = '';
  if (dotenv.env['DEV'] == 'true') {
    develop = '?develop';
  }
  return '$httpEndpoint/version$develop';
}

String get httpEndpoint {
  String protocol = 'http://';
  if (dotenv.env['TLS'] == 'true') {
    protocol = 'https://';
  }
  return '$protocol${dotenv.env['HOST']}';
}

Future<void> openUrl(String url) async {
  if (await canLaunchUrl(Uri.parse(url))) {
    await invokeMacMethod('close_window');
    await launchUrl(Uri.parse(url));
  } else {
    L.w("Can't open: $url");
  }
}

void showToast(String msg, BuildContext context,
    {int? duration, int? gravity}) {
  Fluttertoast.showToast(
      msg: msg,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Colors.black,
      textColor: Colors.white,
      fontSize: 16.0);
}

Future<String> getDeviceUUID() async {
  if (Platform.isLinux || Globals.isIntegration) {
    return Uuid().v4();
  }
  return platform
      .invokeMethod<String>('UUID')
      .then((String? value) => value.toString());
}

bool get shouldUseFirebase {
  return Platform.isIOS || Platform.isAndroid;
}

class L {
  static void d(String msg) {
    _print(msg);
  }

  static void i(String msg) {
    _print(msg);
  }

  static void w(String msg) {
    _print(msg);
  }

  static void e(String msg) {
    _print(msg);
  }

  static void _print(String msg) {
    // ignore: avoid_print
    print(DateTime.now().toString() + ': ' + msg);
  }
}

bool shouldPinWindow(SharedPreferences sp) {
  try {
    return sp.getBool('pin-window') ?? false;
  } catch (_) {
    return false;
  }
}

Future<void> copyText(String text, BuildContext context) async {
  await Clipboard.setData(ClipboardData(text: text));
  Fluttertoast.showToast(msg: '📋 $text', gravity: ToastGravity.BOTTOM);
}

bool hasTextOverflow(String text, TextStyle style,
    {double maxWidth = double.infinity, int maxLines = 1}) {
  final TextPainter textPainter = TextPainter(
    text: TextSpan(text: text, style: style),
    maxLines: maxLines,
    textDirection: TextDirection.ltr,
    textWidthBasis: TextWidthBasis.longestLine,
  )..layout(maxWidth: maxWidth);
  // not really sure why I have to -1
  return textPainter.didExceedMaxLines;
}

String getEclipsedText(String text, TextStyle style,
    {double maxWidth = double.infinity, int maxLines = 1}) {
  for (int i = 5; i < text.length; i++) {
    final String eclipsedText = '${text.substring(0, i)}...';
    if (hasTextOverflow(eclipsedText, style,
        maxWidth: maxWidth - 1, maxLines: maxLines)) {
      return '${text.substring(0, i - 1)}...';
    }
  }
  throw Exception('width too short to eclipse');
}

double windowWidth(BuildContext context) {
  return MediaQuery.of(context).size.width;
}

Future<String> getFirebaseToken() async {
  try {
    return await FirebaseMessaging.instance.getToken() ?? '';
  } catch (e) {
    L.e(e.toString());
  }
  return '';
}

Future<Directory> _getHomeDir() async {
  Directory dir = await getApplicationSupportDirectory();
  return dir.parent.parent.parent;
}

Future<File> getOpenOnLinuxLoginSnapDesktopFilePath() async {
  Directory userDir = await _getHomeDir();
  final Directory userDataPath =
      Directory(join(userDir.path, '.config/autostart/')).absolute;
  return File(join(userDataPath.path, 'notifi.desktop'));
}

Future<bool> linuxDoesAutoLogin() async {
  File path = await getOpenOnLinuxLoginSnapDesktopFilePath();
  // ignore: avoid_slow_async_io
  return path.exists();
}

bool isTablet() {
  final MediaQueryData data = MediaQueryData.fromView(
      WidgetsBinding.instance.platformDispatcher.views.first);
  return data.size.shortestSide > 600;
}

Future<bool> authentication(String msg) async {
  if (Globals.isIntegration || !(Platform.isAndroid || Platform.isIOS)) {
    return true;
  }
  LocalAuthentication localAuth = LocalAuthentication();
  return localAuth.authenticate(localizedReason: msg);
}

TextTheme getTextTheme() {
  double defaultFontSize = 14;
  double bodyText1FontSize = 12;
  double subtitle1FontSize = 10;
  if (Platform.isIOS || Platform.isAndroid) {
    defaultFontSize = 17;
    bodyText1FontSize = 14;
    subtitle1FontSize = 12;
    if (isTablet()) {
      defaultFontSize = 30;
      bodyText1FontSize = 25;
      subtitle1FontSize = 18;
    }
  }
  return TextTheme(
      displayLarge: TextStyle(
          inherit: false,
          textBaseline: TextBaseline.alphabetic,
          fontFamily: 'Inconsolata',
          fontSize: defaultFontSize,
          fontWeight: FontWeight.w600),
      titleMedium: TextStyle(
          color: MyColour.grey,
          fontSize: subtitle1FontSize,
          fontFamily: 'Inconsolata'),
      bodyLarge: TextStyle(
          inherit: false,
          textBaseline: TextBaseline.alphabetic,
          fontFamily: 'Inconsolata',
          color: MyColour.darkGrey,
          fontSize: bodyText1FontSize,
          letterSpacing: 0.2,
          height: 1.2),
      bodyMedium: TextStyle(
          fontSize: defaultFontSize,
          color: MyColour.black,
          fontWeight: FontWeight.w500,
          inherit: false,
          textBaseline: TextBaseline.alphabetic,
          fontFamily: 'Inconsolata'));
}

String getOperatingSystemName() {
  if (Globals.isIntegration) {
    return '${Platform.operatingSystem}-integration';
  }
  return Platform.operatingSystem;
}

DateTime stringToTime(String time) {
  return i.DateFormat('yyyy-MM-dd HH:mm:ss').parse(time, true).toLocal();
}
