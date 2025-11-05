import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io' show Platform;
import 'dart:typed_data';
import 'WelcomeScreen.dart';
import 'AuthenticationStudy.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/rendering.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

Future<void> _initNotifications() async {
  const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );
  
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  AndroidNotificationChannel channel = AndroidNotificationChannel(
    'questlog_reminders',
    'QuestLog Reminders',
    description: 'Notifications for quest start and end times',
    importance: Importance.max,
  );

  final AndroidFlutterLocalNotificationsPlugin? androidPlugin = flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
  await androidPlugin?.createNotificationChannel(channel);

  tz.initializeTimeZones();
  final String localName = await tzDataDefaultLocation();
  tz.setLocalLocation(tz.getLocation(localName));
}

Future<String> tzDataDefaultLocation() async {
  final tz.Location local = tz.local;
  return local.name;
}

Future<void> _requestAndroidNotificationPermissionIfNeeded() async {
  if (!Platform.isAndroid) return;
  
  final AndroidFlutterLocalNotificationsPlugin? androidPlugin = 
      flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
  
  if (androidPlugin != null) {
    await androidPlugin.requestNotificationsPermission();
  }
}


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPaintSizeEnabled = false;
  debugPaintBaselinesEnabled = false;
  await _initNotifications();
  await _requestAndroidNotificationPermissionIfNeeded();
  runApp(const QuestLogApp());
}

class QuestLogApp extends StatelessWidget {
  const QuestLogApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QuestLog',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
        fontFamily: 'DungGeunMo',
      ),
      home: const WelcomeScreen(),
    );
  }
}
