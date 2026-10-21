-- =====================================================================
--  LỚP HỌC Ô LI · Cập nhật cho chức năng giao nhiệm vụ mới (kho đề)
--  Dán vào Supabase › SQL Editor › New query › Run. Chạy lại nhiều lần vẫn an toàn.
--  Kho đề (col = 'bank') chỉ giáo viên xem và sửa, học sinh không đọc được.
-- =====================================================================
drop policy if exists docs_read on public.docs;
create policy docs_read on public.docs for select to anon, authenticated
  using (
    col in ('boards', 'config')
    or public.is_teacher()
    or (public.my_sid() is not null and col not in ('cred', 'msgs', 'bank'))
    or (col = 'msgs' and public.my_sid() is not null and (data->>'from' = public.my_sid() or data->>'to' = public.my_sid()))
  );
