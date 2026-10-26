-- LỚP HỌC Ô LI · Phòng tranh 3D: cho học sinh gửi tranh vẽ của chính mình
-- Chạy một lần trong Supabase › SQL Editor › New query › Run
-- (đã gồm cả quyền nộp bài, hỏi bài, tủ đồ, cờ vua và nhắn tin như trước)
-- Học sinh chỉ gửi được tranh của chính mình, mỗi tháng 1 bức, ảnh tối đa khoảng 450 KB,
-- và không tự duyệt được: mỗi lần gửi lại, tranh trở về trạng thái "chờ duyệt".
drop policy if exists docs_student_insert on public.docs;
create policy docs_student_insert on public.docs for insert to authenticated
  with check (
    public.my_sid() is not null and (
      (col in ('subs', 'qna') and data->>'sid' = public.my_sid())
      or (col in ('gear', 'chess') and id = public.my_sid())
      or (col = 'msgs' and data->>'from' = public.my_sid() and length(coalesce(data->>'text', '')) <= 300)
      or (col = 'art' and data->>'sid' = public.my_sid() and id like public.my_sid() || '\_%'
          and coalesce(data->>'approved', 'false') = 'false' and coalesce(data->>'star', 'false') = 'false')
      or (col = 'artimg' and data->>'sid' = public.my_sid() and id like public.my_sid() || '\_%'
          and length(coalesce(data->>'img', '')) <= 620000)
    ));
drop policy if exists docs_student_update on public.docs;
create policy docs_student_update on public.docs for update to authenticated
  using (
    public.my_sid() is not null and (
      (col in ('subs', 'qna') and data->>'sid' = public.my_sid())
      or (col in ('gear', 'chess') and id = public.my_sid())
      or (col in ('art', 'artimg') and data->>'sid' = public.my_sid())
    ))
  with check (
    public.my_sid() is not null and (
      (col in ('subs', 'qna') and data->>'sid' = public.my_sid())
      or (col in ('gear', 'chess') and id = public.my_sid())
      or (col = 'art' and data->>'sid' = public.my_sid()
          and coalesce(data->>'approved', 'false') = 'false' and coalesce(data->>'star', 'false') = 'false')
      or (col = 'artimg' and data->>'sid' = public.my_sid() and length(coalesce(data->>'img', '')) <= 620000)
    ));
