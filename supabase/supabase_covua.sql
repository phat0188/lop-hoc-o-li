-- LỚP HỌC Ô LI · Câu lạc bộ cờ vua: cho học sinh lưu điểm cờ của chính mình
-- Chạy một lần trong Supabase › SQL Editor › New query › Run (đã gồm cả quyền nhắn tin)
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
