import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/app_icons.dart';
import '../utils/category_icons.dart';

class ItemDetailScreen extends StatefulWidget {
  final String itemId; // รับไอดีจากหน้าคลัง

  const ItemDetailScreen({super.key, required this.itemId, required Map<String, dynamic> itemData});

  @override
  State<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends State<ItemDetailScreen> {
  Map<String, dynamic>? _item;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchItemDetails();
  }

  // --- ดึงข้อมูลจาก Supabase ---
  Future<void> _fetchItemDetails() async {
    try {
      final response = await Supabase.instance.client
          .from('fridge_items')
          .select()
          .eq('item_id', widget.itemId)
          .single();

      if (mounted) {
        setState(() {
          _item = response;
          _isLoading = false;
        });
      }
    } catch (e) {
  if (mounted) {
    setState(() {
      _isLoading = false;
      _item = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("ดึงข้อมูลไม่สำเร็จ: $e"),
        backgroundColor: Colors.red,
      ),
    );
  }
    }
  }

  // --- 🚀 ฟังก์ชันอัปเดตข้อมูลขึ้น Supabase ---
  Future<void> _updateField(String field, dynamic value) async {
    // แสดง Loading ตอนกำลังเซฟ
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await Supabase.instance.client
          .from('fridge_items')
          .update({field: value})
          .eq('item_id', widget.itemId);

      if (mounted) Navigator.pop(context); // ปิด Loading
      _fetchItemDetails(); // โหลดข้อมูลใหม่มาโชว์

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('อัปเดตข้อมูลสำเร็จ!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาด: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // --- 🚀 Popup สำหรับพิมพ์แก้ไขข้อความหรือตัวเลข ---
  Future<void> _showEditDialog(
    String title,
    String field,
    String currentValue, {
    bool isNumber = false,
  }) async {
    TextEditingController controller = TextEditingController(
      text: currentValue,
    );

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'แก้ไข$title',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: controller,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          decoration: InputDecoration(
            hintText: 'กรอก$titleใหม่',
            filled: true,
            fillColor: Colors.grey[100],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ยกเลิก', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () {
              Navigator.pop(context);
              dynamic newValue = isNumber
                  ? int.tryParse(controller.text)
                  : controller.text;
              if (newValue != null && newValue.toString().isNotEmpty) {
                _updateField(field, newValue);
              }
            },
            child: const Text('บันทึก', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // --- 🚀 Popup สำหรับเลือกหมวดหมู่ — เลือกได้จากรายการที่กำหนดไว้เท่านั้น
  // (fixedCategories) ไม่ให้พิมพ์ข้อความอิสระ เพื่อไม่ให้เกิดหมวดหมู่แปลกๆ
  // ซ้ำซ้อนในหน้าคลังเหมือนที่เคยเป็นปัญหาก่อนแก้ไขนี้
  Future<void> _showCategoryPickerDialog(String currentValue) async {
    final normalized = normalizeCategory(currentValue);
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'แก้ไขหมวดหมู่',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: fixedCategories.map((cat) {
              return RadioListTile<String>(
                value: cat,
                groupValue: normalized,
                activeColor: Colors.orange,
                title: Text(cat),
                onChanged: (val) {
                  Navigator.pop(context);
                  if (val != null && val != normalized) {
                    _updateField('category', val);
                  }
                },
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ยกเลิก', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  // --- 🚀 Popup สำหรับเลือกปฏิทินวันหมดอายุ ---
  Future<void> _selectExpiryDate() async {
    DateTime initialDate = DateTime.now();
    if (_item!['expiry_date'] != null) {
      initialDate = DateTime.parse(_item!['expiry_date'].toString());
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime.now().subtract(
        const Duration(days: 365),
      ), // ย้อนหลังได้ 1 ปี
      lastDate: DateTime.now().add(
        const Duration(days: 3650),
      ), // ไปข้างหน้าได้ 10 ปี
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.orange,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      _updateField('expiry_date', picked.toIso8601String());
    }
  }

  // ฟังก์ชันแปลงวันที่
  String _formatThaiDate(String? isoString) {
    if (isoString == null || isoString.isEmpty) return 'ไม่ระบุ';
    try {
      DateTime dt = DateTime.parse(isoString);
      List<String> fullMonths = [
        'มกราคม',
        'กุมภาพันธ์',
        'มีนาคม',
        'เมษายน',
        'พฤษภาคม',
        'มิถุนายน',
        'กรกฎาคม',
        'สิงหาคม',
        'กันยายน',
        'ตุลาคม',
        'พฤศจิกายน',
        'ธันวาคม',
      ];
      return '${dt.day} ${fullMonths[dt.month - 1]} ${dt.year + 543}';
    } catch (e) {
      return isoString;
    }
  }

  @override
Widget build(BuildContext context) {
  if (_isLoading) {
    return const Scaffold(
      backgroundColor: Color(0xFFD8EEFF),
      body: Center(child: CircularProgressIndicator()),
    );
  }

  if (_item == null) {
    return const Scaffold(
      backgroundColor: Color(0xFFD8EEFF),
      body: Center(
        child: Text(
          "ไม่พบข้อมูลสินค้า",
          style: TextStyle(
            fontSize: 18,
            color: Colors.black,
          ),
        ),
      ),
    );
  }

  final item = _item!;

    return Scaffold(
      backgroundColor: const Color(0xFFD8EEFF),
      bottomNavigationBar: const AppBottomNav(current: AppTab.inventory),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),

            // --- Header ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25.0),
              child: Row(
                children: [
                  Container(
                    width: 55,
                    height: 45,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7D0),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: IconButton(
                      icon: const BackIcon(size: 24),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Container(
                      height: 45,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF7D0),
                        borderRadius: BorderRadius.circular(25),
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        "รายละเอียด",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),

            // --- เนื้อหา ---
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 35.0),
                child: Column(
                  children: [
                    // 🚀 เชื่อมปุ่มแก้ไขชื่อ
                    _buildDetailRow(
                      icon: Icons.restaurant,
                      text: item['name'] ?? 'ไม่ระบุชื่อ',
                      isTitle: true,
                      hasEdit: true, // เปิดให้แก้ไขชื่อได้ด้วย
                      onEdit: () => _showEditDialog(
                        'ชื่อวัตถุดิบ',
                        'name',
                        item['name'] ?? '',
                      ),
                    ),
                    const SizedBox(height: 10),

                    // 🚀 เชื่อมปุ่มปฏิทิน
                    _buildDetailRow(
                      icon: Icons.calendar_month,
                      text:
                          "หมดอายุ ${_formatThaiDate(item['expiry_date']?.toString())}",
                      onEdit: _selectExpiryDate,
                    ),
                    const SizedBox(height: 10),

                    // 🚀 เชื่อมปุ่มแก้ไขหมวดหมู่
                    _buildDetailRow(
                      icon: Icons.format_list_bulleted,
                      text: "หมวดหมู่ : ${item['category'] ?? 'ไม่ระบุ'}",
                      onEdit: () =>
                          _showCategoryPickerDialog(item['category'] ?? ''),
                    ),
                    const SizedBox(height: 10),

                    // 🚀 เชื่อมปุ่มแก้ไขจำนวน
                    _buildDetailRow(
                      icon: Icons.add_circle,
                      text:
                          "จำนวน : ${item['quantity'] ?? 0} ${item['unit'] ?? ''}",
                      onEdit: () => _showEditDialog(
                        'จำนวน',
                        'quantity',
                        item['quantity']?.toString() ?? '0',
                        isNumber: true,
                      ),
                    ),
                    const SizedBox(height: 30),

                    if (item['created_at'] != null)
                      Text(
                        "สร้างเมื่อ ${_formatThaiDate(item['created_at'].toString())}",
                        style: const TextStyle(
                          fontSize: 15,
                          color: Colors.black54,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ตามดีไซน์ใน Figma แต่ละแถวไม่มีไอคอนดินสอ/เส้นคั่นให้เห็น แต่ยังแตะทั้งแถว
  // เพื่อแก้ไขได้เหมือนเดิม (ไม่ตัดฟีเจอร์แก้ไขออก แค่ซ่อนไอคอนให้ตรงดีไซน์)
  Widget _buildDetailRow({
    required IconData icon,
    required String text,
    bool isTitle = false,
    bool hasEdit = true,
    VoidCallback? onEdit,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: GestureDetector(
        onTap: hasEdit ? onEdit : null,
        behavior: HitTestBehavior.opaque,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2.0),
              child: Icon(icon, size: isTitle ? 32 : 28, color: Colors.black),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: isTitle ? 28 : 16,
                  fontWeight: isTitle ? FontWeight.w900 : FontWeight.normal,
                  color: Colors.black,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

}