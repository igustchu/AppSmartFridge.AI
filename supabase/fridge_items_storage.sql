-- เพิ่มคอลัมน์สำหรับระบบอายุการเก็บรักษา / ช่องที่เก็บ / ลอต FIFO
-- รันครั้งเดียวใน Supabase Dashboard > SQL Editor

-- ช่องที่เก็บ: 'fridge' = ช่องปกติ, 'freezer' = ช่องแช่แข็ง
alter table fridge_items add column if not exists storage text not null default 'fridge';

-- สถานะของวัตถุดิบ เช่น ดิบ / สุก / เปิดซองแล้ว / ยังไม่เปิดซอง (ว่างได้)
alter table fridge_items add column if not exists food_state text;

-- จำนวนวันที่เก็บได้ในแต่ละช่อง (จากตารางอายุการเก็บรักษา หรือ Gemini)
-- ใช้คำนวณวันหมดอายุใหม่ตอนย้ายช่อง — freezer_days เป็น null = ไม่ควรแช่แข็ง
alter table fridge_items add column if not exists fridge_days integer;
alter table fridge_items add column if not exists freezer_days integer;

-- ให้ quantity รับค่าทศนิยมได้ (หักตามสัดส่วน เช่นใช้ไป 0.5 หัว)
alter table fridge_items alter column quantity type numeric;

-- ให้ expiry_date ว่างได้ (ของเก่าที่บันทึกตอนไม่มีวันหมดอายุ)
alter table fridge_items alter column expiry_date drop not null;

-- ปริมาณที่ตรวจพบจากรูปตอนสแกน (เช่น 1 แพ็ค) แยกจาก quantity/unit ที่ใช้หัก
-- (เช่น แบ่งเป็น 3 ส่วน)
alter table fridge_items add column if not exists detected_quantity numeric;
alter table fridge_items add column if not exists detected_unit text;
