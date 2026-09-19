import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// บริการแจ้งเตือนวันหมดอายุของวัตถุดิบ — อ่านค่า "รับการแจ้งเตือนล่วงหน้า
/// กี่วัน" (notify_days) ที่ผู้ใช้ตั้งไว้ในหน้า notification_settings_screen.dart
/// (เก็บใน user_metadata ของ Supabase Auth) แล้วเทียบกับวันหมดอายุจริงของ
/// วัตถุดิบแต่ละชิ้นใน fridge_items เพื่อยิงแจ้งเตือนจริงไปยังเครื่องผู้ใช้
///
/// ใช้ 2 กลไกร่วมกันเพราะแอปนี้เป็น client-only (ไม่มีเซิร์ฟเวอร์/ฟังก์ชัน
/// แบ็กเอนด์คอยรันตอนแอปปิดอยู่):
/// 1. scheduleExpiryReminders() — ตั้งแจ้งเตือนล่วงหน้าไว้ล่วงหน้าให้ระบบ
///    ปฏิบัติการยิงเองตามเวลาที่กำหนด (09:00 ของวันที่ "เหลืออีก N วันตามที่
///    ตั้งไว้") ผ่าน flutter_local_notifications ซึ่งจะทำงานแม้แอปถูกปิดอยู่
///    เพราะระบบปฏิบัติการเป็นคนยิงให้ ไม่ใช่ตัวแอป
/// 2. checkAndShowDueReminders() — เช็กซ้ำทุกครั้งที่เปิดแอป/หน้าคลัง ว่ามี
///    วัตถุดิบที่ตอนนี้อยู่ในช่วงใกล้หมดอายุ (0 ถึง notify_days วัน) แล้วยัง
///    ไม่เคยเตือนวันนี้หรือยัง ถ้ายังไม่เคย จะยิงแจ้งเตือนทันที (กันเคสที่
///    เพิ่งตั้งวันแจ้งเตือน หรือเพิ่งเพิ่มของที่ใกล้หมดอายุอยู่แล้ว ให้ยังได้
///    รับแจ้งเตือนโดยไม่ต้องรอรอบถัดไป) — ทำให้ตราบใดที่ผู้ใช้เปิดแอปอย่าง
///    น้อยวันละครั้ง จะได้รับการเตือนซ้ำทุกวันที่ยังอยู่ในช่วงใกล้หมดอายุจริง
///    ตามที่ตั้งค่าไว้
///
/// ข้อจำกัดที่ควรรู้: บน iOS ระบบปฏิบัติการจำกัดจำนวนแจ้งเตือนที่ "ตั้งรอไว้ล่วงหน้า"
/// (pending) ได้สูงสุด 64 รายการต่อแอป ถ้ามีวัตถุดิบเยอะมากพร้อมกัน อาจมีบาง
/// รายการที่ตั้งล่วงหน้าไม่ติด (ระบบจะเก็บเฉพาะ 64 รายการที่ใกล้ถึงเวลาที่สุด)
/// แต่กลไกข้อ 2 (เช็กตอนเปิดแอป) จะช่วยชดเชยส่วนนี้ได้เสมอตราบใดที่เปิดแอปอยู่
class NotificationService {
  static final notifications = FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;

