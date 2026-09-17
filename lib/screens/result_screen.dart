import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/category_icons.dart';
import '../widgets/app_icons.dart';
import '../widgets/recipe_flow_widgets.dart';
import 'inventory_screen.dart';

/// หน้าผลลัพธ์หลังสแกนวัตถุดิบ (ตามดีไซน์ใน Figma: "SCAN" - ผลลัพธ์)
/// รูปที่แสดงในการ์ด "รูปภาพ" คือรูปจริงที่ผู้ใช้ถ่าย/เลือกมา (ไม่ใช่รูป mock)
class ResultScreen extends StatefulWidget {
  final List<dynamic> foundItems;
  final Uint8List? imageBytes;

  const ResultScreen({super.key, required this.foundItems, this.imageBytes});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFD8EEFF),
      body: SafeArea(
        child: Column(
          children: [
            const IngredientFlowHeader(title: "ผลลัพธ์"),
            const SizedBox(height: 15),

            // --- ป้ายบอกจำนวนวัตถุดิบที่พบ ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 6),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  "พบวัตถุดิบ ${widget.foundItems.length} รายการ",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // --- การ์ด "รูปภาพ" (รูปจริงที่ถ่าย/เลือกมาสแกน) ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Container(
                width: double.infinity,
                // เพิ่มความสูงจาก 200 เป็น 320 เพื่อให้มีที่พอแสดงรูปเต็มๆ
                // ไม่ต้องครอปแน่นจนเกินไป (ของเดิมกล่องเตี้ยเกินไปเทียบกับรูปโหมด
                // แนวตั้งจากกล้อง ทำให้ครอปหายไปเยอะ)
                height: 320,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFCDC),
                        border: Border.all(color: const Color(0xFFFFD191)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        "รูปภาพ",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: double.infinity,
                          alignment: Alignment.center,
                          // พื้นหลังสีเทาอ่อนไว้รองรับรูปที่สัดส่วนไม่พอดีกรอบ
                          // (BoxFit.contain จะไม่ครอปรูปแต่จะเห็นแถบพื้นหลังนี้แทน)
                          color: Colors.grey.shade100,
                          child: widget.imageBytes != null
                              ? Image.memory(
                                  widget.imageBytes!,
                                  width: double.infinity,
                                  height: double.infinity,
                                  // เปลี่ยนจาก cover เป็น contain เพื่อให้เห็นรูปที่ถ่ายมา
                                  // แบบเต็มๆ ไม่ถูกครอปขอบออกเหมือนก่อนหน้านี้
                                  fit: BoxFit.contain,
                                )
                              : Icon(
                                  Icons.image_outlined,
                                  size: 36,
                                  color: Colors.grey.shade400,
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // --- รายการวัตถุดิบ (List) ---
            Expanded(
              child: widget.foundItems.isEmpty
                  ? const Center(
                      child: Text(
                        "ไม่พบวัตถุดิบ",
                        style: TextStyle(color: Colors.black54, fontSize: 16),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 5, 20, 0),
                      itemCount: widget.foundItems.length,
                      itemBuilder: (context, index) {
                        return IngredientCardItem(
                          initialData:
                              widget.foundItems[index] as Map<String, dynamic>,
                          onUpdate: (key, value) {
                            widget.foundItems[index][key] = value;
                          },
                        );
                      },
                    ),
            ),

            // --- ปุ่มกดด้านล่าง (Footer) ---
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 15),
              child: Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 10,
                      offset: Offset(0, -2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFB6B6B6),
                          foregroundColor: Colors.black87,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          "สแกนใหม่",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _saveToSupabase,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD7EDFF),
                          foregroundColor: Colors.black87,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            CheckIcon(size: 18),
                            SizedBox(width: 5),
                            Text(
                              "บันทึกทั้งหมด",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
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

  // --- ฟังก์ชันบันทึกลง Database ---
  Future<void> _saveToSupabase() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('กรุณาล็อกอินก่อนบันทึกข้อมูล'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) =>
          const Center(child: CircularProgressIndicator(color: Colors.blue)),
    );

    try {
      for (var item in widget.foundItems) {
        String name = item['name'];

        final existingItem = await supabase
            .from('fridge_items')
            .select('item_id, quantity')
            .eq('user_id', user.id)
            .eq('name', name)
            .maybeSingle();

        if (existingItem != null) {
          int newQuantity =
              (existingItem['quantity'] ?? 0) + (item['quantity'] as int);

          await supabase
              .from('fridge_items')
              .update({'quantity': newQuantity})
              .eq('item_id', existingItem['item_id']);
        } else {
          int days = int.tryParse(item['expiry_days'].toString()) ?? 7;
          DateTime expiryDate = DateTime.now().add(Duration(days: days));

          await supabase.from('fridge_items').insert({
            'user_id': user.id,
            'name': name,
            'category': item['category'],
            'quantity': item['quantity'],
            'max_quantity': item['quantity'],
            'unit': item['unit'],
            'expiry_date': expiryDate.toIso8601String(),
          });
        }
      }

      if (mounted) Navigator.pop(context);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('บันทึกข้อมูลเรียบร้อย!'),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const InventoryScreen()),
          (route) => route.isFirst,
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
}

// ==================================================================
// Widget ย่อย: การ์ดสำหรับแสดงผลวัตถุดิบ 1 ชิ้น
// ==================================================================
class IngredientCardItem extends StatefulWidget {
  final Map<String, dynamic> initialData;
  final Function(String key, dynamic value) onUpdate;

  const IngredientCardItem({
    super.key,
    required this.initialData,
    required this.onUpdate,
  });

  @override
  State<IngredientCardItem> createState() => _IngredientCardItemState();
}

class _IngredientCardItemState extends State<IngredientCardItem> {
  late TextEditingController nameController;
  late TextEditingController expiryController;
  late int quantity;
  late String unit;
  late String category;

  @override
  void initState() {
    super.initState();
    final data = widget.initialData;

    nameController = TextEditingController(text: data['name'] ?? '');

    int days = 7;
    if (data['expiry_days'] != null) {
      days = int.tryParse(data['expiry_days'].toString()) ?? 7;
    }
    expiryController = TextEditingController(text: days.toString());

    quantity = (data['quantity'] is int) ? data['quantity'] : 1;
    unit = data['unit'] ?? 'ชิ้น';
    // กันเหนียว: normalize หมวดหมู่ให้เข้าเซ็ตที่กำหนดไว้เสมอ (fixedCategories)
    // เผื่อ AI ตอบมาไม่ตรงเป๊ะ หรือเป็นข้อมูลเก่าก่อนแก้ไขนี้
    category = normalizeCategory((data['category'] ?? 'อื่นๆ').toString());

    nameController.addListener(() {
      widget.onUpdate('name', nameController.text);
    });

    expiryController.addListener(() {
      int? val = int.tryParse(expiryController.text);
      if (val != null) widget.onUpdate('expiry_days', val);
    });
  }

  @override
  void dispose() {
    nameController.dispose();
    expiryController.dispose();
    super.dispose();
  }

  // ใช้ mapping กลางเดียวกับหน้าคลัง (Inventory) เพื่อให้อิโมจิหมวดหมู่ตรงกันทุกหน้า
  String _getEmoji(String cat) => categoryEmoji(cat);

  @override
  Widget build(BuildContext context) {
    int daysToAdd = int.tryParse(expiryController.text) ?? 7;
    final expiryDate = DateTime.now().add(Duration(days: daysToAdd));
    final expiryDateString =
        "${expiryDate.day}/${expiryDate.month}/${expiryDate.year + 543}";

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. ส่วนหัว: หมวดหมู่ (เลือกได้จากรายการที่กำหนดไว้เท่านั้น) และ Emoji
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFCDC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFFD191)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: category,
                    isDense: true,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    items: fixedCategories
                        .map(
                          (c) => DropdownMenuItem(value: c, child: Text(c)),
                        )
                        .toList(),
                    onChanged: (val) {
                      if (val == null) return;
                      setState(() => category = val);
                      widget.onUpdate('category', val);
                    },
                  ),
                ),
              ),
              Text(_getEmoji(category), style: const TextStyle(fontSize: 30)),
            ],
          ),

          const SizedBox(height: 12),

          // 2. ชื่อวัตถุดิบ
          const Text(
            "ชื่อวัตถุดิบ",
            style: TextStyle(
              color: Colors.black87,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 5),
          TextFormField(
            controller: nameController,
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: Colors.grey[50],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
            ),
          ),

          const SizedBox(height: 12),

          // 3. ปริมาณและหน่วย
          Row(
            children: [
              _buildCounterButton("-", () {
                if (quantity > 1) {
                  setState(() => quantity--);
                  widget.onUpdate('quantity', quantity);
                }
              }),
              Container(
                width: 50,
                alignment: Alignment.center,
                child: Text(
                  "$quantity",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.black87,
                  ),
                ),
              ),
              _buildCounterButton("+", () {
                setState(() => quantity++);
                widget.onUpdate('quantity', quantity);
              }),

              const SizedBox(width: 15),

              Expanded(
                child: DropdownButtonFormField<String>(
                  value:
                      [
                        "ชิ้น",
                        "กรัม",
                        "กก.",
                        "แพ็ค",
                        "ขวด",
                        "ลูก",
                        "ฟอง",
                      ].contains(unit)
                      ? unit
                      : "ชิ้น",
                  decoration: InputDecoration(
                    isDense: true,
                    filled: true,
                    fillColor: Colors.grey[50],
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                  items: ["ชิ้น", "กรัม", "กก.", "แพ็ค", "ขวด", "ลูก", "ฟอง"]
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (val) {
                    setState(() => unit = val!);
                    widget.onUpdate('unit', val);
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // 4. วันหมดอายุ
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFCDC),
              border: Border.all(color: const Color(0xFFFFD191)),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "อีกกี่วันหมดอายุ:",
                        style: TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                      SizedBox(
                        height: 30,
                        child: TextFormField(
                          controller: expiryController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                          onChanged: (val) => setState(() {}),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(width: 1, height: 30, color: const Color(0xFFFFD191)),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      "วันที่หมดอายุ",
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                    Text(
                      expiryDateString,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFE62020),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCounterButton(String icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFFFFFCDC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFFFD191)),
        ),
        child: Text(
          icon,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Colors.black87,
          ),
        ),
      ),
    );
  }
}
