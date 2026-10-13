import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../widgets/app_bottom_nav.dart';
import '../widgets/app_icons.dart';
import '../utils/fridge_age.dart';
import '../utils/shelf_life.dart';
import 'notification_settings_screen.dart';

/// หน้า "แจ้งเตือน" วัตถุดิบที่อยู่ในตู้เย็นนาน (ตามดีไซน์ใน Figma กลุ่ม "ALERT")
/// เป็นหน้า root ของแท็บ "แจ้งเตือน" ในแถบเมนูด้านล่าง จึงไม่มีปุ่มย้อนกลับ
class ExpirationAlertScreen extends StatefulWidget {
  const ExpirationAlertScreen({super.key});

  @override
  State<ExpirationAlertScreen> createState() => _ExpirationAlertScreenState();
}

class _ExpirationAlertScreenState extends State<ExpirationAlertScreen> {
  final supabase = Supabase.instance.client;

  // ตัวเลือก "อยู่ในตู้เย็นมาแล้วตั้งแต่กี่วันขึ้นไป" ใช้ 0 แทน "ทั้งหมด"
  // และ -1 แทน "ควรรีบใช้" (เกณฑ์ตามชนิดของ ดู isOldItem ใน fridge_age.dart)
  static const List<Map<String, Object>> dayOptions = [
    {'label': 'ควรรีบใช้', 'value': -1},
    {'label': 'ทั้งหมด', 'value': 0},
    {'label': '3 วัน+', 'value': 3},
    {'label': '7 วัน+', 'value': 7},
    {'label': '14 วัน+', 'value': 14},
  ];

  int selectedDays = -1;
  int oldItemDays = defaultOldItemDays;
  String selectedCategory = "ทั้งหมด";

