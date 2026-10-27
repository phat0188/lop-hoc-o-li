-- TRƯỜNG HỌC Ô LI · Cấp lại tài khoản và đặt lại mật khẩu học sinh ngay trong phần mềm
-- Chạy một lần trong Supabase › SQL Editor › New query › Run.
-- Dùng khi: học sinh bị xóa rồi thêm lại (mã đã có tài khoản cũ), hoặc học sinh quên mật khẩu.
-- Chỉ tài khoản giáo viên đã được duyệt mới gọi được hàm này. Không cần khóa bí mật (service_role).
create extension if not exists pgcrypto with schema extensions;

create or replace function public.oli_student_account(p_sid text, p_pw text) returns text
language plpgsql security definer set search_path = public, extensions as $$
declare v_code text; v_name text; v_email text; v_uid uuid;
begin
  if not public.is_teacher() then raise exception 'not_teacher'; end if;
  if length(coalesce(p_pw, '')) < 6 then raise exception 'weak_password'; end if;
  select lower(data->>'code'), data->>'name' into v_code, v_name from public.docs where col = 'students' and id = p_sid;
  if v_code is null then raise exception 'no_student'; end if;
  v_email := regexp_replace(v_code, '[^a-z0-9._-]', '', 'g') || '@hs.lophocoli.vn';
  select id into v_uid from auth.users where lower(email) = v_email limit 1;
  if v_uid is null then return 'none'; end if;   -- chưa có tài khoản: phần mềm sẽ tạo mới như bình thường
  update auth.users set encrypted_password = extensions.crypt(p_pw, extensions.gen_salt('bf')),
    email_confirmed_at = coalesce(email_confirmed_at, now()), banned_until = null, updated_at = now() where id = v_uid;
  update public.profiles set sid = null where sid = p_sid and id <> v_uid;   -- gỡ liên kết cũ (nếu có)
  insert into public.profiles (id, role, sid, email, name) values (v_uid, 'student', p_sid, v_email, v_name)
    on conflict (id) do update set role = 'student', sid = excluded.sid, email = excluded.email, name = excluded.name;
  return 'ok';
end $$;
revoke all on function public.oli_student_account(text, text) from public, anon;
grant execute on function public.oli_student_account(text, text) to authenticated;
