import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/category_icons.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/app_icons.dart';
import '../widgets/recipe_flow_widgets.dart';
import 'result_screen.dart';

/// หน้าถ่ายรูปวัตถุดิบเพื่อสแกนเข้าตู้เย็น (ตามดีไซน์ใน Figma: "SCAN")
/// รายการ "วัตถุดิบที่เพิ่มล่าสุด" ดึงจาก Supabase จริงเสมอ (ไม่ใช้ตัวเลข mock ของ Figma)
class ImageScanning extends StatefulWidget {
  const ImageScanning({super.key});

  @override
  State<ImageScanning> createState() => _ImageScanningState();
}

class _ImageScanningState extends State<ImageScanning> {
  final ImagePicker _picker = ImagePicker();
  final String _apiKey = '';

  List<Map<String, dynamic>> _recentItems = [];
  bool _isLoadingRecent = true;

  @override
  void initState() {
    super.initState();
    _fetchRecentItems();
  }

  // ดึงวัตถุดิบที่เพิ่มล่าสุด 3 รายการจาก Supabase (ของจริง ไม่ใช่ mock)
  Future<void> _fetchRecentItems() async {
    try {
      final response = await Supabase.instance.client
          .from('fridge_items')
          .select()
          .order('created_at', ascending: false)
          .limit(3);

      if (mounted) {
        setState(() {
          _recentItems = List<Map<String, dynamic>>.from(response);
          _isLoadingRecent = false;
        });
      }
    } catch (e) {
      debugPrint('โหลดวัตถุดิบล่าสุดไม่สำเร็จ: $e');
      if (mounted) {
        setState(() => _isLoadingRecent = false);
      }
    }
  }

