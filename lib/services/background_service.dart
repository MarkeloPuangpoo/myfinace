import 'dart:async';
import 'dart:ui';
import 'dart:developer';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_notification_listener/flutter_notification_listener.dart';
import 'package:drift/drift.dart' as drift;
import '../core/transaction_parser.dart';
import '../data/database.dart';

// Notification ID for the background service
const int serviceNotificationId = 888;
const String notificationChannelId = 'shadow_accountant_service';

// Global instances for the isolate
AppDatabase? _database;
final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  // Create the notification channel for the foreground service
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    notificationChannelId,
    'Shadow Accountant Service',
    description: 'Running in background to listen for transactions',
    importance: Importance.low,
  );

  await _flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(channel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: true,
      isForegroundMode: true,
      notificationChannelId: notificationChannelId,
      initialNotificationTitle: 'Shadow Accountant',
      initialNotificationContent: 'Monitoring banking notifications...',
      foregroundServiceNotificationId: serviceNotificationId,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: true,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  // Ensure Dart is ready
  DartPluginRegistrant.ensureInitialized();

  // Initialize Database inside the background isolate
  _database = AppDatabase();

  // Start listening to notifications
  try {
    bool? hasPermission = await NotificationsListener.hasPermission;
    if (hasPermission != true) {
      log("Notification permission not granted");
    }

    // Initialize and register the callback
    await NotificationsListener.initialize(
      callbackHandle: notificationCallback,
    );

    // Register the event handler
    // Note: registerEventHandle might not be needed if initialize handles it,
    // but some versions require it.
    // However, NotificationsListener.initialize usually sets up the stream.
    // We can also listen to the stream directly if needed, but the callback is for background.

    // Actually, for background execution, we rely on the callback.
    // But we also need to start the service.

    await NotificationsListener.startService(
      title: "Shadow Listener",
      description: "Listening for notifications",
    );
  } catch (e) {
    log("Error starting notification listener: $e");
  }

  // Handle service stop
  service.on('stopService').listen((event) {
    service.stopSelf();
  });
}

@pragma('vm:entry-point')
void notificationCallback(NotificationEvent event) async {
  log("Notification received: ${event.title} - ${event.text}");

  // Ensure database is initialized
  _database ??= AppDatabase();

  // Parse the notification
  final transaction = TransactionParser.parse(event.title, event.text);

  if (transaction != null) {
    log("Transaction Detected: $transaction");

    // Save to Database
    await _database!.insertTransaction(
      TransactionsCompanion(
        amount: drift.Value(transaction.amount),
        type: drift.Value(transaction.type.index),
        timestamp: drift.Value(transaction.timestamp),
        rawBody: drift.Value(transaction.rawBody),
        title: drift.Value(transaction.title),
      ),
    );

    // Optional: Update notification to show last detected transaction
    _flutterLocalNotificationsPlugin.show(
      serviceNotificationId,
      'Shadow Accountant',
      'Last: ${transaction.type == TransactionType.expense ? '-' : '+'}${transaction.amount}',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          notificationChannelId,
          'Shadow Accountant Service',
          icon: 'ic_bg_service_small',
          ongoing: true,
        ),
      ),
    );
  }
}
