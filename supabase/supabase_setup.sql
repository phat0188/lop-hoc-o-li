-- =====================================================================
--  LỚP HỌC Ô LI · Cài đặt cơ sở dữ liệu Supabase
--  Dán toàn bộ file này vào Supabase › SQL Editor › New query › Run.
--  Chạy lại nhiều lần cũng an toàn.
-- =====================================================================

-- 1) Hồ sơ tài khoản: vai trò giáo viên / học sinh -------------------------
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  role text not null default 'pending' check (role in ('teacher','student','pending','blocked')),
  sid text unique,                 -- mã nội bộ của học sinh (khóa trong bảng docs, col = 'students')
  email text,
  name text,
  created_at timestamptz not null default now()
);
alter table public.profiles enable row level security;

-- 2) Kho dữ liệu của app: mỗi dòng là một "tài liệu" thuộc một nhóm (col) -----
--    col: students, tasks, subs, boards, config, gear, qna, live, cred, msgs, chess, bank
create table if not exists public.docs (
  col text not null,
  id text not null,
  data jsonb not null default '{}'::jsonb,
  owner uuid default auth.uid(),
  updated_at timestamptz not null default now(),
  primary key (col, id)
);
create index if not exists docs_col_idx on public.docs (col);
create index if not exists docs_student_code_idx on public.docs (lower(data->>'code')) where col = 'students';
alter table public.docs enable row level security;
alter table public.docs replica identity full;

-- 3) Hàm kiểm tra quyền (security definer để không vòng lặp RLS) ---------------
create or replace function public.is_teacher() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.profiles where id = auth.uid() and role = 'teacher')
$$;
create or replace function public.my_sid() returns text
language sql stable security definer set search_path = public as $$
  select sid from public.profiles where id = auth.uid() and role = 'student'
$$;

-- 4) Tự tạo hồ sơ khi có tài khoản mới ------------------------------------------
--    Học sinh: email dạng <mã học sinh>@hs.lophocoli.vn, chỉ được nhận nếu mã có trong danh sách lớp.
--    Giáo viên: email thật; tài khoản giáo viên ĐẦU TIÊN tự thành giáo viên, các tài khoản sau chờ duyệt.
create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_sid text; v_code text; v_name text;
begin
  if new.email like '%@hs.lophocoli.vn' then
    v_code := split_part(new.email, '@', 1);
    select id, data->>'name' into v_sid, v_name from public.docs
      where col = 'students' and lower(data->>'code') = v_code limit 1;
    if v_sid is not null and not exists (select 1 from public.profiles where sid = v_sid) then
      insert into public.profiles (id, role, sid, email, name) values (new.id, 'student', v_sid, new.email, v_name);
    else
      insert into public.profiles (id, role, email) values (new.id, 'blocked', new.email);
    end if;
  else
    insert into public.profiles (id, role, email, name) values (
      new.id,
      case when exists (select 1 from public.profiles where role = 'teacher') then 'pending' else 'teacher' end,
      new.email, coalesce(new.raw_user_meta_data->>'name', ''));
  end if;
  return new;
end $$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

-- 5) Quyền trên hồ sơ -----------------------------------------------------------
drop policy if exists profiles_read on public.profiles;
create policy profiles_read on public.profiles for select to authenticated
  using (id = auth.uid() or public.is_teacher());
drop policy if exists profiles_teacher_update on public.profiles;
create policy profiles_teacher_update on public.profiles for update to authenticated
  using (public.is_teacher()) with check (public.is_teacher());
drop policy if exists profiles_teacher_delete on public.profiles;
create policy profiles_teacher_delete on public.profiles for delete to authenticated
  using (public.is_teacher() and id <> auth.uid());

-- 6) Quyền trên dữ liệu ---------------------------------------------------------
-- Ai cũng xem được bảng vàng và thông tin trường; giáo viên và học sinh đã được duyệt xem mọi thứ trừ mật khẩu ban đầu (cred).
drop policy if exists docs_read on public.docs;
create policy docs_read on public.docs for select to anon, authenticated
  using (
    col in ('boards', 'config')
    or public.is_teacher()
    or (public.my_sid() is not null and col not in ('cred', 'msgs', 'bank'))
    or (col = 'msgs' and public.my_sid() is not null and (data->>'from' = public.my_sid() or data->>'to' = public.my_sid()))
  );
-- Giáo viên: toàn quyền.
drop policy if exists docs_teacher_all on public.docs;
create policy docs_teacher_all on public.docs for all to authenticated
  using (public.is_teacher()) with check (public.is_teacher());
-- Học sinh: chỉ ghi bài nộp, câu hỏi và tủ đồ của chính mình.
drop policy if exists docs_student_insert on public.docs;
create policy docs_student_insert on public.docs for insert to authenticated
  with check (
    public.my_sid() is not null and (
      (col in ('subs', 'qna') and data->>'sid' = public.my_sid())
      or (col in ('gear', 'chess') and id = public.my_sid())
      or (col = 'msgs' and data->>'from' = public.my_sid() and length(coalesce(data->>'text', '')) <= 300)
    ));
drop policy if exists docs_student_update on public.docs;
create policy docs_student_update on public.docs for update to authenticated
  using (
    public.my_sid() is not null and (
      (col in ('subs', 'qna') and data->>'sid' = public.my_sid())
      or (col in ('gear', 'chess') and id = public.my_sid())
    ))
  with check (
    public.my_sid() is not null and (
      (col in ('subs', 'qna') and data->>'sid' = public.my_sid())
      or (col in ('gear', 'chess') and id = public.my_sid())
    ));

-- Gộp một phần dữ liệu vào tài liệu (chạy với quyền của người gọi nên vẫn qua RLS)
create or replace function public.doc_merge(p_col text, p_id text, p_patch jsonb) returns void
language sql security invoker set search_path = public as $$
  update public.docs set data = data || p_patch, updated_at = now() where col = p_col and id = p_id
$$;
grant execute on function public.doc_merge(text, text, jsonb) to authenticated;

create or replace function public.touch_docs() returns trigger language plpgsql as $$
begin new.updated_at := now(); return new; end $$;
drop trigger if exists docs_touch on public.docs;
create trigger docs_touch before update on public.docs for each row execute function public.touch_docs();

-- 7) Cập nhật tức thời (realtime) -------------------------------------------------
do $$ begin
  alter publication supabase_realtime add table public.docs;
exception when duplicate_object then null; end $$;

-- 8) Kho hình, video, giọng ghi âm -----------------------------------------------
insert into storage.buckets (id, name, public) values ('media', 'media', true)
  on conflict (id) do update set public = true;
drop policy if exists media_read on storage.objects;
create policy media_read on storage.objects for select to anon, authenticated using (bucket_id = 'media');
drop policy if exists media_teacher_write on storage.objects;
create policy media_teacher_write on storage.objects for insert to authenticated
  with check (bucket_id = 'media' and public.is_teacher());
drop policy if exists media_teacher_delete on storage.objects;
create policy media_teacher_delete on storage.objects for delete to authenticated
  using (bucket_id = 'media' and public.is_teacher());
