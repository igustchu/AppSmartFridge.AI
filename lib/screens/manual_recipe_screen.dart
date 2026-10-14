import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/recipe_repository.dart';
import '../widgets/add_recipe_widgets.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/recipe_flow_widgets.dart';

/// หน่วยครัวที่เลือกได้ — รองรับทั้งน้ำหนัก, ช้อน/ถ้วย, นับชิ้น/ส่วน
/// และ "%" สำหรับกะด้วยสายตา (เช่น ใช้นม 50% ของขวด)
/// สัดส่วนอย่าง "ครึ่งหัว" ให้พิมพ์จำนวนเป็น 1/2 แล้วเลือกหน่วย "หัว"
const kRecipeUnits = <String>[
  'กรัม',
  'กิโลกรัม',
  'มิลลิลิตร',
  'ลิตร',
  'ช้อนโต๊ะ',
  'ช้อนชา',
  'ถ้วย',
  'ฟอง',
  'ชิ้น',
  'ลูก',
  'หัว',
  'กลีบ',
  'เม็ด',
  'ต้น',
  'กำ',
  'แพ็ค',
  'ส่วน',
  '%',
];

/// หน้า "เขียนสูตรอาหาร" (ตามดีไซน์ใน Figma)
///
/// ใช้ได้ 2 โหมด:
/// - ปกติ: สร้างสูตรใหม่แล้วบันทึกลง Supabase -> pop(true)
///   ปุ่ม "สแกนใหม่" -> pop(AddRecipeOption.scan) ให้หน้าคลังสูตรพาไปหน้าสแกน
/// - returnOnly: ใช้เป็นฟอร์มแก้ไขสูตรจาก AI -> pop(Map ที่แก้แล้ว) ไม่บันทึกเอง
class ManualRecipeScreen extends StatefulWidget {
  final Map<String, dynamic>? initialRecipe;
  final bool returnOnly;
  final bool showAiDisclaimer;

  const ManualRecipeScreen({
    super.key,
    this.initialRecipe,
    this.returnOnly = false,
    this.showAiDisclaimer = false,
  });

  @override
  State<ManualRecipeScreen> createState() => _ManualRecipeScreenState();
}

class _IngredientRow {
  final TextEditingController name;
  final TextEditingController qty;
  String? unit;

  _IngredientRow({String name = '', String qty = '', this.unit})
    : name = TextEditingController(text: name),
      qty = TextEditingController(text: qty);

  void dispose() {
    name.dispose();
    qty.dispose();
  }
}

class _ManualRecipeScreenState extends State<ManualRecipeScreen> {
  final _picker = ImagePicker();
  final _nameCtrl = TextEditingController();
  final _timeCtrl = TextEditingController();
  final _servingsCtrl = TextEditingController();
  final List<_IngredientRow> _ingredients = [];
  final List<TextEditingController> _steps = [];

  Uint8List? _imageBytes;
  bool _isSaving = false;

  static final _stepNumberPrefix = RegExp(r'^\s*\d+\s*[\.\)]\s*');

