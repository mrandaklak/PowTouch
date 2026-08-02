# PowTouch — Ace Fishing bot (AutoTouch / XXTouch, iOS)

Script tự động **câu cá** cho game **Ace Fishing** trên iOS (máy đã **jailbreak**).
Chạy được trên **AutoTouch** và **XXTouch Elite** — `lib/utils.lua` tự nhận diện ứng
dụng và dùng đúng API nên các file khác không cần sửa. Canh sẵn cho **iPhone 7 Plus**
(1080 × 1920), tự scale nếu máy khác độ phân giải.

## Nguyên lý câu (học từ bản gốc `Ace Fishing/core/fishing/default.js`)

Một con cá đi qua 4 pha, lặp lại:

1. **Quăng cần** — bấm START → hiện vòng cung lực có kim chạy. Nếu **canh Perfect**:
   chờ kim vàng đè lên ô đích rồi chốt; không thì chốt thường.
2. **Chờ cắn** — chờ thanh lực (tension) xuất hiện = cá đã móc.
3. **Kéo cá** *(trọng tâm)* — **giữ** nút reel cho tension leo tới vạch `armPct`
   (~78%) thì **nhả** cho tụt; tụt đủ thì **giữ lại**. Dao động sát vạch đứt mà
   không đứt. Thanh **nội lực** đầy → **vuốt lên** dùng kỹ năng.
4. **Kết thúc** — đóng popup phần thưởng, đếm cá, lặp lại tới khi đủ số cá.

## Bảng cấu hình (hiện ra khi chạy)

Khi bấm Play, script hỏi đúng **2 tuỳ chọn**:

| Tuỳ chọn | Ý nghĩa |
|----------|---------|
| **Canh Perfect** (bật/tắt) | Bật thì canh chốt lực tại vạch perfect; tắt thì quăng thường. |
| **Số cá cần câu** | Câu đủ số này thì tự dừng. Để `0` = câu vô hạn. |

Mặc định ban đầu lấy từ `Config.run` trong `config.lua`.

## Đọc màn hình theo cơ chế AutoTouch (không bắt chước AutoJS)

AutoTouch **không có** kiểu "chụp vào RAM rồi `images.pixel()`" như AutoJS
(`screenshot()` chỉ lưu PNG, không đọc lại được — theo tài liệu). Nên bot dùng
đúng cơ chế native:

- **`getColors({{x,y},...})`** — đọc **nhiều điểm trong MỘT lời gọi**. Vòng kéo cá
  đọc cả thanh lực + điểm reward + điểm nội lực bằng **1 `getColors`/vòng**, rồi tự
  so màu **có sai số** trong Lua.
- **Không** dùng `findColor` cho thanh lực: tài liệu ghi rõ `findColor`/`findColors`
  **không có tham số sai số màu**, mà thanh lực là gradient cam/đỏ → khớp tuyệt đối
  sẽ vỡ. `getColors` + tự so sai số là lựa chọn đúng.

> Số liệu tốc độ thật khác nhau theo máy/phiên bản; chạy `benchmark.lua` để đo
> `getColor` vs `getColors` trên chính máy bạn thay vì đoán.

## Cấu trúc file

| File | Vai trò |
|------|---------|
| `fishing.lua` | Script chính — hỏi cấu hình rồi chạy máy trạng thái câu cá. |
| `config.lua` | Toạ độ nút, màu nhận diện, thanh lực, cơ chế tension, thời gian. **Cần hiệu chỉnh.** |
| `lib/ui.lua` | Bảng hỏi 2 tuỳ chọn (Canh Perfect + Số cá). |
| `lib/utils.lua` | Tương thích AutoTouch/XXTouch + tap/swipe/giữ-nhả, đọc màu **batch `getColors`**, đo % thanh lực, scale toạ độ. |
| `calibrate.lua` | In màu & toạ độ hiện tại để hiệu chỉnh `config.lua`. |
| `benchmark.lua` | Đo thật tốc độ `getColor` vs `getColors` trên máy bạn. |

## Cài đặt

- **AutoTouch:** copy cả thư mục vào Scripts, giữ nguyên `lib/` cạnh `fishing.lua`, chạy `fishing.lua`.
- **XXTouch Elite:** copy vào `/var/mobile/Library/XXTouch/scripts/`, chọn `fishing.lua` → Play.

Rồi mở Ace Fishing, vào màn hình câu cá.

## Hiệu chỉnh (bắt buộc trước lần chạy đầu)

Toạ độ và màu trong `config.lua` chỉ là **giá trị mẫu**:

1. Mở đúng màn hình game → chạy `calibrate.lua`. Xem console để lấy **màu thực** tại
   từng anchor và **% thanh lực** đo được.
2. Dán màu thực vào `Config.anchors.*.color`, chỉnh `tolerance` (20–40).
3. Chỉnh thanh lực `Config.tensionBar`: `x0` (0%), `x1` (vạch đứt 100%), `y`; nếu %
   đo sai thì chỉnh `fillMinR` / `fillRB`.
4. Lấy toạ độ nút (START, reel, vuốt nội lực…) bằng công cụ chọn điểm của XXTouch
   hoặc **Record** của AutoTouch, điền vào `Config.coords`.

## Tinh chỉnh cơ chế kéo cá (`config.lua` → `Config.tension`)

- `armPct` – vạch nhả (cao hơn = kéo nhanh hơn nhưng dễ đứt dây).
- `releaseMs` – nhả bao lâu rồi mới xét giữ lại.
- `rearmDrop` – tụt xuống dưới `armPct - rearmDrop` mới giữ lại (chống rung).
- `minHoldMs` – giữ tối thiểu trước khi được phép nhả.

> Lưu ý thời gian trong trận kéo được **cộng dồn từ các lần sleep** (AutoTouch không
> có đồng hồ mili-giây tường tin cậy), nên là xấp xỉ — cứ tinh chỉnh theo máy thật.

## Ghi chú

- Chỉ dùng cho mục đích học tập / tự động hoá cá nhân trên máy của bạn.
- Đây là phần **câu cá**. Các phần khác (auto vào phòng, chọn mồi/cần, farm sự
  kiện…) sẽ bổ sung sau.