    tz.initializeTimeZones();

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      ),
    );

    await notifications.initialize(settings);

    // Android 13 (API 33) ขึ้นไปต้องขอสิทธิ์แจ้งเตือนแบบ runtime permission
    // เหมือนสิทธิ์อื่นๆ (กล้อง/แกลเลอรี) ไม่ได้ขอผ่าน manifest อย่างเดียวแล้ว
    try {
      await Permission.notification.request();
    } catch (_) {
      // เครื่อง/แพลตฟอร์มที่ไม่รองรับ permission_handler ตัวนี้ (เช่นเว็บ) ข้ามไป
    }

    _initialized = true;
  }

  static Future<void> showExpiryAlert({required String message}) async {
    debugPrint('[NotificationService] showExpiryAlert: $message');
    await notifications.show(
      1,
      "🔔 SmartFridge",
      message,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'expiry_channel',
          'แจ้งเตือนวันหมดอายุ',
          channelDescription: 'แจ้งเตือนเมื่อวัตถุดิบใกล้หมดอายุ',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          presentBanner: true,
          presentList: true,
        ),
      ),
    );
  }

  static Future<void> showNotification({
    required String title,
    required String body,
  }) async {
    await notifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000 % 100000,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'expiry_channel',
          'แจ้งเตือนวันหมดอายุ',
          channelDescription: 'แจ้งเตือนเมื่อวัตถุดิบใกล้หมดอายุ',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          presentBanner: true,
          presentList: true,
        ),
      ),
    );
  }

  // แปลง DateTime แบบ local ของเครื่อง ให้เป็น TZDateTime ที่ปลอดภัยสำหรับ
  // zonedSchedule โดยไม่ต้องพึ่งแพ็กเกจตรวจจับ timezone ของเครื่องเพิ่ม —
  // แปลงเป็น UTC ก่อนแล้วค่อยห่อด้วย tz.UTC ผลลัพธ์คือเวลาจริงตรงกับที่ตั้งไว้
  // ตามเวลาเครื่อง (Dart's DateTime() ที่ไม่ใส่ .utc คือเวลา local ของเครื่องอยู่แล้ว)
  static tz.TZDateTime _toTz(DateTime local) {
    return tz.TZDateTime.from(local.toUtc(), tz.UTC);
  }

  static int _stableId(String key) => key.hashCode & 0x7fffffff;

  /// ตั้งแจ้งเตือนล่วงหน้าให้ระบบปฏิบัติการยิงเองตามเวลาที่กำหนด สำหรับ
  /// วัตถุดิบทุกชิ้นในคลังของผู้ใช้ปัจจุบัน โดยอิงจากค่า "รับการแจ้งเตือน
  /// ล่วงหน้ากี่วัน" (notify_days) ที่ตั้งไว้ในหน้าตั้งค่า
  ///
  /// ล้างของเดิมแล้วตั้งใหม่ทั้งหมดทุกครั้ง เพื่อไม่ให้มีแจ้งเตือนค้างของ
  /// วัตถุดิบที่ถูกลบ/ทำอาหารไปแล้ว หรือวันหมดอายุที่ถูกแก้ไขใหม่
  static Future<void> scheduleExpiryReminders() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    await init();

    final notifyDays = _readNotifyDays(user);

    List<Map<String, dynamic>> items;
    try {
      final response = await supabase
          .from('fridge_items')
          .select()
          .eq('user_id', user.id);
      items = List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('[NotificationService] ดึงข้อมูล fridge_items ไม่สำเร็จ: $e');
      return; // ดึงข้อมูลไม่ได้ (ออฟไลน์ ฯลฯ) ข้ามรอบนี้ไป ไม่ทำให้แอปพัง
    }

    // ล้างแจ้งเตือนที่ตั้งไว้ล่วงหน้าของรอบก่อนหน้าทั้งหมดก่อน แล้วค่อยตั้งใหม่
    // จากข้อมูลคลังปัจจุบันจริงๆ
    await notifications.cancelAll();

    final now = DateTime.now();

    for (final item in items) {
      final expiryRaw = item['expiry_date'];
      if (expiryRaw == null) continue;

      final qty = item['quantity'];
      final qtyNum = qty is num ? qty : num.tryParse(qty?.toString() ?? '');
      if (qtyNum != null && qtyNum <= 0) continue; // ใช้หมดแล้ว ไม่ต้องเตือน

      DateTime expiryDate;
      try {
        expiryDate = DateTime.parse(expiryRaw.toString());
      } catch (_) {
        continue;
      }
      final expiryDay = DateTime(
        expiryDate.year,
        expiryDate.month,
        expiryDate.day,
      );

      final name = item['name']?.toString() ?? 'วัตถุดิบ';
      final itemId = item['item_id']?.toString() ?? name;

      final triggerDay = expiryDay.subtract(Duration(days: notifyDays));
      final triggerTime = DateTime(
        triggerDay.year,
        triggerDay.month,
        triggerDay.day,
        9, // เตือนตอน 9 โมงเช้าของแต่ละวัน
      );

      // ตั้งล่วงหน้าได้เฉพาะเวลาที่ยังไม่ผ่านไปเท่านั้น (ตั้งเวลาย้อนอดีตไม่ได้)
      // ถ้าช่วงที่ควรเตือนผ่านไปแล้ว (เช่นเพิ่งเปลี่ยนค่าวันแจ้งเตือน หรือเพิ่ง
      // เพิ่มของที่ใกล้หมดอายุอยู่แล้ว) checkAndShowDueReminders() จะช่วยจับแทน
      if (triggerTime.isAfter(now)) {
        try {
          await notifications.zonedSchedule(
            _stableId(itemId),
            "🔔 SmartFridge",
            "$name จะหมดอายุในอีก $notifyDays วัน — อย่าลืมเอาไปทำอาหารก่อนหมดอายุนะ!",
            _toTz(triggerTime),
            const NotificationDetails(
              android: AndroidNotificationDetails(
                'expiry_channel',
                'แจ้งเตือนวันหมดอายุ',
                channelDescription: 'แจ้งเตือนเมื่อวัตถุดิบใกล้หมดอายุ',
                importance: Importance.high,
                priority: Priority.high,
              ),
              iOS: DarwinNotificationDetails(
                presentAlert: true,
                presentBadge: true,
                presentSound: true,
                presentBanner: true,
                presentList: true,
              ),
            ),
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          );
        } catch (e) {
          debugPrint('[NotificationService] ตั้งแจ้งเตือนของ "$name" ไม่สำเร็จ: $e');
          // ข้ามรายการนี้ไปถ้าตั้งไม่สำเร็จ (เช่น iOS เต็มโควตา 64 รายการ)
          // ไม่ให้กระทบรายการอื่น
        }
      }
    }

    // ถือโอกาสเช็กด้วยเลยว่ามีของที่อยู่ในช่วงใกล้หมดอายุ "อยู่แล้วตอนนี้"
    // ที่พลาดช่วงเวลาที่ควรตั้งแจ้งเตือนไปแล้วหรือเปล่า จะได้ไม่พลาดแจ้งเตือน
    unawaited(checkAndShowDueReminders(items: items, notifyDays: notifyDays));
  }

  /// เช็กว่ามีวัตถุดิบที่ตอนนี้อยู่ในช่วงใกล้หมดอายุ (เหลือ 0 ถึง notify_days
  /// วัน) หรือไม่ ถ้ามีและยังไม่เคยแจ้งเตือนวันนี้ ให้ยิงแจ้งเตือนทันทีหนึ่งครั้ง
  /// (รวมทุกรายการเป็นข้อความเดียว) แล้วจำวันที่แจ้งเตือนล่าสุดไว้ใน
  /// user_metadata (แนวทางเดียวกับ notify_days) เพื่อไม่ให้เตือนซ้ำหลายครั้ง
  /// ในวันเดียวกันตอนเปิดแอปซ้ำๆ — เรียกซ้ำได้ทุกครั้งที่เปิดแอป/หน้าคลัง
  /// อย่างปลอดภัย
  static Future<void> checkAndShowDueReminders({
    List<Map<String, dynamic>>? items,
    int? notifyDays,
  }) async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final days = notifyDays ?? _readNotifyDays(user);

    List<Map<String, dynamic>> fridgeItems;
    if (items != null) {
      fridgeItems = items;
    } else {
      try {
        final response = await supabase
            .from('fridge_items')
            .select()
            .eq('user_id', user.id);
        fridgeItems = List<Map<String, dynamic>>.from(response);
      } catch (e) {
        debugPrint('[NotificationService] ดึงข้อมูล fridge_items ไม่สำเร็จ: $e');
        return;
      }
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final List<String> expiringNames = [];
    for (final item in fridgeItems) {
      final expiryRaw = item['expiry_date'];
      if (expiryRaw == null) continue;

      final qty = item['quantity'];
      final qtyNum = qty is num ? qty : num.tryParse(qty?.toString() ?? '');
      if (qtyNum != null && qtyNum <= 0) continue;

      DateTime expiryDate;
      try {
        expiryDate = DateTime.parse(expiryRaw.toString());
      } catch (_) {
        continue;
      }
      final expiryDay = DateTime(
        expiryDate.year,
        expiryDate.month,
        expiryDate.day,
      );
      final daysRemaining = expiryDay.difference(today).inDays;

      if (daysRemaining >= 0 && daysRemaining <= days) {
        expiringNames.add(item['name']?.toString() ?? 'วัตถุดิบ');
      }
    }

    if (expiringNames.isEmpty) return;

    final todayKey =
        "${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";
    final lastNotified =
        user.userMetadata?['last_expiry_notify_date']?.toString();
    if (lastNotified == todayKey) return; // วันนี้เตือนไปแล้ว ไม่เตือนซ้ำ

    final String message = expiringNames.length == 1
        ? "${expiringNames.first} ใกล้หมดอายุแล้ว รีบเอาไปทำอาหารก่อนหมดนะ!"
        : "มีวัตถุดิบใกล้หมดอายุ ${expiringNames.length} รายการ: "
              "${expiringNames.take(5).join(', ')}"
              "${expiringNames.length > 5 ? ' และอื่นๆ' : ''}";

    await init();
    await showExpiryAlert(message: message);

    try {
      await supabase.auth.updateUser(
        UserAttributes(data: {"last_expiry_notify_date": todayKey}),
      );
    } catch (e) {
      debugPrint('[NotificationService] บันทึกวันที่แจ้งเตือนล่าสุดไม่สำเร็จ: $e');
      // อัปเดตวันที่แจ้งเตือนล่าสุดไม่สำเร็จ (เช่นออฟไลน์) ไม่เป็นไร รอบหน้า
      // จะลองใหม่ — อย่างมากคือแจ้งเตือนซ้ำอีกครั้งถ้าเปิดแอปวันเดียวกัน
    }
  }

  static int _readNotifyDays(User user) {
    final saved = user.userMetadata?['notify_days'];
    if (saved is int) return saved;
    if (saved != null) return int.tryParse(saved.toString()) ?? 3;
    return 3;
  }
}

// ช่วยให้เรียก Future แบบไม่ต้อง await ตรงๆ โดยไม่ขึ้น warning "unawaited_futures"
// (เทียบเท่า package:pedantic/unawaited แต่เขียนเองสั้นๆ พอ ไม่ต้องเพิ่ม dependency)
void unawaited(Future<void> future) {}
