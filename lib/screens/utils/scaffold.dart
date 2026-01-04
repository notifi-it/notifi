import 'dart:io';
import 'package:flutter/material.dart';
import 'package:notifi/notifications/notifis.dart';
import 'package:notifi/screens/utils/animated_cnt.dart';
import 'package:notifi/utils/pallete.dart';
import 'package:provider/provider.dart';

class MyScaffold extends StatelessWidget {
  const MyScaffold(
      {Key? key, this.leading, this.body, this.bottomNavigationBar})
      : super(key: key);

  final Widget? leading;
  final Widget? body;
  final Widget? bottomNavigationBar;

  @override
  Widget build(BuildContext context) {
    double paddingTop = MediaQuery.of(context).padding.top;
    if (MediaQuery.of(context).padding.top > 0 && Platform.isIOS) {
      paddingTop = MediaQuery.of(context).padding.top - 20;
    }
    double paddingBottom = 0;
    if (MediaQuery.of(context).padding.bottom > 0) {
      paddingBottom = MediaQuery.of(context).padding.bottom / 2;
    }

    return MediaQuery.removePadding(
        removeTop: MediaQuery.of(context).padding.top > 0,
        removeBottom: true,
        context: context,
        child: Container(
            color: MyColour.white,
            padding: EdgeInsets.only(top: paddingTop, bottom: paddingBottom),
            child: Scaffold(
                appBar: AppBar(
                  toolbarHeight: 70,
                  automaticallyImplyLeading: false,
                  shape: Border(
                      bottom:
                          BorderSide(color: Theme.of(context).indicatorColor)),
                  title: Padding(
                    padding: const EdgeInsets.only(right: 56),
                    child: Stack(
                      alignment: Alignment.center,
                      children: <Widget>[
                        Container(
                          alignment: const Alignment(0, 0),
                          child: GestureDetector(
                            onTap: () {
                              Provider.of<Notifications>(context, listen: false)
                                  .scrollToTop();
                            },
                            child: Image.asset('images/bell.png', height: 50),
                          ),
                        ),
                        Positioned(
                          top: 0,
                          child: Container(
                              padding: const EdgeInsets.only(left: 21.4),
                              child: const AnimatedCnt()),
                        ),
                      ],
                    ),
                  ),
                  leading: leading,
                ),
                body: body,
                bottomNavigationBar: bottomNavigationBar)));
  }
}
