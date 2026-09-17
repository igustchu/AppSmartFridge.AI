import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/app_icons.dart';
import '../widgets/recipe_flow_widgets.dart';

/// หน้ารายละเอียดสูตรอาหารที่บันทึกไว้ (ตามดีไซน์ใน Figma: "Smart Recipe" หน้าเมนู)
/// เปิดจากการกดเลือกสูตรในหน้าคลังสูตรอาหาร
/// เทียบวัตถุดิบที่ต้องใช้กับของจริงในตู้เย็น (Supabase) แบบสดเสมอ
class RecipeDetailScreen extends StatefulWidget {
  final Map<String, dynamic> recipe;
  final List<Map<String, dynamic>>
  inventory; // รับข้อมูลคลังเพื่อเอามาเทียบหักลบ
  // ข้อความบนแคปซูลหัวเรื่อง — ค่าเริ่มต้นใช้กับสูตรที่บันทึกไว้แล้ว
  // ส่วนตอนเปิดจากหน้า "สร้างเมนูอาหาร (AI)" จะส่ง "เมนูแนะนำ" มาแทน
  // ให้ตรงกับดีไซน์ Figma ของแต่ละที่มา
  final String headerTitle;

  const RecipeDetailScreen({
    super.key,
    required this.recipe,
    required this.inventory,
    this.headerTitle = "สูตรเมนูอาหาร",
  });

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  bool _isCooking = false;
  bool _isDeleting = false;

  num _toNum(dynamic v) {
    if (v is num) return v;
    return num.tryParse(v?.toString() ?? '') ?? 0;
  }

  // แสดง "ไม่ได้ระบุ" แทนที่จะปล่อยว่างเปล่า เมื่อ AI ไม่ได้ระบุปริมาณ/หน่วยของ
  // วัตถุดิบชิ้นนั้นมาให้ (เช่น รูปสูตรต้นฉบับไม่ได้เขียนปริมาณกำกับไว้)
  String _formatQty(Map<String, dynamic> ing) {
    final qty = ing['use_quantity'];
    final unit = (ing['unit'] ?? '').toString().trim();
    final qtyText = (qty == null || qty.toString().trim().isEmpty)
        ? ''
        : qty.toString().trim();
    final combined = [qtyText, unit].where((s) => s.isNotEmpty).join(' ');
    return combined.isEmpty ? 'ไม่ได้ระบุ' : combined;
  }

  // เช็คว่าวัตถุดิบที่สูตรต้องการ มีในตู้เย็นพอไหม (เทียบชื่อ + จำนวน)
  bool _isIngredientAvailable(Map<String, dynamic> needed) {
    final neededName = (needed['name'] ?? '').toString();
    final neededQty = _toNum(needed['use_quantity']);
    final match = widget.inventory
        .where((inv) => (inv['name'] ?? '').toString() == neededName)
        .toList();
    if (match.isEmpty) return false;
    final haveQty = _toNum(match.first['quantity']);
    return haveQty >= neededQty;
  }

