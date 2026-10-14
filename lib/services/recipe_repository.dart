import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'fridge_stock.dart';

/// งานฝั่ง Supabase ทั้งหมดของฟีเจอร์สูตรอาหาร รวมไว้ที่เดียว
/// (หน้าจอจะได้ไม่ต้องเขียน query / logic เทียบวัตถุดิบซ้ำกันหลายที่)
class RecipeRepository {
  RecipeRepository._();

  static SupabaseClient get _db => Supabase.instance.client;

  /// bucket ใน Supabase Storage สำหรับรูปเมนูที่ผู้ใช้แนบ (หน้าเขียนสูตรเอง)
  static const imageBucket = 'recipe-images';

  // ---------------------------------------------------------------- Inventory

  static Future<List<Map<String, dynamic>>> fetchInventory() async {
    final res = await _db.from('fridge_items').select();
    return List<Map<String, dynamic>>.from(res);
  }

  // ------------------------------------------------------------- Number utils

  static num toNum(dynamic v) {
    if (v is num) return v;
    return num.tryParse(v?.toString() ?? '') ?? 0;
  }

  /// แปลงจำนวนที่ผู้ใช้พิมพ์ รองรับ "2", "0.5", "1/2", "1 1/2"
  /// คืน null ถ้าว่างหรืออ่านไม่ออก
  static num? parseQuantity(dynamic v) {
    if (v == null) return null;
    if (v is num) return v;
    final s = v.toString().trim().replaceAll(',', '.');
    if (s.isEmpty) return null;
    final direct = num.tryParse(s);
    if (direct != null) return direct;

    num total = 0;
    for (final part in s.split(RegExp(r'\s+'))) {
      if (part.contains('/')) {
        final f = part.split('/');
        if (f.length != 2) return null;
        final a = num.tryParse(f[0]);
        final b = num.tryParse(f[1]);
        if (a == null || b == null || b == 0) return null;
        total += a / b;
      } else {
        final n = num.tryParse(part);
        if (n == null) return null;
        total += n;
      }
    }
    return total;
  }

  /// แสดงตัวเลขสวยๆ: 2.0 -> "2", 0.5 -> "0.5"
  static String formatNum(dynamic v) {
    if (v == null) return '';
    final n = v is num ? v : num.tryParse(v.toString());
    if (n == null) return v.toString();
    if (n == n.roundToDouble()) return n.toInt().toString();
    return double.parse(n.toStringAsFixed(2)).toString();
  }

  // ------------------------------------------------------ Ingredient matching

  /// วัตถุดิบนี้มีในตู้เย็นพอไหม — เทียบชื่อแบบยืดหยุ่น + รวมทุกลอต (FIFO)
  /// ใช้ตรรกะเดียวกับตอนหักวัตถุดิบจริงใน RecipeDetailScreen
  static bool isIngredientAvailable(
    Map<String, dynamic> ingredient,
    List<Map<String, dynamic>> inventory,
  ) {
    final neededName = (ingredient['name'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    if (neededName.isEmpty) return false;
    final neededQty = toNum(ingredient['use_quantity']);

    final hasMatch = inventory.any((inv) {
      final invName = (inv['name'] ?? '').toString().trim().toLowerCase();
      return invName.isNotEmpty &&
          (invName == neededName ||
              invName.contains(neededName) ||
              neededName.contains(invName));
    });
    return hasMatch && availableQuantity(inventory, neededName) >= neededQty;
  }

  /// (มีครบกี่ชนิด, ต้องใช้ทั้งหมดกี่ชนิด)
  static (int, int) completeness(
    Map<String, dynamic> recipe,
    List<Map<String, dynamic>> inventory,
  ) {
    final list = ingredientsOf(recipe);
    final have = list.where((i) => isIngredientAvailable(i, inventory)).length;
    return (have, list.length);
  }

  static List<Map<String, dynamic>> ingredientsOf(Map<String, dynamic> recipe) {
    final raw = recipe['detailed_ingredients'];
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  // -------------------------------------------------------------------- Save

  /// บันทึกสูตรลงตาราง scanned_recipes
  /// คืนค่า false ถ้าบันทึกสูตรได้ แต่อัปโหลดรูปไม่สำเร็จ
  static Future<bool> saveRecipe(
    Map<String, dynamic> recipe, {
    Uint8List? imageBytes,
  }) async {
    final user = _db.auth.currentUser;
    if (user == null) throw 'ไม่พบผู้ใช้งาน กรุณาเข้าสู่ระบบใหม่';

    String? imageUrl;
    var imageOk = true;
    if (imageBytes != null) {
      imageUrl = await _uploadImage(user.id, imageBytes);
      imageOk = imageUrl != null;
    }

    final ingredients = ingredientsOf(recipe);
    final name = (recipe['recipe_name'] ?? '').toString().trim();

    await _db.from('scanned_recipes').insert({
      'user_id': user.id,
      'recipe_name': name.isEmpty ? 'ไม่มีชื่อเมนู' : name,
      'time': recipe['time'],
      'servings': recipe['servings'],
      'ingredients_used':
          recipe['ingredients_used'] ??
          ingredients.map((e) => e['name']).toList(),
      'detailed_ingredients': ingredients,
      'instructions': recipe['instructions'] ?? [],
      if (imageUrl != null) 'image_url': imageUrl,
    });
    return imageOk;
  }

  static Future<String?> _uploadImage(String uid, Uint8List bytes) async {
    try {
      final path = '$uid/${DateTime.now().millisecondsSinceEpoch}.jpg';
      await _db.storage
          .from(imageBucket)
          .uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(contentType: 'image/jpeg'),
          );
      return _db.storage.from(imageBucket).getPublicUrl(path);
    } catch (e) {
      debugPrint('อัปโหลดรูปเมนูไม่สำเร็จ: $e');
      return null;
    }
  }
}
