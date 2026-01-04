import 'dart:async';
import 'dart:io';

import 'package:akar_icons_flutter/akar_icons_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as i;
import 'package:json_annotation/json_annotation.dart';
import 'package:notifi/notifications/notifis.dart';
import 'package:notifi/utils/pallete.dart';
import 'package:notifi/utils/utils.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;

@JsonSerializable()
// ignore: must_be_immutable
class NotificationUI extends StatefulWidget {
  NotificationUI(
      {required this.uuid,
      required this.time,
      required this.title,
      this.message = '',
      this.image = '',
      this.link = '',
      this.id = -1,
      this.read = false,
      this.canExpand = false})
      : super(key: Key('notification')) {
    dttmTime = i.DateFormat('yyyy-MM-dd HH:mm:ss').parse(time, true).toLocal();
  }

  factory NotificationUI.fromJson(Map<String, dynamic> json) =>
      _$NotificationFromJson(json);

  final String uuid;
  final String time;
  final String title;
  String message;
  String image;
  String link;
  int id;
  bool read;
  bool canExpand;
  bool isExpanded = false;
  late int index;
  late DateTime dttmTime;
  late void Function(BuildContext context, int id) toggleExpand;
  late String shrinkTitle;
  late String shrinkMessage;

  bool get isRead => read;

  Map<String, dynamic> toJson() => _$NotificationToJson(this);

  @override
  NotificationUIState createState() => NotificationUIState();
}

NotificationUI _$NotificationFromJson(Map<String, dynamic> json) {
  return NotificationUI(
      id: json['id'] as int,
      uuid: json['UUID'] as String,
      time: json['time'] as String,
      title: eParser.emojify(json['title'] as String),
      message: eParser.emojify(json['message'] as String),
      image: json['image'] as String,
      link: json['link'] as String);
}

Map<String, dynamic> _$NotificationToJson(NotificationUI notification) =>
    <String, dynamic>{
      'id': notification.id,
      'title': notification.title,
      'time': notification.time,
      'message': notification.message,
      'image': notification.image,
      'link': notification.link,
      'read': notification.isRead,
    };

