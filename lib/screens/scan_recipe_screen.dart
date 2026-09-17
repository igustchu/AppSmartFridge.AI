import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../widgets/app_bottom_nav.dart';
import '../widgets/app_icons.dart';
import '../widgets/recipe_flow_widgets.dart';
import 'scan_recipe_result_screen.dart';
import 'saved_recipes_screen.dart';

/// ทางลัด "สแกนสูตรอาหาร" จากเมนูหลัก (เมนูตะแกรงหน้าแรก)
/// ผู้ใช้ขอให้เข้ามาแล้วเจอหน้าคลังสูตรอาหารที่บันทึกไว้แล้วเลย แทนที่จะพา
/// เข้ากล้องสแกนทันที — ถ้าจะสแกนสูตรใหม่ ให้กดปุ่ม + ในหน้าคลังสูตรอาหารแทน
/// (ตัวหน้ากล้องสแกนจริงๆ ย้ายไปอยู่ที่ ScanRecipeCaptureScreen ด้านล่าง)
class ScanRecipeScreen extends StatelessWidget {
  const ScanRecipeScreen({super.key});

  @override
  Widget build(BuildContext context) => const SavedRecipesScreen();
}

/// หน้าสแกนสูตรอาหาร (ตามดีไซน์ใน Figma: "Scan Smart Recipe")
/// ถ่ายรูป/เลือกรูปสูตรอาหาร แล้วให้ Gemini แกะออกมาเป็นสูตร
/// จากนั้นพาไปหน้าผลลัพธ์เพื่อตรวจสอบวัตถุดิบกับของจริงในตู้เย็นก่อนบันทึก
/// (เข้าถึงได้จากปุ่ม + ในหน้าคลังสูตรอาหาร SavedRecipesScreen)
class ScanRecipeCaptureScreen extends StatefulWidget {
  const ScanRecipeCaptureScreen({super.key});

  @override
  State<ScanRecipeCaptureScreen> createState() =>
      _ScanRecipeCaptureScreenState();
}

class _ScanRecipeCaptureScreenState extends State<ScanRecipeCaptureScreen> {
  final ImagePicker _picker = ImagePicker();
  final String _apiKey = '';

  List<Map<String, dynamic>> _recentRecipes = [];
  bool _isLoadingRecent = true;

  @override
  void initState() {
    super.initState();
    _fetchRecentRecipes();
  }

