import 'package:supabase_flutter/supabase_flutter.dart';

/// นับว่าวัตถุดิบอยู่ในตู้เย็นมาแล้วกี่วัน โดยนับจากเวลาที่เพิ่มเข้าตู้เย็น
/// (created_at) ครบทุก 24 ชั่วโมงนับเป็น 1 วัน (ยังไม่ถึง 24 ชั่วโมง = 0 วัน)
int daysInFridge(dynamic createdAt) => hoursInFridge(createdAt) ~/ 24;

/// เข้าตู้เย็นมาแล้วกี่ชั่วโมง
int hoursInFridge(dynamic createdAt) {
  final added = _parseLocal(createdAt);
  if (added == null) return 0;
  final diff = DateTime.now().difference(added).inHours;
  return diff < 0 ? 0 : diff;
}

/// ช่วงเวลาที่อยู่ในตู้เย็นแบบสั้น — ยังไม่ถึง 1 วันบอกเป็นชั่วโมง (เช่น
/// "5 ชั่วโมง") ตั้งแต่ 1 วันขึ้นไปบอกเป็นวันอย่างเดียว (เช่น "3 วัน")
String fridgeAgeDuration(dynamic createdAt) {
  final days = daysInFridge(createdAt);
  if (days > 0) return '$days วัน';
  final hours = hoursInFridge(createdAt);
  if (hours < 1) return 'ไม่ถึง 1 ชั่วโมง';
  return '$hours ชั่วโมง';
}

/// ข้อความบอกว่าอยู่ในตู้เย็นมาแล้วนานเท่าไหร่ ใช้แสดงผลในทุกหน้า — แสดง
/// ตัวเลขเสมอ และถ้ายังไม่ครบวันจะบอกจำนวนชั่วโมงด้วย
String fridgeAgeText(dynamic createdAt) =>
    'อยู่ในตู้เย็นมาแล้ว ${fridgeAgeDuration(createdAt)}';

/// เหลืออีกกี่วันจะหมดอายุ นับเป็นวันตามปฏิทิน (หมดอายุวันนี้ = 0,
/// พรุ่งนี้ = 1, หมดอายุไปแล้ว = ติดลบ) — null ถ้าไม่มีวันหมดอายุ
int? daysUntilExpiry(dynamic expiryDate) {
  final expiry = _parseLocal(expiryDate);
  if (expiry == null) return null;
  return _dayOf(expiry).difference(_today()).inDays;
}

/// ข้อความป้ายวันหมดอายุ เช่น "หมดอายุพรุ่งนี้"
String expiryText(int days) {
  if (days < 0) return 'หมดอายุแล้ว ${-days} วัน';
  if (days == 0) return 'หมดอายุวันนี้';
  if (days == 1) return 'หมดอายุพรุ่งนี้';
  if (days >= 60) return 'หมดอายุในอีก ${days ~/ 30} เดือน';
  return 'หมดอายุในอีก $days วัน';
}

/// ของที่ใช้หมดแล้ว (เหลือ 0 ชิ้น) ไม่ต้องนับ/เตือน เพราะไม่มีของเหลือแล้ว
/// (ของที่ไม่มีระบุจำนวนไว้ ให้ถือว่ายังมีของอยู่ตามเดิม)
bool isUsedUp(Map<String, dynamic> item) {
  final qty = item['quantity'];
  if (qty == null) return false;
  final qtyNum = qty is num ? qty : num.tryParse(qty.toString());
  return qtyNum != null && qtyNum <= 0;
}

/// ลำดับแบบ FIFO: ลอตที่ใกล้หมดอายุที่สุดมาก่อน (ไม่มีวันหมดอายุไว้ท้ายสุด)
/// ถ้าหมดอายุวันเดียวกัน ลอตที่เข้าตู้เย็นก่อนมาก่อน — ใช้ทั้งตอนแสดงผลใน
/// หน้าเช็คตู้เย็นและตอนเลือกลอตที่จะหักตอนทำอาหาร
int compareFifo(Map<String, dynamic> a, Map<String, dynamic> b) {
  final ea = daysUntilExpiry(a['expiry_date']);
  final eb = daysUntilExpiry(b['expiry_date']);
  if (ea != null && eb != null && ea != eb) return ea.compareTo(eb);
  if (ea == null && eb != null) return 1;
  if (ea != null && eb == null) return -1;
  return daysInFridge(b['created_at']).compareTo(daysInFridge(a['created_at']));
}

DateTime? _parseLocal(dynamic raw) {
  if (raw == null) return null;
  try {
    return DateTime.parse(raw.toString()).toLocal();
  } catch (_) {
    return null;
  }
}

DateTime _dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime _today() => _dayOf(DateTime.now());

/// ค่าเริ่มต้นของ "อยู่ในตู้เย็นครบกี่วันถึงจะถือว่าอยู่นานแล้ว ควรรีบใช้"
/// ถ้าผู้ใช้ยังไม่เคยตั้งค่าไว้ในหน้า notification_settings_screen.dart
const int defaultOldItemDays = 7;

/// อ่านค่า "แจ้งเตือนเมื่ออยู่ในตู้เย็นครบกี่วัน" (notify_days) ที่ผู้ใช้ตั้งไว้
/// ใน user_metadata ของ Supabase Auth — ใช้ร่วมกันในหน้าแจ้งเตือน, การแจ้ง
/// เตือน push, เมนูอาหาร (AI) และแพลนอาหาร
int readOldItemDays(User? user) {
  final saved = user?.userMetadata?['notify_days'];
  if (saved is int) return saved;
  if (saved != null) {
    return int.tryParse(saved.toString()) ?? defaultOldItemDays;
  }
  return defaultOldItemDays;
}

/// สัดส่วนของอายุการเก็บรักษาที่ถือว่า "ควรรีบใช้" แล้ว
const double oldItemShelfRatio = 0.7;

/// อยู่ในตู้เย็นครบกี่วันถึงจะถือว่าควรรีบใช้ สำหรับวัตถุดิบชิ้นนี้ — ใช้ค่าที่
/// น้อยกว่าระหว่าง (1) จำนวนวันที่ผู้ใช้ตั้งไว้ กับ (2) 70% ของอายุการเก็บ
/// รักษาของชิ้นนั้นตามช่องที่เก็บ (fridge_days/freezer_days) ของที่เน่าเร็ว
/// อย่างเนื้อสัตว์จึงถูกเตือนเร็วกว่าของที่เก็บได้นานอย่างไข่ ส่วนของเก่าที่
/// ไม่มีข้อมูลอายุการเก็บรักษาจะใช้จำนวนวันที่ผู้ใช้ตั้งไว้อย่างเดียว
int oldThresholdFor(Map<String, dynamic> item, int userDays) {
  final raw = item['storage'] == 'freezer'
      ? item['freezer_days']
      : item['fridge_days'];
  final shelfDays = raw is num ? raw : num.tryParse(raw?.toString() ?? '');
  if (shelfDays == null || shelfDays <= 0) return userDays;
  final byShelf = (shelfDays * oldItemShelfRatio).ceil().clamp(1, 1 << 30);
  return byShelf < userDays ? byShelf : userDays;
}

/// วัตถุดิบชิ้นนี้อยู่ในตู้เย็นนานจนควรรีบใช้แล้วหรือยัง (ของที่ใช้หมดแล้ว
/// หรือไม่มีวันที่เข้าตู้เย็นไม่นับ)
bool isOldItem(Map<String, dynamic> item, int userDays) {
  if (item['created_at'] == null || isUsedUp(item)) return false;
  return daysInFridge(item['created_at']) >= oldThresholdFor(item, userDays);
}
