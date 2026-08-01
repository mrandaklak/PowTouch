# PowTouch — Ace Fishing bot (XXTouch Elite / AutoTouch, iOS)

Script tự động **câu cá** cho game **Ace Fishing** trên iOS (máy đã **jailbreak**).
Chạy được trên **XXTouch Elite** (miễn phí) và **AutoTouch** — `lib/utils.lua`
tự nhận diện ứng dụng đang chạy và dùng đúng API, nên các file còn lại không cần
sửa. Được canh sẵn cho **iPhone 7 Plus** (1080 × 1920, iOS 15.8.8), tự scale toạ
độ nếu chạy trên máy có độ phân giải khác.

> Đây là phần **câu cá** — bước đầu tiên của dự án. Các phần khác (auto vào
> phòng, chọn mồi, chọn cần, farm sự kiện…) sẽ bổ sung sau.

## Luồng hoạt động

Máy trạng thái (state machine) lặp lại các bước:

1. **START** – nhấn nút quăng cần.
2. **PERFECT** – canh thanh lực, chốt tại vạch *perfect* (quăng perfect).
3. **WAIT** – chờ cá cắn câu.
4. **TENSION** – nhấp liên tục để giữ lực căng dây; tự ngừng khi dây vào vùng
   nguy hiểm để tránh đứt.
5. **NỘI LỰC** – khi thanh nội lực đầy thì vuốt để dùng kỹ năng.
6. **GIẬT CẦN** – thu cá về.
7. **XỬ LÝ KẾT THÚC** – đóng popup phần thưởng rồi quay lại bước 1.

## Cấu trúc file

| File | Vai trò |
|------|---------|
| `fishing.lua` | Script chính — chạy vòng lặp câu cá. |
| `config.lua` | Toạ độ nút, màu nhận diện trạng thái, thời gian. **Cần hiệu chỉnh.** |
| `lib/utils.lua` | Lớp tương thích: tự nhận diện XXTouch/AutoTouch + tap, swipe, đọc/so màu, scale toạ độ. |
| `calibrate.lua` | In màu & toạ độ hiện tại để bạn hiệu chỉnh `config.lua`. |

## Cài đặt

**XXTouch Elite:**
1. Copy cả thư mục vào `/var/mobile/Library/XXTouch/scripts/` (dùng web editor
   của XXTouch qua Wi-Fi, hoặc Filza). Giữ nguyên thư mục `lib/` cạnh `fishing.lua`.
2. Mở XXTouch Elite → chọn `fishing.lua` → **Play**.

**AutoTouch:** copy vào thư mục Scripts của AutoTouch rồi chạy `fishing.lua`.

Sau đó mở game Ace Fishing, vào màn hình câu cá.

## Hiệu chỉnh (bắt buộc trước khi dùng)

Toạ độ và màu trong `config.lua` chỉ là **giá trị mẫu**. Cách chỉnh:

1. Mở đúng màn hình game rồi chạy `calibrate.lua`. Xem console/log của ứng dụng
   để lấy **màu thực** tại từng điểm neo.
2. Dán màu thực vào `Config.anchors.*.color`, chỉnh `tolerance` (20–40).
3. Lấy toạ độ chính xác các nút (start, tension, giật cần, vùng vuốt nội lực…)
   bằng công cụ chọn điểm của XXTouch (bảng toạ độ khi chạm) hoặc **Record** của
   AutoTouch, rồi điền vào `Config.coords`.

Nếu chưa muốn dùng nhận diện màu, đặt `Config.features.useColorDetection = false`
để chạy hoàn toàn theo thời gian (kém chính xác hơn, cần chỉnh timing).

## Chạy

Chạy `fishing.lua` (nút Play trong XXTouch/AutoTouch). Dừng bằng nút Stop, hoặc
đặt `Config.maxCatches` > 0 để tự dừng sau số cá nhất định.

## Tuỳ chỉnh nhanh (`config.lua`)

- `Config.features.useInnerPower` – bật/tắt vuốt nội lực.
- `Config.timing.tensionTapIntervalMs` – tần suất nhấp tension.
- `Config.timing.fightTimeoutMs` – thời gian tối đa cho một trận kéo cá.
- `Config.features.verboseLog` – bật log chi tiết để debug.

## Ghi chú

- Chỉ dùng cho mục đích học tập/tự động hoá cá nhân trên máy của bạn.
- XXTouch Elite dùng các API `touch.on/move/off`, `screen.get_color`,
  `screen.size`, `sys.msleep`, `sys.toast`; AutoTouch dùng
  `touchDown/Move/Up`, `getColor`, `getScreenResolution`, `usleep`, `toast`.
  `lib/utils.lua` tự chọn đúng bộ API — bạn không cần sửa gì thêm.