  // ฟังก์ชันหักวัตถุดิบออกจาก Supabase
  Future<void> _startCooking() async {
    // แจ้งเตือนยืนยัน
    bool confirm =
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("เริ่มทำอาหาร?"),
            content: const Text(
              "ระบบจะทำการหักวัตถุดิบที่ใช้ในเมนูนี้ออกจากคลังของคุณอัตโนมัติ",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text("ยกเลิก"),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: TextButton.styleFrom(foregroundColor: const Color(0xff5189C9)),
                child: const Text("ตกลง, หักวัตถุดิบเลย"),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirm) return;

    setState(() => _isCooking = true);

    try {
      final supabase = Supabase.instance.client;
      List<dynamic> detailedIngredients =
          widget.recipe['detailed_ingredients'] ?? [];

      // วนลูปเช็ควัตถุดิบที่ AI บอกว่าต้องใช้
      for (var needed in detailedIngredients) {
        String neededName = needed['name'] ?? '';
        int neededQty = (needed['use_quantity'] is int)
            ? needed['use_quantity']
            : int.tryParse(needed['use_quantity'].toString()) ?? 0;

        // หาวัตถุดิบในตู้เย็นที่ชื่อตรงกัน
        var matchedItem = widget.inventory
            .where((inv) => inv['name'] == neededName)
            .firstOrNull;

        if (matchedItem != null && neededQty > 0) {
          int currentQty = matchedItem['quantity'] ?? 0;
          int newQty = currentQty - neededQty;
          if (newQty < 0) newQty = 0; // ป้องกันเลขติดลบ

          // อัปเดตยอดใน Database
          await supabase
              .from('fridge_items')
              .update({'quantity': newQty})
              .eq('item_id', matchedItem['item_id']);
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("ทำอาหารเสร็จสิ้น! หักวัตถุดิบเรียบร้อยแล้ว 🍲"),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(
          context,
          true,
        ); // ส่งค่า true กลับไปให้หน้าเดิมรีเฟรชตู้เย็น
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("เกิดข้อผิดพลาด: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isCooking = false);
    }
  }

  // ลบสูตรอาหารนี้ออกจาก Supabase จริง
  Future<void> _deleteRecipe() async {
    final recipeName = widget.recipe['recipe_name'] ?? 'สูตรนี้';
    final confirm =
        await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("ลบสูตรอาหารนี้?"),
            content: Text("ต้องการลบ \"$recipeName\" ออกจากคลังสูตรอาหารใช่ไหม"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text("ยกเลิก"),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text("ลบ"),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirm) return;

    setState(() => _isDeleting = true);
    try {
      await Supabase.instance.client
          .from('scanned_recipes')
          .delete()
          .eq('id', widget.recipe['id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("ลบสูตรอาหารเรียบร้อยแล้ว"),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // กลับไปหน้ารายการแล้วรีเฟรช
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ลบไม่สำเร็จ: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final recipe = widget.recipe;
    List<dynamic> instructions = recipe['instructions'] ?? [];
    List<dynamic> detailedIngredients = recipe['detailed_ingredients'] ?? [];

    final availableCount = detailedIngredients
        .where((e) => _isIngredientAvailable(Map<String, dynamic>.from(e)))
        .length;

    return Scaffold(
      backgroundColor: const Color(0xFFD8EEFF),
      bottomNavigationBar: const AppBottomNav(current: AppTab.scan),
      body: SafeArea(
        child: Column(
          children: [
            RecipeFlowHeader(title: widget.headerTitle),
            const SizedBox(height: 15),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ชื่อเมนู (กล่องขาวตรงกลาง ตามดีไซน์)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        recipe['recipe_name'] ?? 'ไม่มีชื่อเมนู',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // สถานะวัตถุดิบ (ของจริงจากฐานข้อมูล ไม่ใช่ mock)
                    RecipeStatusBar(
                      label: "สถานะวัตถุดิบ",
                      have: availableCount,
                      total: detailedIngredients.length,
                    ),
                    const SizedBox(height: 20),

                    // วัตถุดิบที่ต้องใช้
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 5,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF7D0),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text(
                                  "วัตถุดิบที่ต้องใช้",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                              const EditPillButton(),
                            ],
                          ),
                          const SizedBox(height: 14),
                          ...detailedIngredients.map((ing) {
                            final ingMap = Map<String, dynamic>.from(ing);
                            final available = _isIngredientAvailable(ingMap);
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10.0),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      SizedBox(
                                        width: 20,
                                        child: available
                                            ? const CheckIcon(size: 18)
                                            : null,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        ingMap['name'] ?? '',
                                        style: const TextStyle(
                                          fontSize: 15,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    _formatQty(ingMap),
                                    style: TextStyle(
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ขั้นตอนการทำ
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 5,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF7D0),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text(
                                  "ขั้นตอนการทำ",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                              const EditPillButton(),
                            ],
                          ),
                          const SizedBox(height: 14),
                          ...instructions.map((step) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12.0),
                              child: Text(
                                step.toString(),
                                style: const TextStyle(
                                  fontSize: 15,
                                  height: 1.5,
                                  color: Colors.black87,
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),

            // ปุ่มด้านล่าง: ลบสูตรนี้ / เริ่มทำอาหาร (หักวัตถุดิบ)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                    offset: Offset(0, -3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  SizedBox(
                    height: 55,
                    width: 55,
                    child: OutlinedButton(
                      onPressed: _isDeleting ? null : _deleteRecipe,
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        side: const BorderSide(color: Colors.redAccent),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      child: _isDeleting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.redAccent,
                              ),
                            )
                          : const Icon(
                              Icons.delete_outline,
                              color: Colors.redAccent,
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 55,
                      child: ElevatedButton(
                        onPressed: _isCooking ? null : _startCooking,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xffffd84d),
                          foregroundColor: const Color(0xff5189C9),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        child: _isCooking
                            ? const CircularProgressIndicator(
                                color: Color(0xff5189C9),
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.soup_kitchen,
                                    size: 24,
                                    color: Color(0xff5189C9),
                                  ),
                                  SizedBox(width: 10),
                                  Text(
                                    "Cooking (หักวัตถุดิบ)",
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xff5189C9),
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
