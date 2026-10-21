-- LỚP HỌC Ô LI · Cho phép học sinh gửi tin nhắn riêng (lưu lại để đọc khi bạn offline)
-- Chạy một lần trong Supabase › SQL Editor › New query › Run
drop policy if exists docs_student_insert on public.docs;
create policy docs_student_insert on public.docs for insert to authenticated
  with check (
    public.my_sid() is not null and (
      (col in ('subs', 'qna') and data->>'sid' = public.my_sid())
      or (col = 'gear' and id = public.my_sid())
      or (col = 'msgs' and data->>'from' = public.my_sid() and length(coalesce(data->>'text', '')) <= 300)
    ));
-- Học sinh chỉ đọc được tin nhắn mình gửi hoặc nhận (giáo viên đọc được tất cả)
drop policy if exists docs_read on public.docs;
create policy docs_read on public.docs for select to anon, authenticated
  using (
    col in ('boards', 'config')
    or public.is_teacher()
    or (public.my_sid() is not null and col not in ('cred', 'msgs'))
    or (col = 'msgs' and public.my_sid() is not null and (data->>'from' = public.my_sid() or data->>'to' = public.my_sid()))
  );