  Future<void> _pickAndAnalyzeImage(ImageSource source) async {
    if (!mounted) return;
    try {
      // จำกัดขนาดรูปก่อนส่งเข้า Gemini — กล้องมือถือสมัยนี้ถ่ายได้ไฟล์ใหญ่มาก
      // (10+ MB) ถ้าส่งเต็มขนาดจริงจะอัพโหลดช้าและโมเดลประมวลผลช้าตามไปด้วย
      // โดยไม่ได้ช่วยให้แม่นยำขึ้นเลย (โมเดล vision ย่อภาพลงประมวลผลอยู่แล้ว)
      // ย่อเหลือด้านยาวสุดไม่เกิน 1024px และลดคุณภาพลงเล็กน้อยช่วยให้เร็วขึ้น
      // มากโดยไม่กระทบความแม่นยำในการจำแนกวัตถุดิบ
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );
      if (image == null) return;

      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        // จำกัดสเกลข้อความไว้ไม่ให้เกิน 1.3 เท่า เพราะถ้าเครื่องตั้งค่า
        // ขนาดตัวอักษรใหญ่พิเศษ (Accessibility > Larger Text) ไว้สูงมาก
        // ป้ายข้อความเล็กๆ ในไดอะล็อกนี้จะขยายจนล้นทับเนื้อหาข้างหลังได้
        // (การ์ดสีขาวช่วยให้ดูเป็นกล่องไดอะล็อกจริงๆ ไม่ใช่ตัวหนังสือลอย
        // ทับพื้นหลังตรงๆ ด้วย)
        builder: (ctx) => PopScope(
          canPop: false,
          child: MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1.3,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 24,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.blue),
                    SizedBox(height: 16),
                    Text(
                      "กำลังวิเคราะห์วัตถุดิบ...",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      final model = GenerativeModel(model: 'gemini-3.6-flash', apiKey: _apiKey);
      final imageBytes = await image.readAsBytes();

      final prompt = TextPart("""
วิเคราะห์วัตถุดิบทั้งหมดในรูปภาพ (อาจมีหลายชิ้น)
ตอบกลับมาเป็น JSON Array (List) เท่านั้น
รูปแบบ:
[
 {
  "category":"หมวดหมู่",
  "name":"ชื่อวัตถุดิบ",
  "quantity":1,
  "unit":"หน่วย",
  "expiry_days":7
 }
]
ห้ามมีข้อความอธิบายอื่น
ห้ามมี Markdown ```json

สำคัญ: ค่า "category" ต้องเลือกจากรายการนี้เท่านั้น ห้ามพิมพ์คำอื่นนอกเหนือจากนี้เด็ดขาด:
${fixedCategories.join(", ")}
""");

      final response = await model
          .generateContent([
            Content.multi([prompt, DataPart('image/jpeg', imageBytes)]),
          ])
          .timeout(const Duration(seconds: 30));

      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      if (response.text != null) {
        String cleanJson = response.text!
            .replaceAll('```json', '')
            .replaceAll('```', '')
            .trim();

        dynamic decoded = jsonDecode(cleanJson);
        List<dynamic> itemsList = [];

        if (decoded is List) {
          itemsList = decoded;
        } else if (decoded is Map) {
          itemsList = [decoded];
        }

        // กันเหนียว: ถ้า AI ตอบหมวดหมู่ไม่ตรงเป๊ะกับที่กำหนดไว้ (fixedCategories)
        // ให้ map เข้าเซ็ตที่กำหนดไว้เสมอ ไม่ปล่อยให้หมวดหมู่แปลกๆ หลุดเข้าคลัง
        for (var item in itemsList) {
          if (item is Map) {
            item['category'] = normalizeCategory(
              (item['category'] ?? '').toString(),
            );
          }
        }

        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ResultScreen(
                foundItems: itemsList,
                imageBytes: imageBytes,
              ),
            ),
          ).then((_) {
            _fetchRecentItems();
          });
        }
      }
    } catch (e) {
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    }
  }

  // ใช้ mapping กลางเดียวกับหน้าคลัง (Inventory) เพื่อให้อิโมจิหมวดหมู่ตรงกันทุกหน้า
  String _getCategoryEmoji(String category) => categoryEmoji(category);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFD8EEFF),
      bottomNavigationBar: const AppBottomNav(current: AppTab.scan),
      body: SafeArea(
        child: Column(
          children: [
            const IngredientFlowHeader(title: "ถ่ายรูปวัตถุดิบ"),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  children: [
                    const SizedBox(height: 15),
                    _IngredientOptionCard(
                      icon: Icons.camera_alt_outlined,
                      title: "ถ่ายรูปวัตถุดิบ",
                      subtitle: "เปิดกล้องเพื่อสแกน",
                      onTap: () => _pickAndAnalyzeImage(ImageSource.camera),
                    ),
                    const SizedBox(height: 15),
                    _IngredientOptionCard(
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
                          _buildTipItem("จัดวัตถุดิบให้อยู่ตรงกลางเฟรม"),
                          _buildTipItem("หลีกเลี่ยงเงาหรือแสงสะท้อนบนวัตถุ"),
                          _buildTipItem("ถ่ายทีละชิ้นเพื่อความแม่นยำสูงสุด"),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // วัตถุดิบที่เพิ่มล่าสุด (ดึงจาก Supabase จริง)
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
                            "วัตถุดิบที่เพิ่มล่าสุด",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _isLoadingRecent
                              ? const Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : _recentItems.isEmpty
                              ? const Text(
                                  "ยังไม่มีประวัติการเพิ่มวัตถุดิบ",
                                  style: TextStyle(color: Colors.grey),
                                )
                              : Column(
                                  children: _recentItems.map((item) {
                                    final emoji = _getCategoryEmoji(
                                      item['category'] ?? '',
                                    );
                                    final name = item['name'] ?? 'ไม่ระบุ';
                                    final time = relativeTimeThai(
                                      item['created_at']?.toString(),
                                    );
                                    return _buildRecentItem(emoji, name, time);
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

  // แถบหัวเรื่อง: ปุ่มย้อนกลับ + แคปซูลไอคอนสแกน/ชื่อหน้า + ปุ่มตัวกรองวงกลม
  // (สีครีมเหลืองอ่อนทั้งแถบ ตามดีไซน์ Figma "SCAN")
  Widget _buildTipItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          const CheckIcon(size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.black87, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentItem(String iconEmoji, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFD9D9D9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(iconEmoji, style: const TextStyle(fontSize: 24)),
          ),
          const SizedBox(width: 15),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(color: Colors.black54, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// การ์ดตัวเลือกสแกน (วงกลมไอคอนฟ้าอ่อน + ชื่อ + คำอธิบาย) ทรงเดียวกับ
/// _ScanOptionCard ในหน้าสแกนสูตรอาหาร เพื่อให้ดีไซน์ตรงกันทั้งแอป
class _IngredientOptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _IngredientOptionCard({
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
