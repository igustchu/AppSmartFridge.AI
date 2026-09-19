// เทมเพลตสำหรับเก็บ API Key ของโปรเจกต์
// วิธีใช้: คัดลอกไฟล์นี้ แล้วเปลี่ยนชื่อเป็น api_keys.dart (อยู่โฟลเดอร์เดียวกัน)
// จากนั้นใส่ API Key จริงของคุณแทนค่า YOUR_GEMINI_API_KEY_HERE ด้านล่าง
// ไฟล์ api_keys.dart จะไม่ถูก commit เข้า git (อยู่ใน .gitignore แล้ว)
class ApiKeys {
  static const String gemini = 'YOUR_GEMINI_API_KEY_HERE';
  static const String geminiImageScanning = 'YOUR_GEMINI_API_KEY_HERE';
}