  @override
  void initState() {
    super.initState();
    final r = widget.initialRecipe;
    if (r != null) {
      _nameCtrl.text = (r['recipe_name'] ?? '').toString();
      _timeCtrl.text = (r['time'] ?? '').toString();
      _servingsCtrl.text = (r['servings'] ?? '').toString();
      for (final ing in RecipeRepository.ingredientsOf(r)) {
        final unit = (ing['unit'] ?? '').toString().trim();
        _ingredients.add(
          _IngredientRow(
            name: (ing['name'] ?? '').toString(),
            qty: RecipeRepository.formatNum(ing['use_quantity']),
            unit: unit.isEmpty ? null : unit,
          ),
        );
      }
      final rawSteps = r['instructions'];
      if (rawSteps is List) {
        for (final s in rawSteps) {
          _steps.add(
            TextEditingController(
              text: s.toString().replaceFirst(_stepNumberPrefix, ''),
            ),
          );
        }
      }
    }
    // ฟอร์มเปล่าเริ่มที่ 3 ช่อง ตาม Figma
    while (_ingredients.length < 3) {
      _ingredients.add(_IngredientRow());
    }
    while (_steps.length < 3) {
      _steps.add(TextEditingController());
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _timeCtrl.dispose();
    _servingsCtrl.dispose();
    for (final r in _ingredients) {
      r.dispose();
    }
    for (final c in _steps) {
      c.dispose();
    }
    super.dispose();
  }

  void _snack(String text, {Color color = Colors.red}) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(text), backgroundColor: color));
  }

  // -------------------------------------------------------------- Image

  Future<void> _pickImage() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('ถ่ายภาพ'),
              onTap: () => Navigator.pop(ctx, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('เลือกจากคลังรูปภาพ'),
              onTap: () => Navigator.pop(ctx, 'gallery'),
            ),
            if (_imageBytes != null)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text(
                  'ลบรูปภาพ',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () => Navigator.pop(ctx, 'remove'),
              ),
          ],
        ),
      ),
    );
    if (action == null || !mounted) return;
    if (action == 'remove') {
      setState(() => _imageBytes = null);
      return;
    }
    try {
      final file = await _picker.pickImage(
        source: action == 'camera' ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 1200,
        imageQuality: 80,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (mounted) setState(() => _imageBytes = bytes);
    } catch (e) {
      if (mounted) _snack('เปิดรูปภาพไม่สำเร็จ: $e');
    }
  }

  // --------------------------------------------------------------- Save

  /// รวมข้อมูลในฟอร์มเป็น Map (รูปแบบเดียวกับสูตรที่ AI สแกน)
  /// คืน null ถ้าข้อมูลยังไม่ครบ (และแจ้งผู้ใช้แล้ว)
  Map<String, dynamic>? _collectRecipe() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      _snack('กรุณากรอกชื่อเมนู');
      return null;
    }

    final ingredients = <Map<String, dynamic>>[];
    for (final row in _ingredients) {
      final ingName = row.name.text.trim();
      if (ingName.isEmpty) continue;
      final qtyText = row.qty.text.trim();
      final qty = RecipeRepository.parseQuantity(qtyText);
      if (qtyText.isNotEmpty && qty == null) {
        _snack('จำนวนของ "$ingName" ไม่ถูกต้อง (ใช้ตัวเลข เช่น 2, 0.5 หรือ 1/2)');
        return null;
      }
      ingredients.add({
        'name': ingName,
        'use_quantity': qty,
        'unit': row.unit ?? '',
      });
    }
    if (ingredients.isEmpty) {
      _snack('กรุณาเพิ่มวัตถุดิบอย่างน้อย 1 รายการ');
      return null;
    }

    final steps = _steps
        .map((c) => c.text.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    String? orNull(String s) => s.trim().isEmpty ? null : s.trim();

    return {
      ...?widget.initialRecipe,
      'recipe_name': name,
      'time': orNull(_timeCtrl.text),
      'servings': orNull(_servingsCtrl.text),
      'ingredients_used': ingredients.map((e) => e['name']).toList(),
      'detailed_ingredients': ingredients,
      'instructions': [
        for (var i = 0; i < steps.length; i++) '${i + 1}. ${steps[i]}',
      ],
    };
  }

  Future<void> _onPrimary() async {
    FocusScope.of(context).unfocus();
    final recipe = _collectRecipe();
    if (recipe == null) return;

    if (widget.returnOnly) {
      Navigator.pop(context, recipe);
      return;
    }

    setState(() => _isSaving = true);
    try {
      final imageOk = await RecipeRepository.saveRecipe(
        recipe,
        imageBytes: _imageBytes,
      );
      if (!mounted) return;
      _snack(
        imageOk
            ? 'บันทึกสูตรอาหารเรียบร้อยแล้ว 📖'
            : 'บันทึกสูตรแล้ว แต่อัปโหลดรูปไม่สำเร็จ',
        color: imageOk ? Colors.green : Colors.orange,
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      _snack('บันทึกไม่สำเร็จ: $e');
    }
  }

  void _onSecondary() {
    if (widget.returnOnly) {
      Navigator.pop(context);
    } else {
      Navigator.pop(context, AddRecipeOption.scan);
    }
  }

  // -------------------------------------------------------------- Build

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kRecipeBg,
      bottomNavigationBar: const AppBottomNav(current: AppTab.scan),
      body: SafeArea(
        child: Column(
          children: [
            RecipeFlowHeader(
              title: widget.returnOnly ? 'แก้ไขสูตรอาหาร' : 'เขียนสูตรอาหาร',
            ),
            const SizedBox(height: 15),
            Expanded(
              child: GestureDetector(
                onTap: () => FocusScope.of(context).unfocus(),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  children: [
                    if (widget.showAiDisclaimer) ...[
                      const AiDisclaimerBanner(),
                      const SizedBox(height: 14),
                    ],
                    if (!widget.returnOnly) ...[
                      _buildImagePicker(),
                      const SizedBox(height: 18),
                    ],
                    _label('ชื่อเมนู'),
                    _plainField(_nameCtrl, 'เช่น ผัดกะเพราไก่'),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _label('เวลาทำ'),
                              _plainField(_timeCtrl, 'เช่น 15 นาที'),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _label('จำนวนที่'),
                              _plainField(_servingsCtrl, 'เช่น 1 ที่'),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _label('วัตถุดิบที่ต้องใช้'),
                    RecipeSectionCard(
                      padding: const EdgeInsets.fromLTRB(10, 14, 10, 4),
                      child: Column(
                        children: [
                          for (var i = 0; i < _ingredients.length; i++)
                            _buildIngredientRow(i),
                          _addButton('เพิ่มวัตถุดิบ', () {
                            setState(() => _ingredients.add(_IngredientRow()));
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    _label('ขั้นตอนการทำ'),
                    RecipeSectionCard(
                      padding: const EdgeInsets.fromLTRB(10, 14, 10, 4),
                      child: Column(
                        children: [
                          for (var i = 0; i < _steps.length; i++)
                            _buildStepRow(i),
                          _addButton('เพิ่มขั้นตอน', () {
                            setState(
                              () => _steps.add(TextEditingController()),
                            );
                          }),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            RecipeBottomActions(
              secondaryLabel: widget.returnOnly ? 'ยกเลิก' : 'สแกนใหม่',
              onSecondary: _onSecondary,
              primaryLabel: widget.returnOnly ? 'ใช้การแก้ไข' : 'บันทึกสูตร',
              onPrimary: _onPrimary,
              isLoading: _isSaving,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePicker() {
    return Material(
      color: Colors.white,
      elevation: 1,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _pickImage,
        child: _imageBytes == null
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 22),
                child: Column(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: kRecipeYellow,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: kRecipeYellowBorder),
                      ),
                      child: const Icon(
                        Icons.camera_alt_outlined,
                        size: 30,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'เพิ่มรูปภาพเมนูอาหาร',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'แตะเพื่อเลือกรูปภาพหรือถ่ายภาพ',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ],
                ),
              )
            : Stack(
                children: [
                  Image.memory(
                    _imageBytes!,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.edit_outlined, size: 18),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(left: 2, bottom: 8),
    child: Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 15,
        color: Colors.black87,
      ),
    ),
  );

  Widget _plainField(TextEditingController ctrl, String hint) {
    return TextField(
      controller: ctrl,
      textInputAction: TextInputAction.next,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: Colors.white,
        hintText: hint,
        hintStyle: TextStyle(fontSize: 14, color: Colors.grey.shade500),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 13,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: kRecipeBlue, width: 1.5),
        ),
      ),
    );
  }

  InputDecoration _boxDecoration(String hint, {Widget? prefix}) {
    final radius = BorderRadius.circular(10);
    return InputDecoration(
      isDense: true,
      hintText: hint,
      hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade500),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      prefixIcon: prefix,
      prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
      enabledBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: Colors.grey.shade400),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: const BorderSide(color: kRecipeBlue, width: 1.5),
      ),
    );
  }

  Widget _removeButton(VoidCallback? onTap) {
    return SizedBox(
      width: 28,
      child: onTap == null
          ? null
          : IconButton(
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              tooltip: 'ลบ',
              icon: Icon(Icons.close, size: 18, color: Colors.grey.shade500),
              onPressed: onTap,
            ),
    );
  }

  Widget _buildIngredientRow(int i) {
    final row = _ingredients[i];
    final units = <String>{
      ...kRecipeUnits,
      if (row.unit != null && row.unit!.isNotEmpty) row.unit!,
    }.toList();

    return Padding(
      key: ObjectKey(row),
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 18,
            child: Text(
              '${i + 1}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: 5,
            child: TextField(
              controller: row.name,
              textInputAction: TextInputAction.next,
              style: const TextStyle(fontSize: 13),
              decoration: _boxDecoration('ชื่อวัตถุดิบ'),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: 2,
            child: TextField(
              controller: row.qty,
              // ใช้คีย์บอร์ดตัวอักษรเพื่อให้พิมพ์เศษส่วน เช่น 1/2 ได้
              keyboardType: TextInputType.text,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13),
              decoration: _boxDecoration('จำนวน'),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: 3,
            child: Container(
              height: 40,
              padding: const EdgeInsets.only(left: 8, right: 2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade400),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: (row.unit == null || row.unit!.isEmpty)
                      ? null
                      : row.unit,
                  isExpanded: true,
                  isDense: true,
                  hint: Text(
                    'หน่วย',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                  ),
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
                  style: const TextStyle(fontSize: 13, color: Colors.black87),
                  borderRadius: BorderRadius.circular(12),
                  menuMaxHeight: 320,
                  items: units
                      .map(
                        (u) => DropdownMenuItem(
                          value: u,
                          child: Text(u, overflow: TextOverflow.ellipsis),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => row.unit = v),
                ),
              ),
            ),
          ),
          _removeButton(
            _ingredients.length > 1
                ? () => setState(() {
                    _ingredients.removeAt(i);
                    // dispose หลังเฟรมนี้ ไม่งั้น TextField ที่ยังค้างอยู่จะใช้ controller ที่ถูกทำลายแล้ว
                    WidgetsBinding.instance.addPostFrameCallback(
                      (_) => row.dispose(),
                    );
                  })
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildStepRow(int i) {
    final ctrl = _steps[i];
    return Padding(
      key: ObjectKey(ctrl),
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: TextField(
              controller: ctrl,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.newline,
              style: const TextStyle(fontSize: 13, height: 1.4),
              decoration: _boxDecoration(
                'อธิบายขั้นตอน',
                prefix: Padding(
                  padding: const EdgeInsets.only(left: 10, right: 4),
                  child: Text(
                    '${i + 1}.',
                    style: const TextStyle(fontSize: 13, color: Colors.black87),
                  ),
                ),
              ),
            ),
          ),
          _removeButton(
            _steps.length > 1
                ? () => setState(() {
                    _steps.removeAt(i);
                    WidgetsBinding.instance.addPostFrameCallback(
                      (_) => ctrl.dispose(),
                    );
                  })
                : null,
          ),
        ],
      ),
    );
  }

  Widget _addButton(String label, VoidCallback onTap) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.add, size: 18),
        label: Text(label),
        style: TextButton.styleFrom(
          foregroundColor: Colors.black87,
          textStyle: const TextStyle(fontSize: 13),
        ),
      ),
    );
  }
}
