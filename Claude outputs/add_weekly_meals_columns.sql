-- รันใน Supabase Dashboard > SQL Editor ก่อนใช้ฟีเจอร์ "ทำอาหาร" ในแอป
-- (ก่อนใช้ปุ่ม "สร้างแพลนอาหาร" อีกครั้งด้วย เพราะโค้ดใหม่จะพยายาม insert
-- คอลัมน์ ingredients / is_cooked ตอนสร้างแผน ถ้ายังไม่มีคอลัมน์นี้
-- "สร้างแพลนอาหาร" จะ error ทันที)

alter table weekly_meals
  add column if not exists ingredients jsonb not null default '[]'::jsonb,
  add column if not exists steps text,
  add column if not exists is_cooked boolean not null default false;
