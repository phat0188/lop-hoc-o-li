# Trường học Ô Li – Hướng dẫn chạy bản web với Supabase

Bộ file gồm:

| File | Dùng để |
|---|---|
| `index.html` | Toàn bộ web app (một file duy nhất) |
| `supabase_setup.sql` | Tạo bảng, phân quyền, kho hình ảnh trên Supabase |
| `du_lieu_mau.sql` | Dữ liệu mẫu: 16 học sinh, 35 nhiệm vụ và bài giảng, bài nộp, bảng vàng |

## Bước 1 – Cài cơ sở dữ liệu (làm một lần)

1. Vào supabase.com, mở project của thầy cô.
2. Chọn **SQL Editor → New query**, dán toàn bộ nội dung `supabase_setup.sql`, bấm **Run**. Thấy "Success" là được.
3. Tạo một query mới, dán `du_lieu_mau.sql`, bấm **Run** (bỏ qua nếu muốn bắt đầu với dữ liệu trống).

## Bước 2 – Cài đặt đăng nhập

1. **Authentication → Sign In / Providers → Email**: **tắt "Confirm email"**.
   Học sinh dùng mã học sinh làm tên đăng nhập, không có hộp thư thật, nên phải tắt bước xác nhận email.
2. Giữ **"Allow new users to sign up"** ở trạng thái bật (app dùng nó để cấp tài khoản học sinh).
3. Nếu cấp tài khoản cho nhiều lớp một lúc mà bị báo lỗi giới hạn: **Authentication → Rate Limits**, tăng mục đăng kí/đăng nhập, hoặc đợi vài phút rồi cấp tiếp.

## Bước 3 – Đưa web lên mạng

Cách dễ nhất là **Netlify Drop** (miễn phí):

1. Vào app.netlify.com/drop, đăng nhập.
2. Kéo thả **thư mục chứa `index.html`** vào trang. Netlify cho ngay một đường link dạng `https://ten-ngau-nhien.netlify.app` (đổi tên được trong Site settings).
3. Quay lại Supabase: **Authentication → URL Configuration → Site URL**, dán đường link đó.

(GitHub Pages hoặc Vercel cũng được; chỉ cần đặt `index.html` ở thư mục gốc.)

## Bước 4 – Bắt đầu dùng

1. Mở web, bấm **Đăng nhập → Giáo viên**, nhập email và mật khẩu, bấm **Tạo tài khoản giáo viên**.
   **Tài khoản giáo viên đầu tiên được duyệt tự động**, vì vậy thầy cô nên tạo tài khoản ngay sau khi cài đặt.
   Giáo viên khác đăng kí sau sẽ ở trạng thái chờ; thầy cô duyệt trong **Trang Giáo viên → Tài khoản**.
2. Thêm học sinh ở **Trang Giáo viên → Học sinh** (mỗi em một mã, ví dụ `7B05`).
3. Vào **Trang Giáo viên → Tài khoản**, chọn lớp, bấm **Cấp tài khoản cho cả lớp**, rồi **In phiếu đăng nhập** để phát cho các em.
4. Học sinh vào web → **Đăng nhập → Học sinh**, nhập mã và mật khẩu trên phiếu. Các em nên đổi mật khẩu ở mục **Tài khoản**.

## Phân quyền đã cài

- Chưa đăng nhập: chỉ xem được bảng vàng.
- Học sinh: xem bài giảng, nhiệm vụ, bảng xếp hạng; chỉ ghi được **bài nộp, câu hỏi và tủ đồ của chính mình**.
- Giáo viên: toàn quyền với dữ liệu lớp học, tải hình/video/ghi âm, duyệt giáo viên khác.
- Mật khẩu ban đầu của học sinh chỉ giáo viên xem được.

## Giới hạn hiện tại (sẽ làm ở bản sau)

- **Quên mật khẩu**: tạm thời giáo viên xóa tài khoản em đó trong Supabase (**Authentication → Users**), rồi bấm **Cấp tài khoản** lại trong app.
- **Tính năng AI** (Ô Li soạn bài, trợ giảng, gợi ý trả lời) đang ẩn ở bản web; cần thêm một Edge Function giữ khóa AI.
- **Chấm điểm** vẫn tính trên máy học sinh, nên về lí thuyết một em rành kĩ thuật có thể gửi điểm giả cho bài của mình. Muốn chặt chẽ hơn cần chuyển phần chấm lên máy chủ.
- **Dạy trực tiếp**: các tín hiệu giơ tay, mời phát biểu, khen đi qua kênh Realtime của Supabase; hiện chưa chặn việc một học sinh tự gửi tín hiệu "mời/khen" giả.

## Phòng tranh 3D (cập nhật tháng 10/2026)
Để học sinh gửi được tranh vẽ, thầy cô chạy **một lần** tệp `supabase_phongtranh.sql` trong Supabase › SQL Editor › New query › Run.
- Mỗi học sinh gửi 1 bức/tháng; ảnh được nén tự động (tối đa khoảng 450 KB).
- Thầy cô vào Phòng GV hoặc đi tới cửa **Phòng tranh 3D** (dãy C) để đặt chủ đề tháng, **Duyệt**, **Ẩn**, chọn **Tranh tiêu biểu** hoặc **Xóa** tranh.
- Tranh chỉ được treo sau khi thầy cô duyệt. Học sinh gửi lại thì tranh trở về "chờ duyệt".
