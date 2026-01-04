import 'package:flutter_driver/driver_extension.dart';
// ignore: avoid_relative_lib_imports
import '../lib/main.dart' as app;

void main() async {
  enableFlutterDriverExtension();
  await app.mainImpl(integration: true);
}
