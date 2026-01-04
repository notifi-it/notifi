import 'dart:io' show File, Platform;

import 'package:akar_icons_flutter/akar_icons_flutter.dart';
import 'package:launch_review/launch_review.dart';
import 'package:app_settings/app_settings.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:notifi/notifications/notifications_table.dart';
import 'package:notifi/screens/utils/alert.dart';
import 'package:notifi/screens/utils/scaffold.dart';
import 'package:notifi/user.dart';
import 'package:notifi/utils/pallete.dart';
import 'package:notifi/utils/utils.dart';
import 'package:notifi/utils/version.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:url_launcher/url_launcher.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  SettingsScreenState createState() => SettingsScreenState();
}

class SettingsScreenState extends State<SettingsScreen> {
  late ValueNotifier<String> _versionString;
  late ValueNotifier<bool> _hasUpgrade;

  @override
  void initState() {
    _versionString = ValueNotifier<String>('');
    _hasUpgrade = ValueNotifier<bool>(false);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    if (!isTest) {
      PackageInfo.fromPlatform().then((PackageInfo package) {
        if (Platform.isMacOS || Platform.isLinux) {
          _versionString.value = package.version;
        } else {
          _versionString.value = '${package.version} (${package.buildNumber})';
        }
        hasUpgrade(package.version).then((bool hasUpgrade) {
          _hasUpgrade.value = hasUpgrade;
        });
      });
    }

    Widget bottomNavigationBar = SizedBox();
    if (Platform.isMacOS || Platform.isLinux) {
      bottomNavigationBar = Container(
          padding: const EdgeInsets.only(bottom: 5),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              TextButton(
                onPressed: () {
                  SystemNavigator.pop();
                },
                child: Icon(
                  AkarIcons.sign_out,
                  color: MyColour.black,
                  size: 25,
                ),
              ),
            ],
          ));
    }

    IconData otherPlatformsIcon = AkarIcons.laptop_device;
    if (Platform.isLinux || Platform.isMacOS) {
      otherPlatformsIcon = AkarIcons.mobile_device;
    }

    return MyScaffold(
        leading: IconButton(
            key: Key('back-button'),
            icon: const Icon(AkarIcons.chevron_left),
            onPressed: () {
              Navigator.pop(context);
            }),
        body: Column(children: <Widget>[
          Consumer<User>(
              builder: (BuildContext context, User user, Widget? child) {
            final String credentials = user.getCredentials();

            SettingOption credentialsSettingWidget =
                SettingOption('Copy Credentials', AkarIcons.clipboard,
                    onTapCallback: () async {
              await copyText(credentials, context);
            });
            if (Platform.isIOS || Platform.isAndroid) {
              credentialsSettingWidget =
                  SettingOption('Share Credentials', AkarIcons.share_box,
                      onTapCallback: () async {
                // ignore: deprecated_member_use
                await Share.share('$credentials ');
              });
            }

            return Column(children: <Widget>[
              SettingOption(
                  'How Do I Receive Notifications?', AkarIcons.question,
                  onTapCallback: () async {
                await openUrl('$httpEndpoint?c=$credentials#how-to');
              }),
              credentialsSettingWidget
            ]);
          }),
          SettingOption('Create New Credentials', AkarIcons.arrow_clockwise,
              key: Key('new-credentials'), onTapCallback: () {
            showAlert(
                context,
                'Replace Credentials?',
                'Are you sure? You will never be able to use your '
                    'current credentials again!', onOkPressed: () async {
              if (await authentication(
                  'Please authenticate to replace credentials')) {
                final bool gotUser =
                    await Provider.of<User>(context, listen: false)
                        .setNewUser();
                Navigator.pop(context);
                if (!gotUser) {
                  showToast(
                      'Problem fetching new credentials. '
                      'Please try again later...',
                      context);
                }
              }
            });
          }),
          if (Platform.isIOS)
            SettingOption('iOS App Settings...', AkarIcons.gear,
                onTapCallback: () => AppSettings.openAppSettings(
                    type: AppSettingsType.notification)),
          SettingOption('About...', AkarIcons.info,
              onTapCallback: () => openUrl('https://notifi.it')),
          SettingOption('Other Platforms...', otherPlatformsIcon,
              onTapCallback: () => openUrl('$httpEndpoint#downloads')),
          if (Platform.isAndroid || Platform.isIOS)
            SettingOption('Review app...', AkarIcons.star,
                onTapCallback: () => LaunchReview.launch(
                      androidAppId: 'it.notifi.notifi',
                      iOSAppId: '1563961135',
                    )),
          if (Platform.isLinux)
            Container(
              padding: const EdgeInsets.only(top: 5),
              child: FutureBuilder<bool>(
                  future: linuxDoesAutoLogin(),
                  builder: (BuildContext context, AsyncSnapshot<bool> f) {
                    if (f.connectionState == ConnectionState.none) {
                      return const CircularProgressIndicator();
                    }
                    return SettingOption(
                      'Open notifi at Login',
                      AkarIcons.person,
                      switchValue: f.data ?? false,
                      switchCallback: (_) async {
                        File desktopPath =
                            await getOpenOnLinuxLoginSnapDesktopFilePath();
                        File localSnapDesktopPath =
                            File('snap/gui/notifi.desktop');
                        if (f.data ?? false) {
                          await desktopPath.delete();
                        } else {
                          localSnapDesktopPath.copy(desktopPath.path);
                        }
                        setState(() {});
                      },
                    );
                  }),
            ),
          if (Platform.isMacOS)
            FutureBuilder<SharedPreferences>(
                future: SharedPreferences.getInstance(),
                // ignore: always_specify_types
                builder: (BuildContext context, AsyncSnapshot f) {
                  if (f.connectionState == ConnectionState.none ||
                      f.data == null) {
                    return const CircularProgressIndicator();
                  }
                  final SharedPreferences sp = f.data as SharedPreferences;
                  return SettingOption(
                    'Pin window',
                    AkarIcons.pin,
                    switchValue: shouldPinWindow(sp),
                    switchCallback: (bool shouldPin) async {
                      final bool success = await invokeMacMethod(
                          'set-pin-window',
                          <String, bool>{'transient': !shouldPin}) as bool;
                      if (success) {
                        sp.setBool('pin-window', shouldPin);
                      }
                      setState(() {});
                    },
                  );
                }),
          Container(
            padding: const EdgeInsets.only(top: 30),
            child: RichText(
                textAlign: TextAlign.center,
                text: TextSpan(children: <InlineSpan>[
                  const TextSpan(
                    text: 'Made by \n',
                    style: TextStyle(
                        color: MyColour.grey,
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                        fontFamily: 'Inconsolata'),
                  ),
                  MouseRegionSpan(
                      mouseCursor: SystemMouseCursors.click,
                      inlineSpan: TextSpan(
                        text: 'Maximilian Mitchell',
                        style: const TextStyle(
                            color: MyColour.darkGrey,
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                            fontFamily: 'Inconsolata'),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () {
                            launchUrl(Uri.parse('https://max.me.uk'));
                          },
                      )),
                ])),
          ),
          if (!isTest)
            ValueListenableBuilder<String>(
                valueListenable: _versionString,
                builder: (BuildContext context, String version, Widget? child) {
                  return Container(
                    padding: const EdgeInsets.only(top: 10),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Text('version: $version',
                            style: const TextStyle(
                                color: MyColour.grey, fontSize: 12)),
                        if (Platform.isMacOS)
                          ValueListenableBuilder<bool>(
                              valueListenable: _hasUpgrade,
                              builder: (BuildContext context, bool hasUpgrade,
                                  Widget? child) {
                                if (hasUpgrade) {
                                  return TextButton(
                                      onPressed: () {
                                        invokeMacMethod('update');
                                      },
                                      child: Icon(
                                        AkarIcons.cloud_download,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .secondary,
                                        size: 18,
                                      ));
                                }
                                return const SizedBox();
                              })
                      ],
                    ),
                  );
                }),
        ]),
        bottomNavigationBar: bottomNavigationBar);
  }
}

// ignore: must_be_immutable
class SettingOption extends StatelessWidget {
  SettingOption(this.text, this.icon,
      {Key? key,
      this.onTapCallback,
      this.switchCallback,
      this.switchValue = false})
      : super(key: key);

  final String text;
  final IconData icon;
  final GestureTapCallback? onTapCallback;
  final ValueChanged<bool>? switchCallback;
  final bool switchValue;

  @override
  Widget build(BuildContext context) {
    final Container iconWidget = Container(
        padding: const EdgeInsets.only(right: 15),
        child: Icon(icon, size: 23, color: MyColour.black));

    double verticalPadding = 0;
    if (Platform.isLinux || Platform.isMacOS) verticalPadding = 13;
    Widget setting;
    // switchValue ??= false;
    setting = Container(
        padding: EdgeInsets.only(left: 16, right: 7, top: verticalPadding),
        child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Row(children: <Widget>[
                iconWidget,
                Text(text, style: Theme.of(context).textTheme.bodyMedium)
              ]),
              Switch(
                  value: switchValue,
                  onChanged: switchCallback,
                  activeThumbColor: Theme.of(context).colorScheme.secondary)
            ]));
    return setting;
  }
}