  List<Map<String, dynamic>> items = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadItems();
  }

  Future<void> loadItems() async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      if (mounted) setState(() => loading = false);
      return;
    }

    final data = await supabase
        .from('fridge_items')
        .select()
        .eq('user_id', user.id);

    oldItemDays = readOldItemDays(user);

    final result = data.where((item) {
      if (item['created_at'] == null) return false;

      // ถ้าใช้วัตถุดิบชิ้นนี้หมดแล้ว (เช่น กดทำอาหารจนหักจำนวนเหลือ 0) ก็ไม่ต้อง
      // เตือนอีกต่อไป เพราะไม่มีของเหลือให้ต้องรีบใช้แล้ว
      if (isUsedUp(Map<String, dynamic>.from(item))) return false;

      if (selectedDays == -1) {
        return isOldItem(Map<String, dynamic>.from(item), oldItemDays);
      }
      return daysInFridge(item['created_at']) >= selectedDays;
    }).map<Map<String, dynamic>>((e) {
      return Map<String, dynamic>.from(e);
    }).toList();

    // เรียงตามของที่อยู่ในตู้เย็นนานที่สุดขึ้นก่อนเสมอ (ของที่ควรรีบใช้ที่สุด
    // ต้องอยู่บนสุดจริงๆ ไม่ว่าจะอยู่หมวดไหน) ส่วนหมวดหมู่ใช้เป็นตัวตัดสินรอง
    result.sort((a, b) {
      final ageCompare = daysInFridge(b['created_at'])
          .compareTo(daysInFridge(a['created_at']));
      if (ageCompare != 0) return ageCompare;

      final catA = a['category']?.toString() ?? "อื่นๆ";
      final catB = b['category']?.toString() ?? "อื่นๆ";
      return catA.compareTo(catB);
    });

    if (mounted) {
      setState(() {
        items = result;
        loading = false;
      });
    }
  }

  void changeDays(int day) {
    setState(() {
      selectedDays = day;
      loading = true;
    });

    loadItems();
  }

  List<String> categories() {
    final list = items
        .map((item) => item['category']?.toString() ?? "อื่นๆ")
        .toSet()
        .toList();

    list.sort();

    return ["ทั้งหมด", ...list];
  }

  List<Map<String, dynamic>> filteredItems() {
    if (selectedCategory == "ทั้งหมด") {
      return items;
    }

    return items.where((item) {
      return (item['category']?.toString() ?? "อื่นๆ") == selectedCategory;
    }).toList();
  }

  String categoryEmoji(String category) {
    if (category.contains("ผลไม้")) return "🍎";
    if (category.contains("ผัก")) return "🥕";
    if (category.contains("เนื้อ") ||
        category.contains("หมู") ||
        category.contains("ไก่") ||
        category.contains("ปลา")) {
      return "🥩";
    }
    if (category.contains("ข้าว") || category.contains("แป้ง")) return "🍞";
    if (category.contains("นม") || category.contains("เครื่องดื่ม")) {
      return "🥛";
    }
    if (category.contains("ขนม")) return "🍬";

    return "📦";
  }

  String formatDate(String date) {
    final d = DateTime.parse(date).toLocal();
    return "${d.day}/${d.month}/${d.year + 543}";
  }

  // สีการ์ด: ของที่ควรรีบใช้แล้ว (ตามชนิดของ) = แดงเสมอ นอกนั้นไล่ตามระยะเวลา
  // ที่อยู่ในตู้เย็น: 7 วันขึ้นไป = เหลือง, 3 วันขึ้นไป = เขียว, น้อยกว่า = ขาว
  Color cardColor(int days, bool old) {
    if (old || days >= 14) return const Color(0xFFFADBD8);
    if (days >= 7) return const Color(0xFFFFF7D0);
    if (days >= 3) return const Color(0xFFDCF3DC);
    return Colors.white;
  }

  Color statusColor(int days, bool old) {
    if (old || days >= 14) return const Color(0xffD64545);
    if (days >= 7) return const Color(0xffC9A227);
    if (days >= 3) return const Color(0xff3F9142);
    return Colors.grey.shade600;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffD8EEFF),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 15),
            buildHeader(context),
            const SizedBox(height: 12),
            buildSettingsButton(context),
            const SizedBox(height: 15),
            buildDaySelector(),
            const SizedBox(height: 15),
            Expanded(
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : buildContent(),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNav(current: AppTab.alert),
    );
  }

  Widget buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7D0),
                borderRadius: BorderRadius.circular(25),
              ),
              child: const Row(
                children: [
                  NotificationIcon(size: 22),
                  SizedBox(width: 10),
                  Text(
                    "แจ้งเตือนวัตถุดิบ",
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 16,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            height: 50,
            width: 50,
            decoration: const BoxDecoration(
              color: Color(0xFFFFF7D0),
              shape: BoxShape.circle,
            ),
            child: const Center(child: FilterIcon(size: 20)),
          ),
        ],
      ),
    );
  }

  Widget buildSettingsButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Align(
        alignment: Alignment.centerRight,
        child: InkWell(
          borderRadius: BorderRadius.circular(25),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const NotificationSettingsScreen(),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(25),
              border: Border.all(color: Colors.black87, width: 1.2),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.notifications, color: Colors.black87, size: 18),
                SizedBox(width: 8),
                Text(
                  "ตั้งค่า",
                  style: TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget buildDaySelector() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "อยู่ในตู้เย็นมาแล้ว",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          // ให้ชิปทั้ง 5 อันขยายเท่าๆ กันจนเต็มความกว้างการ์ดพอดี แทนที่จะ
          // ปล่อยให้กองชิดซ้ายแล้วเหลือพื้นที่ว่างด้านขวาแบบเดิม
          Row(
            children: [
              for (int i = 0; i < dayOptions.length; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(child: _buildDayChip(dayOptions[i])),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDayChip(Map<String, Object> opt) {
    final value = opt['value'] as int;
    final selected = selectedDays == value;

    return GestureDetector(
      onTap: () => changeDays(value),
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFFF7D0) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: selected ? null : Border.all(color: Colors.black12),
        ),
        child: Text(
          opt['label'] as String,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 11.5,
            color: Colors.black87,
          ),
        ),
      ),
    );
  }

  Widget buildContent() {
    final showItems = filteredItems();

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: [
        // สรุปจำนวนรายการ
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Container(
                height: 55,
                width: 55,
                decoration: const BoxDecoration(
                  color: Color(0xffE3F2FD),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.access_time,
                  color: Color(0xff5189C9),
                  size: 30,
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "อยู่ในตู้เย็น",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      selectedDays == -1
                          ? "${showItems.length} รายการ ควรรีบใช้"
                          : selectedDays == 0
                          ? "${showItems.length} รายการทั้งหมด"
                          : "${showItems.length} รายการ อยู่มา $selectedDays วันขึ้นไป",
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
              Text(
                "${showItems.length}",
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 15),

        const Text(
          "หมวดหมู่",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 10),

        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: categories().map((cat) {
            final selected = selectedCategory == cat;

            return GestureDetector(
              onTap: () => setState(() => selectedCategory = cat),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: selected ? const Color(0xFFFFF7D0) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: selected ? null : Border.all(color: Colors.black12),
                ),
                child: Text(
                  "${categoryEmoji(cat)} $cat",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 15),

        if (showItems.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Text(
                "ไม่มีรายการวัตถุดิบในช่วงนี้",
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ),
          ),

        ...showItems.map((item) {
          final days = daysInFridge(item['created_at']);
          final old = isOldItem(item, oldItemDays);

          return Container(
            margin: const EdgeInsets.only(bottom: 15),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: cardColor(days, old),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      categoryEmoji(item['category'] ?? ""),
                      style: const TextStyle(fontSize: 32),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        item['name'] ?? "ไม่ระบุ",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                        ),
                      ),
                    ),
                    InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => deleteItem(item),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(
                          Icons.delete_outline,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text("📥 เพิ่มเข้าตู้เย็น: ${formatDate(item['created_at'])}"),
                if (item['storage'] != null)
                  Text(
                    "${storageEmoji(item['storage'])} เก็บใน${storageLabel(item['storage'])}",
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 15,
                      color: statusColor(days, old),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      old
                          ? "${fridgeAgeText(item['created_at'])} · ควรรีบใช้"
                          : fridgeAgeText(item['created_at']),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: statusColor(days, old),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Future<void> deleteItem(Map<String, dynamic> item) async {
    try {
      await supabase.from('fridge_items').delete().eq('item_id', item['item_id']);
      await loadItems();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("ลบไม่สำเร็จ: $e")));
    }
  }
}
