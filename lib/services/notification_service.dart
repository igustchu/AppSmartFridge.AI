import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;


class NotificationService {


static final notifications =
FlutterLocalNotificationsPlugin();



static Future<void> init() async {


tz.initializeTimeZones();


const settings =
InitializationSettings(

iOS: DarwinInitializationSettings(

requestAlertPermission:true,

requestBadgePermission:true,

requestSoundPermission:true,

),

);



await notifications.initialize(
settings
);



}



static Future<void> showExpiryAlert({

required String message,

}) async {


await notifications.show(

1,

"🔔 SmartFridge",

message,

const NotificationDetails(

iOS: DarwinNotificationDetails(

presentAlert:true,

presentBadge:true,

presentSound:true,

),

),

);


}

  static Future<void> showNotification({required String title, required String body}) async {}


}