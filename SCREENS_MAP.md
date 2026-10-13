# แผนที่หน้าจอ (Screens Map) - SmartFridge.AI

เอกสารนี้สรุปว่าไฟล์ไหนใน `lib/screens/` เป็นของเมนู/ฟีเจอร์ไหน จัดกลุ่มตามการใช้งานจริง
(ไม่ได้ย้ายไฟล์จริง แค่ทำเป็นแผนที่ไว้อ้างอิง ไฟล์ยังอยู่ที่เดิมทุกไฟล์)

## 🔐 ระบบสมาชิก (Auth)
- `login_screen.dart` — หน้าล็อกอิน
- `register.dart` — หน้าสมัครสมาชิก
- `verify_email_otp_screen.dart` — ยืนยัน OTP ทางอีเมลหลังสมัคร
- `forgot_password_screen.dart` — ขอลิงก์รีเซ็ตรหัสผ่าน
- `reset_password_screen.dart` — ตั้งรหัสผ่านใหม่ (จากลิงก์อีเมล)
- `change_password_screen.dart` — เปลี่ยนรหัสผ่าน (ตอนล็อกอินอยู่)

## 🏠 หน้าหลัก (Main Navigation)
- `main_menu_screen.dart` — หน้าเมนูหลัก มีแท็บ/ปุ่มลิงก์ไปทุกฟีเจอร์

## 🧊 คลังวัตถุดิบ (Inventory)
- `inventory_screen.dart` — รายการวัตถุดิบทั้งหมดในตู้เย็น
- `item_detail_screen.dart` — รายละเอียด/แก้ไขวัตถุดิบทีละชิ้น
- `expiration_alert_screen.dart` — แจ้งเตือนวัตถุดิบใกล้หมดอายุ
- `notification_settings_screen.dart` — ตั้งค่าการแจ้งเตือน

## 📷 สแกน/ถ่ายรูป (Scanning)
- `scan_menu_screen.dart` — เมนูเลือกว่าจะสแกนอะไร (วัตถุดิบ/สูตรอาหาร)
- `ImageScanning.dart` — ถ่ายรูปวัตถุดิบ วิเคราะห์ด้วย Gemini
- `result_screen.dart` — ผลลัพธ์วัตถุดิบที่สแกนได้ (ก่อนบันทึกเข้าคลัง)
- `scan_recipe_screen.dart` — ถ่ายรูปสูตรอาหาร วิเคราะห์ด้วย Gemini
- `scan_recipe_result_screen.dart` — ผลลัพธ์สูตรอาหารที่สแกนได้ เทียบกับของในตู้เย็น

## 🍳 สูตรอาหาร & AI แนะนำเมนู (Recipes / AI)
- `ai_recipe_screen.dart` — ให้ AI แนะนำเมนูจากวัตถุดิบที่มี
- `recipe_detail_screen.dart` — รายละเอียดสูตรอาหาร + ปุ่มเริ่มทำ (หักวัตถุดิบ)
- `saved_recipes_screen.dart` — สูตรอาหารที่บันทึกไว้
- `cook_meal_screen.dart` — หน้าทำอาหารตามสูตร ทีละขั้นตอน

## 📅 วางแผนมื้ออาหาร (Meal Planning)
- `plan_menu_screen.dart` — เมนูเลือกว่าจะวางแผนแบบไหน
- `meal_plan_screen.dart` — สร้างแผนมื้ออาหารรายสัปดาห์ด้วย AI
- `weekly_plan_screen.dart` — ดูแผนมื้ออาหารที่สร้างไว้รายสัปดาห์
- `my_plan_screen.dart` — แผนมื้ออาหารของฉัน (ภาพรวม)

## 👤 โปรไฟล์ & ตั้งค่าบัญชี (Profile / Account)
- `profile_screen.dart` — หน้าโปรไฟล์ผู้ใช้
- `edit_profile_screen.dart` — แก้ไขข้อมูลโปรไฟล์
- `delete_account_screen.dart` — ลบบัญชี

---
### ไฟล์ระบบสำคัญที่เกี่ยวข้อง
- `lib/main.dart` — จุดเริ่มต้นแอป
- `lib/services/notification_service.dart` — จัดการแจ้งเตือน local notification
- `lib/config/api_keys.dart` — เก็บ API Key (ไม่ขึ้น git)
- `lib/widgets/` — widget ที่ใช้ซ้ำหลายหน้า (bottom nav, header, icons)
- `lib/utils/category_icons.dart` — ไอคอนตามหมวดหมู่วัตถุดิบ
- `lib/utils/fridge_age.dart` — คำนวณว่าอยู่ในตู้เย็นมาแล้วกี่วัน / เหลืออีกกี่วันหมดอายุ / ลำดับ FIFO
- `lib/utils/shelf_life.dart` — ตารางอายุการเก็บรักษา (ช่องปกติ/แช่แข็ง, ดิบ/สุก ฯลฯ) ใช้เป็นค่าเริ่มต้นตอนสแกน
- `lib/services/fridge_stock.dart` — หักวัตถุดิบตามสัดส่วนแบบ FIFO (ลอตที่ใกล้หมดอายุก่อน)
- `supabase/fridge_items_storage.sql` — SQL เพิ่มคอลัมน์ storage / food_state / fridge_days / freezer_days
