import 'package:akar_icons_flutter/akar_icons_flutter.dart';
import 'package:flutter/material.dart';
import 'package:notifi/user.dart';
import 'package:notifi/utils/pallete.dart';
import 'package:provider/provider.dart';

Future<void> showAlert(BuildContext context, String title, String description,
    {required VoidCallback onOkPressed, int? duration, int? gravity}) {
  return showDialog<void>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Column(children: <Widget>[
          Container(
            padding: const EdgeInsets.only(bottom: 10.0),
            child: Icon(
              AkarIcons.triangle_alert,
              color: Theme.of(context).colorScheme.secondary,
              size: 40,
            ),
          ),
          Text(
            title,
            textAlign: TextAlign.left,
          )
        ]),
        content: Text(description),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text(
              'Cancel',
              style: TextStyle(color: MyColour.grey),
            ),
          ),
          TextButton(
              onPressed: onOkPressed,
              child: const Text(
                'Ok',
                key: Key('ok'),
                style: TextStyle(
                    color: MyColour.black, fontWeight: FontWeight.w900),
              )),
        ],
      );
    },
  );
}

void showAlertSnackBar(BuildContext context, String message) {
  final SnackBar snackBar = SnackBar(
      duration: const Duration(days: 1),
      backgroundColor: MyColour.transparent,
      elevation: 0,
      content: Listener(
        onPointerDown: (_) async {
          await Provider.of<User>(context, listen: false).initWSS();
          ScaffoldMessenger.of(context).removeCurrentSnackBar();
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(5.0),
              decoration: const BoxDecoration(
                color: MyColour.black,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: <Widget>[
                  const Icon(
                    AkarIcons.triangle_alert,
                    color: MyColour.white,
                    size: 13,
                  ),
                  Text(' $message',
                      style: const TextStyle(
                          color: MyColour.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w400)),
                ],
              ),
            ),
          ],
        ),
      ));
  ScaffoldMessenger.of(context).showSnackBar(snackBar);
}
