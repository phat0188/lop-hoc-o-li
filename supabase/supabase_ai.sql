-- LỚP HỌC Ô LI · Bảng đếm lượt dùng AI (chạy một lần trong SQL Editor)
create table if not exists public.ai_usage (
  uid uuid not null references auth.users(id) on delete cascade,
  day date not null default current_date,
  n int not null default 0,
  primary key (uid, day)
);
alter table public.ai_usage enable row level security;
-- Không tạo policy: chỉ Edge Function (dùng khóa máy chủ) mới đọc/ghi được bảng này.