class NotificationUIState extends State<NotificationUI>
    with WidgetsBindingObserver {
  NotificationUIState();

  final GlobalKey _columnKey = GlobalKey();
  final GlobalKey _titleKey = GlobalKey();
  final GlobalKey _messageKey = GlobalKey();
  final ValueNotifier<String> _timeStr = ValueNotifier<String>('');
  Timer? timer;

  double iconSize = 15.0;

  @override
  void setState(VoidCallback fn) {
    if (mounted) {
      super.setState(fn);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _canExpandHandler(context));
    WidgetsBinding.instance.addObserver(this);
    timer = Timer.periodic(const Duration(minutes: 1), (Timer t) => _setTime());
  }

  @override
  void didChangeMetrics() {
    if (!isTest && mounted) _canExpandHandler(context);
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<Notifications>(builder:
        (BuildContext context, Notifications reloadTable, Widget? child) {
      String title = widget.title;
      String message = widget.message;
      int? messageMaxLines = 3;
      int? titleMaxLines = 1;

      _setTime();

      // if expanded notification
      if (widget.isExpanded) {
        titleMaxLines = null;
        messageMaxLines = null;
      } else {
        title = widget.shrinkTitle;
        message = widget.shrinkMessage;
      }

      // if read notification
      Color backgroundColour = Colors.white;
      Color titleColour = MyColour.black;
      if (widget.isRead) {
        backgroundColour = MyColour.offWhite;
        titleColour = MyColour.black;
      }

      // if message
      Widget messageRow;
      if (widget.message != '') {
        messageRow = Row(key: _messageKey, children: <Widget>[
          Flexible(
              child: SelectableText(message, onTap: () {
            setState(() {
              if (!widget.isExpanded) {
                widget.toggleExpand(context, widget.index);
              }
            });
          },
                  scrollPhysics: const NeverScrollableScrollPhysics(),
                  style: Theme.of(context).textTheme.bodyLarge!,
                  minLines: 1,
                  maxLines: messageMaxLines)),
        ]);
      } else {
        messageRow = const SizedBox();
      }

      // if link
      Widget? linkBtn;
      if (widget.link != '') {
        linkBtn = InkWell(
            onTap: () async {
              await openUrl(widget.link);
              setState(() {
                Provider.of<Notifications>(context, listen: false)
                    .markRead(widget.index, isRead: true);
              });
            },
            onLongPress: () {
              showToast(widget.link, context);
            },
            child: Container(
                padding: const EdgeInsets.only(top: 7.0),
                child: Icon(
                  AkarIcons.link_chain,
                  size: iconSize,
                  color: MyColour.grey,
                )));
      }

      // if image
      Widget? image;
      if (widget.image != '') {
        image = MouseRegion(
          cursor: SystemMouseCursors.alias,
          child: GestureDetector(
              onTap: () async {
                await openUrl(widget.image);
                Provider.of<Notifications>(context, listen: false)
                    .markRead(widget.index, isRead: true);
              },
              child: Container(
                padding: const EdgeInsets.only(right: 10.0, top: 3.0),
                child: ClipRRect(
                    borderRadius: BorderRadius.circular(2.0),
                    child: CachedNetworkImage(
                        imageUrl: widget.image,
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                        errorWidget:
                            (BuildContext context, String url, dynamic error) {
                          return const SizedBox();
                        },
                        filterQuality: FilterQuality.medium)),
              )),
        );
      }

      const double padding = 10.0;

      double timePaddingBottom = 2;
      double timePaddingTop = 2;
      if (Platform.isIOS || Platform.isAndroid) {
        timePaddingBottom = 1;
        timePaddingTop = 4;
      }

      // NOTIFICATION
      final Container slideNotification = Container(
          color: Colors.transparent,
          padding: const EdgeInsets.only(
              left: padding, right: padding, top: padding),
          child: Container(
              decoration: BoxDecoration(
                  border: Border.all(
                      color: Theme.of(context).tabBarTheme.indicatorColor ??
                          Theme.of(context).primaryColor),
                  color: backgroundColour,
                  borderRadius:
                      const BorderRadius.all(Radius.circular(padding))),
              child: Container(
                  padding: const EdgeInsets.all(padding),
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Container(
                          padding: const EdgeInsets.only(right: padding),
                          child: SizedBox(
                            width: 15,
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  // mark as read
                                  InkWell(
                                      onTap: () {
                                        setState(() {
                                          Provider.of<Notifications>(context,
                                                  listen: false)
                                              .toggleRead(widget.index);
                                        });
                                      },
                                      child: Container(
                                          padding:
                                              const EdgeInsets.only(top: 2.0),
                                          child: Icon(
                                            AkarIcons.check,
                                            size: iconSize,
                                            color: MyColour.grey,
                                          ))),
                                  if (widget.canExpand)
                                    InkWell(
                                        key: Key('toggle-expand'),
                                        onTap: () {
                                          setState(() {
                                            widget.toggleExpand(
                                                context, widget.index);
                                          });
                                        },
                                        child: Container(
                                            padding:
                                                const EdgeInsets.only(top: 7.0),
                                            child: Icon(
                                              widget.isExpanded
                                                  ? AkarIcons.reduce
                                                  : AkarIcons.enlarge,
                                              size: iconSize,
                                              color: MyColour.grey,
                                            )))
                                  else
                                    Container(),
                                  if (linkBtn != null) linkBtn,
                                ]),
                          ),
                        ),
                        image ?? Container(),
                        Expanded(
                            child: SizedBox(
                          width: double.infinity,
                          child: Column(
                              key: _columnKey,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    // TITLE
                                    Expanded(
                                      child: SelectableText(title,
                                          key: _titleKey, onTap: () {
                                        setState(() {
                                          if (!widget.isExpanded) {
                                            widget.toggleExpand(
                                                context, widget.index);
                                          }
                                        });
                                      },
                                          scrollPhysics:
                                              // ignore: lines_longer_than_80_chars
                                              const NeverScrollableScrollPhysics(),
                                          style: (Theme.of(context)
                                                      .textTheme
                                                      .displayLarge ??
                                                  const TextStyle())
                                              .copyWith(color: titleColour),
                                          textAlign: TextAlign.left,
                                          minLines: 1,
                                          maxLines: titleMaxLines),
                                    ),
                                    if (Platform.isMacOS || Platform.isLinux)
                                      Padding(
                                          padding:
                                              const EdgeInsets.only(top: 2.0),
                                          child: InkWell(
                                            onTap: () {
                                              setState(() {
                                                Provider.of<Notifications>(
                                                        context,
                                                        listen: false)
                                                    .delete(widget.index);
                                              });
                                            },
                                            child:
                                                Icon(AkarIcons.cross, size: 10),
                                          )),
                                  ],
                                ),

                                // TIME
                                Padding(
                                  padding: EdgeInsets.only(
                                      top: timePaddingTop,
                                      bottom: timePaddingBottom),
                                  child: Row(children: <Widget>[
                                    ValueListenableBuilder<String>(
                                        valueListenable: _timeStr,
                                        builder: (BuildContext context,
                                            String timeStr, Widget? child) {
                                          return Expanded(
                                            child: SelectableText(timeStr,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .titleMedium ??
                                                  const TextStyle()),
                                          );
                                        })
                                  ]),
                                ),

                                // MESSAGE
                                messageRow
                              ]),
                        ))
                      ]))));
      return GestureDetector(
          onLongPress: () {
            setState(() {
              Provider.of<Notifications>(context, listen: false)
                  .toggleRead(widget.index);
            });
          },
          child: slideNotification);
    });
  }

  void _canExpandHandler(BuildContext context) {
    bool canExpand = false;

    // prevent check if can expand when window is scaling up
    if (Platform.isMacOS &&
        (_columnKey.currentContext?.size?.width ?? 0) <= 123) return;

    double maxWidth = _columnKey.currentContext?.size?.width ?? 0;
    // account for icon
    if (Platform.isMacOS || Platform.isLinux) maxWidth -= iconSize;

    final TextTheme textTheme = Theme.of(context).textTheme;
    if (_columnKey.currentContext != null &&
        textTheme.displayLarge != null &&
        maxWidth > 10 &&
        hasTextOverflow(widget.title, textTheme.displayLarge!,
            maxWidth: maxWidth)) {
      canExpand = true;
      widget.shrinkTitle = getEclipsedText(
          widget.title, textTheme.displayLarge!,
          maxWidth: maxWidth);
    } else {
      widget.shrinkTitle = widget.title;
    }

    if (_messageKey.currentContext != null &&
        widget.message != '' &&
        textTheme.bodyLarge != null &&
        (_messageKey.currentContext?.size?.width ?? 0) > 10 &&
        hasTextOverflow(widget.message, textTheme.bodyLarge!,
            maxWidth: _messageKey.currentContext?.size?.width ?? 0,
            maxLines: 3)) {
      canExpand = true;
      widget.shrinkMessage = getEclipsedText(
          widget.message, textTheme.bodyLarge!,
          maxWidth: _messageKey.currentContext?.size?.width ?? 0, maxLines: 3);
    } else {
      widget.shrinkMessage = widget.message;
    }

    widget.canExpand = canExpand;
    if (mounted) setState(() {});
  }

  void _setTime() {
    final String friendlyDttm =
        i.DateFormat('MMM d, y HH:mm:ss').format(widget.dttmTime);
    _timeStr.value = '$friendlyDttm - ${timeago.format(widget.dttmTime)}';
  }
}