  // ดึงสูตรอาหารที่สแกนไว้ล่าสุด 3 รายการจาก Supabase (ของจริง ไม่ใช่ mock)
  Future<void> _fetchRecentRecipes() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        if (mounted) setState(() => _isLoadingRecent = false);
        return;
      }
      final response = await Supabase.instance.client
          .from('scanned_recipes')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false)
          .limit(3);

      if (mounted) {
        setState(() {
          _recentRecipes = List<Map<String, dynamic>>.from(response);
          _isLoadingRecent = false;
        });
      }
    } catch (e) {
      // แสดง error จริงออกมาแทนที่จะกลืนเงียบๆ เพื่อให้ตรวจจับปัญหา เช่น
      // Row Level Security (RLS) บน Supabase บล็อกการอ่านได้ง่ายขึ้น
      debugPrint('โหลดสูตรอาหารล่าสุดไม่สำเร็จ: $e');
      if (mounted) setState(() => _isLoadingRecent = false);
    }
  }

  Future<void> _pickAndAnalyzeImage(ImageSource source) async {
    if (!mounted) return;
    try {
      // จำกัดความกว้าง/คุณภาพรูปก่อนส่งให้ AI เพื่อลดขนาดไฟล์
      // (รูปจากกล้องความละเอียดสูงทำให้อัพโหลดช้าจนเกิน timeout ได้)
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 85,
      );
      if (image == null) return;

      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const PopScope(
          canPop: false,
          child: Center(child: CircularProgressIndicator(color: Colors.blue)),
        ),
      );

      final model = GenerativeModel(model: 'gemini-3.6-flash', apiKey: _apiKey);
      final imageBytes = await image.readAsBytes();

      final prompt = TextPart("""
        วิเคราะห์สูตรอาหารจากรูปภาพนี้ (อาจเป็นภาพถ่ายจากตำรา หนังสือ ใบสั่งอาหาร หรือลายมือ)
        ตอบกลับมาเป็น JSON Object เท่านั้น ตามรูปแบบนี้เป๊ะๆ:
        {
          "recipe_name": "ชื่อเมนู",
          "time": "เวลาทำ (เช่น 30 นาที)",
          "servings": "จำนวนที่ได้ (เช่น 2 ที่)",
          "ingredients_used": ["วัตถุดิบหลัก1", "วัตถุดิบหลัก2"],
          "detailed_ingredients": [
            {"name": "ชื่อวัตถุดิบภาษาไทย", "use_quantity": จำนวนเลข(ใส่แค่เลข), "unit": "หน่วย"}
          ],
          "instructions": [
            "1. ขั้นตอนแรก...",
            "2. ขั้นตอนต่อไป..."
          ]
        }
        ห้ามมีข้อความอธิบายอื่น และ ห้ามมี Markdown ```json
      """);

      final response = await model
          .generateContent([
            Content.multi([prompt, DataPart('image/jpeg', imageBytes)]),
          ])
          .timeout(const Duration(seconds: 60));

      if (mounted && Navigator.canPop(context)) Navigator.pop(context);

      if (response.text != null) {
        String cleanJson = response.text!
            .replaceAll('```json', '')
            .replaceAll('```', '')
            .trim();

        dynamic decoded = jsonDecode(cleanJson);
        Map<String, dynamic> recipe = decoded is Map
            ? Map<String, dynamic>.from(decoded)
            : <String, dynamic>{};

        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ScanRecipeResultScreen(recipe: recipe),
            ),
          ).then((_) {
            // พอกลับมาจากหน้าผลลัพธ์ (บันทึกแล้วหรือยกเลิก) รีเฟรชรายการล่าสุด
            _fetchRecentRecipes();
          });
        }
      }
    } catch (e) {
      if (mounted && Navigator.canPop(context)) Navigator.pop(context);
      final isTimeout = e is TimeoutException;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isTimeout
                ? "การวิเคราะห์รูปใช้เวลานานเกินไป กรุณาลองใหม่อีกครั้ง (เช็คสัญญาณอินเทอร์เน็ตด้วย)"
                : "เกิดข้อผิดพลาด: $e",
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFD8EEFF),
      bottomNavigationBar: const AppBottomNav(current: AppTab.scan),
      body: SafeArea(
        child: Column(
          children: [
            RecipeFlowHeader(title: "สแกนสูตรอาหาร"),
            const SizedBox(height: 15),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  children: [
                    _ScanOptionCard(
                      icon: Icons.camera_alt_outlined,
                      title: "ถ่ายรูปสูตรอาหาร",
                      subtitle: "เปิดกล้องเพื่อสแกน",
                      onTap: () => _pickAndAnalyzeImage(ImageSource.camera),
                    ),
                    const SizedBox(height: 15),
                    _ScanOptionCard(
                      icon: Icons.image_outlined,
                      title: "เลือกจากคลังรูปภาพ",
                      subtitle: "อัพโหลดรูปภาพที่มีอยู่",
                      onTap: () => _pickAndAnalyzeImage(ImageSource.gallery),
                    ),
                    const SizedBox(height: 20),

                    // เคล็ดลับการสแกน
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
                          const Text(
                            "เคล็ดลับการสแกน",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _buildTipItem("ถ่ายรูปในที่ที่มีแสงสว่างเพียงพอ"),
                          _buildTipItem("จัดมุมมองให้อยู่ในแนวตรงและวางราบ"),
                          _buildTipItem("เน้นความคมชัดและโฟกัสที่ตัวหนังสือ"),
                          _buildTipItem("ครอบตัดเอาเฉพาะเนื้อหาที่สำคัญ"),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // สูตรอาหารที่สแกนล่าสุด (ดึงจาก Supabase จริง)
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
                          const Text(
                            "สูตรอาหารที่สแกนล่าสุด",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _isLoadingRecent
                              ? const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(10.0),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                )
                              : _recentRecipes.isEmpty
                              ? const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 10.0),
                                  child: Text(
                                    "ยังไม่มีประวัติการสแกนสูตรอาหาร",
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 13,
                                    ),
                                  ),
                                )
                              : Column(
                                  children: _recentRecipes.map((r) {
                                    return _buildRecentItem(
                                      r['recipe_name'] ?? 'ไม่มีชื่อเมนู',
                                      relativeTimeThai(
                                        r['created_at']?.toString(),
                                      ),
                                    );
                                  }).toList(),
                                ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTipItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          const CheckIcon(size: 18),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(color: Colors.black87, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentItem(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.black87,
              fontSize: 15,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(color: Colors.black54, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _ScanOptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ScanOptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        splashColor: Colors.blue.withOpacity(0.15),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 5,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                height: 70,
                width: 70,
                decoration: const BoxDecoration(
                  color: Color(0xFFE3F2FD),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 32, color: const Color(0xff5189C9)),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black54, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
