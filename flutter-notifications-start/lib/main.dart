import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:meetups/http/web.dart';
import 'package:meetups/models/device.dart';
import 'package:meetups/screens/events_screen.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

final navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  FirebaseMessaging messaging = FirebaseMessaging.instance;

  NotificationSettings settings = await messaging.requestPermission(
    alert: true,
    announcement: false,
    badge: true,
    carPlay: false,
    criticalAlert: false,
    provisional: false,
    sound: true,
  );

  if (settings.authorizationStatus == AuthorizationStatus.authorized) {
    print('Permissions granted ${settings.authorizationStatus}');
    _startPushNotificationHandler(messaging);
  } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
    print('Provisory permissions granted ${settings.authorizationStatus}');
    _startPushNotificationHandler(messaging);
  }

  runApp(App());
}

Future<void> _startPushNotificationHandler(FirebaseMessaging messaging) async {
  String? token = await messaging.getToken();
  print('TOKEN: $token');
  setPushToken(token);

  //foreground
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    print('Message received while the app was open');

    if (message.notification != null) {
      print(message.notification!.title);
    }
  });
  //background
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  //terminated
  var notification = await FirebaseMessaging.instance.getInitialMessage();
  if (notification!.data['message'].length > 0) {
    openDialog(notification.data['message']);
  }
}

void setPushToken(String? token) async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  String? prefsToken = prefs.getString('pushToken');
  bool? prefSent = prefs.getBool('tokenSent');

  if (prefsToken != token || (prefsToken == token && prefSent == false)) {
    print('Enviando pro Servidor');

    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    String? brand;
    String? model;

    if (Platform.isAndroid) {
      AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
      print('Device Info ${androidInfo.model}');
      model = androidInfo.model;
      brand = androidInfo.brand;
    }
    if (Platform.isIOS) {
      IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
      model = iosInfo.utsname.machine;
      brand = 'Apple';
    }
    Device device = Device(brand: brand, model: model, token: token);
    sendDevice(device);
  }
}

class App extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Dev meetups',
      home: EventsScreen(),
      navigatorKey: navigatorKey,
    );
  }
}

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('Message receive in background');
}

void openDialog(String message) {
  OutlinedButton okButton = OutlinedButton(
    onPressed: () => Navigator.pop(navigatorKey.currentContext!),
    child: Text('Ok'),
  );
  AlertDialog alert = AlertDialog(
    title: Text('Title'),
    content: Text(message),
    actions: [okButton],
  );

  showDialog(
      context: navigatorKey.currentContext!,
      builder: (BuildContext context) {
        return alert;
      });
}
