import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../widgets/app_bottom_nav.dart';
import '../widgets/app_icons.dart';
import '../widgets/recipe_flow_widgets.dart';
import 'saved_recipes_screen.dart';

/// หน้าแสดงผลลัพธ์การสแกนสูตรอาหาร (ตามดีไซน์ใน Figma: "Result Smart Recipe")
/// เทียบรายการวัตถุดิบที่สูตรต้องใช้กับของจริงในตู้เย็น (Supabase) แบบสด
/// ก่อนให้ผู้ใช้กด "บันทึกสูตร" เข้าคลังสูตรอาหารของตัวเอง
class ScanRecipeResultScreen extends StatefulWidget {
  final Map<String, dynamic> recipe;

  const ScanRecipeResultScreen({super.key, required this.recipe});

  @override
  State<ScanRecipeResultScreen> createState() =>
      _ScanRecipeResultScreenState();
}

class _ScanRecipeResultScreenState extends State<ScanRecipeResultScreen> {
  bool _isLoadingInventory = true;
  bool _isSaving = false;
  List<Map<String, dynamic>> _inventory = [];

  @override
  void initState() {
    super.initState();
    _fetchInventory();
  }

  // ดึงวัตถุดิบจริงในตู้เย็นจาก Supabase มาใช้เทียบ (ห้ามใช้ตัวเลขจาก mock)
  Future<void> _fetchInventory() async {
    try {
      final response = await Supabase.instance.client
          .from('fridge_items')
          .select();
      if (mounted) {
        setState(() {
          _inventory = List<Map<String, dynamic>>.from(response);
          _isLoadingInventory = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingInventory = false);
    }
  }

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
    final match = _inventory
        .where((inv) => (inv['name'] ?? '').toString() == neededName)
        .toList();
    if (match.isEmpty) return false;
    final haveQty = _toNum(match.first['quantity']);
    return haveQty >= neededQty;
  }

  Future<void> _saveRecipe() async {
    setState(() => _isSaving = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        throw "ไม่พบผู้ใช้งาน กรุณาเข้าสู่ระบบใหม่";
      }

      final recipe = widget.recipe;
      await Supabase.instance.client.from('scanned_recipes').insert({
        'user_id': user.id,
        'recipe_name': recipe['recipe_name'] ?? 'ไม่มีชื่อเมนู',
        'time': recipe['time'],
        'servings': recipe['servings'],
        'ingredients_used': recipe['ingredients_used'] ?? [],
        'detailed_ingredients': recipe['detailed_ingredients'] ?? [],
        'instructions': recipe['instructions'] ?? [],
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("บันทึกสูตรอาหารเรียบร้อยแล้ว 📖"),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const SavedRecipesScreen()),
          (route) => route.isFirst,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("บันทึกไม่สำเร็จ: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
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
            RecipeFlowHeader(title: "สูตรเมนูอาหาร"),
            const SizedBox(height: 15),
            Expanded(
              child: _isLoadingInventory
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xff5189C9),
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ชื่อเมนู (กล่องขาวตรงกลาง ตามดีไซน์)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              vertical: 14,
                            ),
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
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFF7D0),
                                        borderRadius:
                                            BorderRadius.circular(20),
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
                                  final ingMap = Map<String, dynamic>.from(
                                    ing,
                                  );
                                  final available = _isIngredientAvailable(
                                    ingMap,
                                  );
                                  return Padding(
                                    padding: const EdgeInsets.only(
                                      bottom: 10.0,
                                    ),
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
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFF7D0),
                                        borderRadius:
                                            BorderRadius.circular(20),
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
                                    padding: const EdgeInsets.only(
                                      bottom: 12.0,
                                    ),
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

            // ปุ่มด้านล่าง: สแกนใหม่ / บันทึกสูตร
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
                  Expanded(
                    child: SizedBox(
                      height: 55,
                      child: ElevatedButton(
                        onPressed: _isSaving
                            ? null
                            : () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey.shade400,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        child: const Text(
                          "สแกนใหม่",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: SizedBox(
                      height: 55,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveRecipe,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE3F2FD),
                          foregroundColor: const Color(0xff5189C9),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        child: _isSaving
                            ? const CircularProgressIndicator(
                                color: Color(0xff5189C9),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  ColorFiltered(
                                    colorFilter: ColorFilter.mode(
                                      Color(0xff5189C9),
                                      BlendMode.srcIn,
                                    ),
                                    child: CheckIcon(size: 18),
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    "บันทึกสูตร",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
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
