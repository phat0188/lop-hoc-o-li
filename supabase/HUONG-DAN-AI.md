# Bật tính năng AI cho Lớp học Ô Li (bản web)

Các tính năng dùng AI: **Trợ lí Ô Li ra đề và giao bài**, **Ô Li soạn bài bổ trợ**, **Ô Li soạn bài giúp**, **Thêm câu hỏi và lời giảng** (khi nhập PowerPoint), **Trợ giảng Ô Li** (học sinh hỏi), **Gợi ý trả lời** (giáo viên trả lời câu hỏi của học sinh).

Khóa AI được cất trong Supabase (máy chủ), không nằm trong trang web, nên học sinh không thể lấy được.

## Bước 1 – Lấy khóa AI (Anthropic Claude)

1. Vào **console.anthropic.com**, tạo tài khoản và đăng nhập.
2. Vào **Billing / Plans & Billing**, nạp một ít credit (thẻ Visa/Mastercard). Xem giá ở trang pricing của Anthropic; để thử nghiệm thì nạp mức thấp nhất là đủ.
3. Vào **API Keys → Create Key**, đặt tên `lop-hoc-o-li`, bấm tạo, rồi **Copy** khóa (bắt đầu bằng `sk-ant-…`).
   Khóa chỉ hiện **một lần**, và **không gửi khóa này cho ai** (kể cả trong chat).

(Có thể dùng Google Gemini thay thế: đặt secret `GEMINI_API_KEY` và `GEMINI_MODEL` theo tên mẫu Gemini hiện hành thay cho `ANTHROPIC_API_KEY`.)

## Bước 2 – Tạo bảng đếm lượt dùng

Supabase › **SQL Editor** › New query › dán nội dung `supabase_ai.sql` › **Run**.

## Bước 3 – Tạo Edge Function

1. Supabase › **Edge Functions** (biểu tượng hình tia sét/hàm ở thanh bên trái) › **Deploy a new function** › **Via Editor**.
2. Đặt tên function chính xác là: `oli-ai`
3. Xóa đoạn mã mẫu, dán toàn bộ nội dung file `oli-ai/index.ts`.
4. Bấm **Deploy function**.

## Bước 4 – Cất khóa AI vào Supabase

1. Supabase › **Edge Functions** › **Secrets** (hoặc *Manage secrets*).
2. Thêm secret mới:
   - Name: `ANTHROPIC_API_KEY`
   - Value: dán khóa `sk-ant-…` ở Bước 1
3. Bấm **Save**.

Tuỳ chọn (có thể bỏ qua):

| Secret | Ý nghĩa | Mặc định |
|---|---|---|
| `AI_LIMIT_STUDENT` | Số lần mỗi học sinh được hỏi AI mỗi ngày | 20 |
| `AI_LIMIT_TEACHER` | Số lần mỗi giáo viên được dùng AI mỗi ngày | 200 |
| `ANTHROPIC_MODEL` | Mẫu AI dùng để soạn bài | claude-sonnet-5-5 |
| `ANTHROPIC_MODEL_FAST` | Mẫu AI dùng cho trợ giảng, gợi ý trả lời | claude-haiku-5-5 |

## Bước 5 – Cập nhật web và kiểm tra

1. Trang web trên GitHub Pages đã được cập nhật sẵn, không cần làm gì thêm. Mở trang, bấm Ctrl + F5 để tải bản mới.
2. Đăng xuất rồi đăng nhập lại bằng tài khoản giáo viên › Trang Giáo viên › **Nhiệm vụ**: khung **✨ Trợ lí Ô Li ra đề và giao bài** phải hiện ô nhập yêu cầu (không còn dòng "chưa được bật").
3. Học sinh vào một bài giảng › **Giơ tay hỏi cô** › có nút **Hỏi trợ giảng Ô Li ngay**.

Nếu nút AI không hiện: kiểm tra tên function đúng là `oli-ai`, đã lưu secret `ANTHROPIC_API_KEY`, và đăng xuất rồi đăng nhập lại.

## An toàn

- Chỉ tài khoản đã được duyệt (giáo viên, học sinh có trong danh sách lớp) mới gọi được AI.
- Mỗi người bị giới hạn số lượt mỗi ngày, nên không ai làm tốn tiền quá mức.
- Trợ giảng Ô Li được dặn: trả lời ngắn, đúng chương trình, không nói thẳng đáp án câu trắc nghiệm, đưa học sinh quay lại bài học nếu hỏi lạc đề.
- AI vẫn có thể sai: thầy cô xem lại bài do Ô Li soạn trước khi giao.
