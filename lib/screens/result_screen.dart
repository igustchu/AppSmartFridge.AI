import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/category_icons.dart';
import '../utils/shelf_life.dart';
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
  void initState() {
    super.initState();

    // จัดกลุ่มวัตถุดิบที่สแกนเจอให้หมวดหมู่เดียวกันอยู่ติดกัน จะได้ไล่ดูง่าย
    // ใช้ index เดิมเป็นตัวตัดสินลำดับรองเพื่อให้เรียงแบบ stable (ของในหมวด
    // เดียวกันยังอยู่ตามลำดับที่สแกนเจอ ไม่สลับกันไปมา)
    final indexed = widget.foundItems.asMap().entries.toList();
    indexed.sort((a, b) {
      final catA = (a.value is Map ? a.value['category']?.toString() : null) ?? "อื่นๆ";
      final catB = (b.value is Map ? b.value['category']?.toString() : null) ?? "อื่นๆ";
      final catCompare = catA.compareTo(catB);
      if (catCompare != 0) return catCompare;
      return a.key.compareTo(b.key);
    });

    widget.foundItems
      ..clear()
      ..addAll(indexed.map((e) => e.value));

    // คำนวณค่าการจัดเก็บเริ่มต้น (ช่องปกติ + วันหมดอายุตามตาราง/Gemini) ให้
    // ทุกชิ้นตั้งแต่ตอนเปิดหน้า ไม่รอให้การ์ดถูกเลื่อนมาแสดงก่อน (ListView
    // สร้างการ์ดเฉพาะชิ้นที่อยู่บนจอ) — กดบันทึกทันทีก็ยังได้ค่าที่ถูกต้อง
    for (final item in widget.foundItems) {
      if (item is! Map || item.containsKey('storage')) continue;
      item['gemini_fridge_days'] = item['fridge_days'];
      item['gemini_freezer_days'] = item['freezer_days'];
      final typeKey = findShelfType(item['shelf_type']?.toString())?.key;
      final state = defaultStateFor(typeKey);
      final life = resolveShelfLife(
        typeKey: typeKey,
        state: state,
        geminiFridgeDays: item['gemini_fridge_days'],
        geminiFreezerDays: item['gemini_freezer_days'],
      );
      item['shelf_type'] = typeKey;
      item['food_state'] = state;
      item['storage'] = storageFridge;
      item['fridge_days'] = life.fridgeDays;
      item['freezer_days'] = life.freezerDays;
      item['expiry_days'] = life.fridgeDays;
    }
  }

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
      // หลัก FIFO: ซื้อวัตถุดิบชนิดเดิมมาเพิ่มเมื่อไหร่ ก็บันทึกแยกเป็นลอตใหม่
      // (แถวใหม่) เสมอ ไม่รวมเข้ากับลอตเดิม เพื่อให้แต่ละลอตมีวันที่เข้าตู้เย็น
      // และวันหมดอายุของตัวเอง ตอนทำอาหารระบบจะหักจากลอตที่ใกล้หมดอายุก่อน
      for (var item in widget.foundItems) {
        String name = item['name'];
        final storage = item['storage']?.toString() ?? storageFridge;
        int days = int.tryParse(item['expiry_days'].toString()) ?? 7;
        DateTime expiryDate = DateTime.now().add(Duration(days: days));
        final foodState = item['food_state']?.toString() ?? '';

        // ปริมาณที่ตรวจพบจากรูป (เก็บไว้แสดงว่าซื้อมาเท่าไหร่) แยกกับหน่วยที่ใช้
        // หักตอนทำอาหาร: ถ้าผู้ใช้เลือก "แบ่งเป็นส่วน" ระบบจะนับ/หักเป็น "ส่วน"
        // แทน ไม่งั้นหักตามปริมาณที่ตรวจพบตรงๆ
        final detectedQty = num.tryParse(item['quantity'].toString()) ?? 1;
        final detectedUnit = item['unit']?.toString() ?? 'ชิ้น';
        final usePortions = item['use_mode'] == 'portion';
        final num stockQty = usePortions
            ? (int.tryParse(item['portions'].toString()) ?? 1)
            : detectedQty;
        final stockUnit = usePortions ? 'ส่วน' : detectedUnit;

        await supabase.from('fridge_items').insert({
          'user_id': user.id,
          'name': name,
          'category': item['category'],
          'quantity': stockQty,
          'max_quantity': stockQty,
          'unit': stockUnit,
          'detected_quantity': detectedQty,
          'detected_unit': detectedUnit,
          'expiry_date': expiryDate.toIso8601String(),
          'storage': storage,
          'food_state': foodState.isEmpty ? null : foodState,
          'fridge_days': item['fridge_days'],
          'freezer_days': item['freezer_days'],
        });
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
  late TextEditingController detectedQtyController;
  late String unit;

  // การนำไปใช้หัก: 'detected' = หักตามปริมาณที่ตรวจพบจากรูป,
  // 'portion' = ผู้ใช้แบ่งเป็นส่วนเอง แล้วหักทีละส่วน
  late String useMode;
  late int portions;
  late String category;

  // การจัดเก็บ: ประเภทตามตารางอายุการเก็บรักษา (null = ไม่ตรงกับตาราง ใช้ค่า
  // ที่ Gemini ประเมิน), สถานะ (ดิบ/สุก ฯลฯ) และช่องที่เก็บ
  ShelfType? shelfType;
  late String foodState;
  late String storage;
  late ResolvedShelfLife shelfLife;

  static const List<String> baseUnits = [
    "ชิ้น",
    "หัว",
    "กรัม",
    "กก.",
    "แพ็ค",
    "ขวด",
    "ลูก",
    "ฟอง",
  ];

  @override
  void initState() {
    super.initState();
    final data = widget.initialData;

    nameController = TextEditingController(text: data['name'] ?? '');

    // ค่าเริ่มต้นถูกคำนวณไว้แล้วใน ResultScreen.initState อ่านกลับมาจากข้อมูล
    // ของชิ้นนี้ (การ์ดที่ถูกสร้างใหม่ตอนเลื่อนจอจะได้ไม่รีเซ็ตค่าที่ผู้ใช้เลือก)
    shelfType = findShelfType(data['shelf_type']?.toString());
    foodState = data['food_state']?.toString() ?? defaultStateFor(shelfType?.key);
    storage = data['storage']?.toString() ?? storageFridge;
    shelfLife = _resolve();
    expiryController = TextEditingController(
      text: (data['expiry_days'] ?? shelfLife.daysFor(storage) ?? 7).toString(),
    );

    final detected = num.tryParse(data['quantity']?.toString() ?? '') ?? 1;
    detectedQtyController = TextEditingController(text: _formatNum(detected));
    detectedQtyController.addListener(() {
      final val = num.tryParse(detectedQtyController.text);
      if (val != null && val > 0) widget.onUpdate('quantity', val);
    });
    widget.onUpdate('quantity', detected);
    // ใช้หน่วยที่ Gemini ตรวจพบจริง (ถ้าไม่อยู่ในรายการ ก็เพิ่มเข้าไปให้เลือก)
    unit = (data['unit']?.toString().trim().isNotEmpty ?? false)
        ? data['unit'].toString().trim()
        : 'ชิ้น';
    widget.onUpdate('unit', unit);

    useMode = data['use_mode']?.toString() ?? 'detected';
    portions = int.tryParse(data['portions']?.toString() ?? '') ?? 3;
    widget.onUpdate('use_mode', useMode);
    widget.onUpdate('portions', portions);
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
    detectedQtyController.dispose();
    super.dispose();
  }

  // ใช้ mapping กลางเดียวกับหน้าคลัง (Inventory) เพื่อให้อิโมจิหมวดหมู่ตรงกันทุกหน้า
  String _getEmoji(String cat) => categoryEmoji(cat);

  List<String> get units =>
      baseUnits.contains(unit) ? baseUnits : [unit, ...baseUnits];

  String _formatNum(num v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  InputDecoration _boxDecoration() => InputDecoration(
    isDense: true,
    filled: true,
    fillColor: Colors.grey[50],
    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.grey.shade300),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.grey.shade300),
    ),
  );

  Widget _sectionLabel(String text) => Text(
    text,
    style: const TextStyle(
      color: Colors.black87,
      fontSize: 13,
      fontWeight: FontWeight.w500,
    ),
  );

  // ส่วน "การนำไปใช้หัก" — แยกจากปริมาณที่ตรวจพบจากรูป ผู้ใช้กำหนดเองว่าจะ
  // ให้ระบบหักตามปริมาณจริง (เช่น 500 กรัม) หรือแบ่งเป็นส่วนบริโภค (เช่น 3 ส่วน)
  Widget _buildUsageSection() {
    final detectedText =
        "${detectedQtyController.text.isEmpty ? '-' : detectedQtyController.text} $unit";
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel("การนำไปใช้ (หักวัตถุดิบ)"),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildChip(
              label: "หักตามที่ตรวจพบ ($detectedText)",
              selected: useMode == 'detected',
              onTap: () {
                setState(() => useMode = 'detected');
                widget.onUpdate('use_mode', useMode);
              },
            ),
            _buildChip(
              label: "แบ่งเป็นส่วน",
              selected: useMode == 'portion',
              onTap: () {
                setState(() => useMode = 'portion');
                widget.onUpdate('use_mode', useMode);
              },
            ),
          ],
        ),
        if (useMode == 'portion') ...[
          const SizedBox(height: 8),
          Row(
            children: [
              _buildCounterButton("-", () {
                if (portions > 1) {
                  setState(() => portions--);
                  widget.onUpdate('portions', portions);
                }
              }),
              Container(
                width: 50,
                alignment: Alignment.center,
                child: Text(
                  "$portions",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.black87,
                  ),
                ),
              ),
              _buildCounterButton("+", () {
                setState(() => portions++);
                widget.onUpdate('portions', portions);
              }),
              const SizedBox(width: 10),
              const Text(
                "ส่วน",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 4),
        Text(
          useMode == 'portion'
              ? "แบ่ง $detectedText เป็น $portions ส่วน — ทำอาหารแล้วจะหักทีละส่วน"
              : "ทำอาหารแล้วจะหักตามปริมาณจริง ($unit)",
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
      ],
    );
  }

  ResolvedShelfLife _resolve() => resolveShelfLife(
    typeKey: shelfType?.key,
    state: foodState,
    geminiFridgeDays: widget.initialData['gemini_fridge_days'],
    geminiFreezerDays: widget.initialData['gemini_freezer_days'],
  );

  // ส่งค่าการจัดเก็บกลับไปเก็บในข้อมูลของวัตถุดิบชิ้นนี้ เพื่อใช้ตอนบันทึก
  void _pushShelfLife() {
    widget.onUpdate('storage', storage);
    widget.onUpdate('food_state', foodState);
    widget.onUpdate('fridge_days', shelfLife.fridgeDays);
    widget.onUpdate('freezer_days', shelfLife.freezerDays);
    widget.onUpdate(
      'expiry_days',
      int.tryParse(expiryController.text) ?? shelfLife.fridgeDays,
    );
  }

  // เปลี่ยนช่องที่เก็บ/สถานะแล้ว คำนวณวันหมดอายุเริ่มต้นใหม่ตามตาราง
  void _changeStorage({String? newStorage, String? newState}) {
    setState(() {
      if (newState != null) foodState = newState;
      shelfLife = _resolve();
      if (newStorage != null) storage = newStorage;
      if (shelfLife.daysFor(storage) == null) storage = storageFridge;
      expiryController.text = shelfLife.daysFor(storage).toString();
    });
    _pushShelfLife();
  }

  String _shelfSourceText() {
    if (shelfType == null) {
      return "ค่าเริ่มต้นจาก Gemini (ไม่ตรงกับตารางอายุการเก็บรักษา)";
    }
    final stateText = foodState.isEmpty ? "" : " ($foodState)";
    return "ค่าเริ่มต้นตามตาราง: ${shelfType!.label}$stateText "
        "${storageLabel(storage)}";
  }

  Widget _buildChip({
    required String label,
    required bool selected,
    VoidCallback? onTap,
  }) {
    final disabled = onTap == null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFFF7D0) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? const Color(0xFFFFD191) : Colors.black12,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: disabled ? Colors.black26 : Colors.black87,
          ),
        ),
      ),
    );
  }

  Widget _buildStorageSection() {
    final canFreeze = shelfLife.freezerDays != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "เก็บไว้ช่องไหน",
          style: TextStyle(
            color: Colors.black87,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildChip(
              label: "${storageEmoji(storageFridge)} ช่องปกติ",
              selected: storage == storageFridge,
              onTap: () => _changeStorage(newStorage: storageFridge),
            ),
            // แสดงตัวเลือกช่องแช่แข็งเฉพาะวัตถุดิบที่มีข้อมูลการแช่แข็ง
            if (canFreeze)
              _buildChip(
                label: "${storageEmoji(storageFreezer)} ช่องแช่แข็ง",
                selected: storage == storageFreezer,
                onTap: () => _changeStorage(newStorage: storageFreezer),
              ),
          ],
        ),
        if (shelfType?.noFreeze ?? false)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              "*ไม่ควรเก็บในช่องแช่แข็ง",
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ),
        if (shelfType != null && shelfType!.stateNames.isNotEmpty) ...[
          const SizedBox(height: 10),
          const Text(
            "สถานะ",
            style: TextStyle(
              color: Colors.black87,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: shelfType!.stateNames
                .map(
                  (st) => _buildChip(
                    label: st,
                    selected: foodState == st,
                    onTap: () => _changeStorage(newState: st),
                  ),
                )
                .toList(),
          ),
        ],
      ],
    );
  }

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

          // 3. ปริมาณที่ตรวจพบจากรูป (Gemini) — แก้ไขได้ถ้าตรวจพบไม่ตรง
          _sectionLabel("ปริมาณที่ตรวจพบจากรูป"),
          const SizedBox(height: 5),
          Row(
            children: [
              SizedBox(
                width: 90,
                child: TextFormField(
                  controller: detectedQtyController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                  decoration: _boxDecoration(),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: unit,
                  decoration: _boxDecoration(),
                  items: units
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

          // 4. การนำไปใช้หัก (ผู้ใช้กำหนดเอง แยกจากปริมาณที่ตรวจพบ)
          _buildUsageSection(),

          const SizedBox(height: 12),

          // 5. ช่องที่เก็บ + สถานะ (ใช้คำนวณวันหมดอายุเริ่มต้น)
          _buildStorageSection(),

          const SizedBox(height: 12),

          // 6. วันหมดอายุ (คำนวณอัตโนมัติจากตาราง แก้ไขเองได้)
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
          const SizedBox(height: 4),
          Text(
            _shelfSourceText(),
            style: const TextStyle(fontSize: 12, color: Colors.black54),
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
