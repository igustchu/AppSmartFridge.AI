import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'item_detail_screen.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/app_icons.dart';
import '../utils/category_icons.dart';
import '../services/notification_service.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  String? _selectedCategory;
  List<Map<String, dynamic>> _inventoryItems = [];
  bool _isLoading = true;

  // ช่องค้นหาวัตถุดิบด้านบน — เดิมเป็นแค่ TextField เปล่าๆ พิมพ์แล้วไม่มีอะไร
  // เกิดขึ้นเลย ตอนนี้ผูกกับ state จริง พิมพ์แล้วต้องกรองรายการวัตถุดิบจริง
  // จากคลังให้ขึ้นมา
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchInventoryData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchInventoryData() async {
    setState(() => _isLoading = true);
    try {
      final response = await Supabase.instance.client
          .from('fridge_items')
          .select()
          .order(
            'item_id',
            ascending: false,
          ); // เรียงตาม item_id ที่มีในฐานข้อมูล

      setState(() {
        _inventoryItems = List<Map<String, dynamic>>.from(response);
      });

      // ทุกครั้งที่โหลด/รีเฟรชคลัง ให้ซิงก์แจ้งเตือนวันหมดอายุใหม่ให้ตรงกับ
      // ของจริงในคลังตอนนี้ (ของที่ถูกลบ/ทำอาหารไปแล้วจะไม่มีแจ้งเตือนค้าง
      // ของที่เพิ่มใหม่จะได้ตั้งแจ้งเตือนให้ด้วย) ทำแบบไม่ต้องรอ (fire-and-
      // forget) จะได้ไม่ทำให้หน้าคลังโหลดช้าลง
      NotificationService.scheduleExpiryReminders().catchError((_) {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("เกิดข้อผิดพลาดในการดึงข้อมูล: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteItem(String id) async {
    try {
      await Supabase.instance.client
          .from('fridge_items')
          .delete()
          .eq('item_id', id); // อ้างอิงตาม item_id
      _fetchInventoryData();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("ลบข้อมูลไม่สำเร็จ: $e")));
    }
  }

  // ใช้ mapping กลางจาก utils/category_icons.dart (หน้านี้คือต้นแบบที่หน้าอื่น
  // ต้องอ้างอิงตาม เพื่อไม่ให้ชุดอิโมจิหมวดหมู่เพี้ยนไปคนละหน้า)
  String _getCategoryIcon(String category) => categoryEmoji(category);

  String _getSubtitle(Map<String, dynamic> item) {
    if (item['expiry_date'] != null) {
      DateTime expDate = DateTime.parse(item['expiry_date'].toString());
      int diffDays = expDate.difference(DateTime.now()).inDays;
      if (diffDays < 0) return 'หมดอายุแล้ว';
      if (diffDays == 0) return 'หมดอายุวันนี้';
      return 'หมดอายุในอีก $diffDays วัน';
    }
    return 'จำนวน : ${item['quantity'] ?? 1} ${item['unit'] ?? ''}';
  }

  @override
  Widget build(BuildContext context) {
    bool isCategoryView = _selectedCategory == null;
    final Set<String> uniqueCategories = _inventoryItems
        .map((item) => (item['category'] ?? 'อื่นๆ').toString())
        .toSet();
    final List<Map<String, dynamic>> displayedItems = isCategoryView
        ? _inventoryItems
        : _inventoryItems
              .where(
                (item) => (item['category'] ?? 'อื่นๆ') == _selectedCategory,
              )
              .toList();

    // ถ้ามีการพิมพ์ค้นหา ให้ค้นจากชื่อวัตถุดิบทั้งหมดในคลังจริง (ไม่สนใจว่า
    // ตอนนี้อยู่ในมุมมองหมวดหมู่ไหน) เทียบแบบไม่สนตัวพิมพ์เล็ก/ใหญ่
    final String trimmedQuery = _searchQuery.trim().toLowerCase();
    final bool isSearching = trimmedQuery.isNotEmpty;
    final List<Map<String, dynamic>> searchResults = isSearching
        ? _inventoryItems.where((item) {
            final name = (item['name']?.toString() ?? '').toLowerCase();
            return name.contains(trimmedQuery);
          }).toList()
        : <Map<String, dynamic>>[];

    int totalItems = isCategoryView
        ? _inventoryItems.length
        : displayedItems.length;
    int nearExpiryCount = 0;
    int expiredCount = 0;

    for (var item in (isCategoryView ? _inventoryItems : displayedItems)) {
      final qty = item['quantity'];
      final qtyNum = qty is num ? qty : num.tryParse(qty?.toString() ?? '');
      final isUsedUp = qtyNum != null && qtyNum <= 0;

      // ของที่ใช้หมดแล้ว (เหลือ 0 ชิ้น) ไม่ควรถูกนับทั้ง "ใกล้หมดอายุ" และ
      // "หมดแล้ว" เพราะไม่มีของเหลือให้ต้องพูดถึงวันหมดอายุอีกต่อไป (ปกติแล้ว
      // พอเหลือ 0 ตอนทำอาหาร ระบบจะลบรายการนี้ออกจากคลังไปเลย)
      if (!isUsedUp && item['expiry_date'] != null) {
        int diff = DateTime.parse(
          item['expiry_date'].toString(),
        ).difference(DateTime.now()).inDays;
        if (diff < 0) {
          expiredCount++;
        } else if (diff <= 3) {
          nearExpiryCount++;
        }
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFFD8EEFF),
      bottomNavigationBar: const AppBottomNav(current: AppTab.inventory),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _fetchInventoryData,
          color: Colors.blue,
          child: Column(
            children: [
              const SizedBox(height: 15),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Row(
                  children: [
                    if (!isCategoryView) ...[
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF7D0),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: IconButton(
                          icon: const BackIcon(size: 24),
                          onPressed: () =>
                              setState(() => _selectedCategory = null),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: Container(
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: TextField(
                          controller: _searchController,
                          onChanged: (value) =>
                              setState(() => _searchQuery = value),
                          decoration: InputDecoration(
                            hintText: isCategoryView
                                ? "วัตถุดิบทั้งหมด"
                                : _selectedCategory,
                            hintStyle: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                            prefixIcon: const Padding(
                              padding: EdgeInsets.all(14),
                              child: ListIcon(size: 20),
                            ),
                            suffixIcon: _searchQuery.isEmpty
                                ? const Icon(
                                    Icons.search,
                                    color: Colors.black,
                                  )
                                : IconButton(
                                    icon: const Icon(
                                      Icons.close,
                                      color: Colors.black,
                                    ),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _searchQuery = '');
                                    },
                                  ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 13,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      height: 50,
                      width: 50,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF7D0),
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: const Center(child: FilterIcon(size: 20)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: IntrinsicHeight(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildStatColumn("$totalItems", "รายการ"),
                        const VerticalDivider(
                          color: Colors.grey,
                          thickness: 0.5,
                        ),
                        _buildStatColumn("$nearExpiryCount", "ใกล้หมดอายุ"),
                        const VerticalDivider(
                          color: Colors.grey,
                          thickness: 0.5,
                        ),
                        _buildStatColumn("$expiredCount", "หมดแล้ว"),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // ในหน้า inventory_screen.dart ส่วนของ build method
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: Colors.blue),
                      )
                    : isSearching
                    // 🔍 กำลังพิมพ์ค้นหา — โชว์ผลลัพธ์ที่ตรงกับคำค้นจากของ
                    // ทั้งหมดในคลังจริง แทนที่มุมมองหมวดหมู่/รายการปกติ
                    ? (searchResults.isEmpty
                          ? const Center(
                              child: Text(
                                "ไม่พบวัตถุดิบที่ค้นหา",
                                style: TextStyle(
                                  color: Colors.black54,
                                  fontSize: 16,
                                ),
                              ),
                            )
                          : ListView(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              children: [
                                ...searchResults.map(
                                  (item) => _buildItemCard(context, item),
                                ),
                                const SizedBox(height: 30),
                              ],
                            ))
                    : _inventoryItems
                          .isEmpty // 🚀 เช็กตรงนี้ครับ ถ้า list ว่าง
                    ? const Center(
                        child: Text(
                          "ยังไม่มีวัตถุดิบในตู้เย็น", // ข้อความนี้จะขึ้นเมื่อไม่มีของ
                          style: TextStyle(color: Colors.black54, fontSize: 16),
                        ),
                      )
                    : ListView(
                        // 🚀 ถ้ามีของค่อยแสดง ListView
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        children: [
                          if (isCategoryView)
                            ...uniqueCategories.map(
                              (cat) => _buildCategoryCard(
                                cat,
                                _getCategoryIcon(cat),
                              ),
                            )
                          else
                            ...displayedItems.map(
                              (item) => _buildItemCard(context, item),
                            ),
                          const SizedBox(height: 10),
                          _buildAddButton(
                            isCategoryView
                                ? "+ เพิ่มหมวดหมู่"
                                : "+ เพิ่มวัตถุดิบ",
                          ),
                          const SizedBox(height: 30),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatColumn(String number, String label) {
    return Column(
      children: [
        Text(
          number,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.black87),
        ),
      ],
    );
  }

  Widget _buildCategoryCard(String name, String icon) {
    return GestureDetector(
      onTap: () => setState(() => _selectedCategory = name),
      child: Container(
        margin: const EdgeInsets.only(bottom: 15),
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 25),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF7D0),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 35)),
            const SizedBox(width: 20),
            Text(
              name,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemCard(BuildContext context, Map<String, dynamic> item) {
    String id = item['item_id'].toString();
    String name = item['name'] ?? 'ไม่ระบุชื่อ';
    String subtitle = _getSubtitle(item);
    String icon = _getCategoryIcon(item['category'] ?? '');

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ItemDetailScreen(itemData: item, itemId: id),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 15),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF7D0),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: subtitle.contains('หมดอายุ')
                          ? Colors.red.shade700
                          : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                Text(icon, style: const TextStyle(fontSize: 30)),
                const SizedBox(width: 15),
                GestureDetector(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text("ยืนยันการลบ"),
                        content: Text("คุณต้องการลบ $name ใช่หรือไม่?"),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text("ยกเลิก"),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                              _deleteItem(id);
                            },
                            child: const Text(
                              "ลบ",
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                  child: const Icon(
                    Icons.delete,
                    color: Colors.black87,
                    size: 28,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddButton(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 25),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7D0),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Center(
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ),
    );
  }

}