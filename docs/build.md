# Build, chạy, đóng gói

| Lệnh | Làm gì | Thời gian đo (máy dev) |
|---|---|---|
| `scripts/build.sh` | `mach build` + gắn `application.ini`, prefs, policies vào objdir | ~10s (incremental), ~30s sau khi xoá objdir, ~2 phút khi cần tải artifact |
| `scripts/build.sh faster` | chỉ front-end | ~6s |
| `scripts/run.sh [args]` | `mach run -purgecaches` với app data của Opz (`build.sh faster` không đổi build ID, nên phải xoá cache khởi động để chạy code mới) | — |
| `scripts/package.sh` | `mach package` + repack thành `opz/` + sha256 | ~50s, tarball 87 MB |
| `scripts/install-local.sh` | `package.sh` rồi cài vào `~/Apps/opz` (bản dùng hằng ngày), giữ bản cũ ở `~/Apps/opz.prev` | ~50s + vài giây giải nén |

## Vừa dùng vừa sửa

- **Bản dùng hằng ngày** cài ở `~/Apps/opz`, profile thật `~/.config/mozilla/opz/`.
- **Bản đang sửa** chạy bằng `scripts/run.sh` (profile tạm trong objdir), mở song song được.
  Không dùng nó để duyệt web thật: file front-end là symlink về `engine/`.
- Patch đã ổn thì đưa sang bản dùng hằng ngày:

  ```bash
  scripts/install-local.sh --wait   # đóng Opz khi được nhắc; cài xong tự mở lại, tab được khôi phục
  ```

  - Không cho cài khi Opz đang chạy từ `~/Apps/opz` (thay file dưới trình duyệt đang chạy sẽ làm nó crash); `--wait` chờ bạn đóng rồi mở lại.
  - `--no-package`: cài tarball mới nhất trong `dist/` mà không đóng gói lại.
  - `--rollback`: đổi về bản trước (`~/Apps/opz.prev`).
  - `OPZ_INSTALL_DIR=/đường/dẫn/opz`: cài chỗ khác (tên thư mục phải là `opz`).
  - Bản mới được giải nén cạnh bản cũ và chạy thử `opz --version` trước khi thay; menu ứng dụng được cập nhật qua `install-desktop.sh`.

Các bước `package.sh` thực hiện:
- Đổi thư mục `firefox/` thành `opz/`.
- Đổi tên binary thật `firefox-bin` thành `opz-bin`, bỏ stub `firefox`.
- Thêm launcher `opz`, `browser/application.ini` của Opz, `00-opz.js`,
  `distribution/policies.json` và file menu.
- Chạy thử `opz --version`; nếu không ra "Opz" thì dừng.

[← Mục lục](../README.md)
