# Branding và tên ứng dụng

- **Tên hiển thị** nằm ở `branding/opz/`:
  - `configure.sh`: `MOZ_APP_DISPLAYNAME`
  - `locales/en-US/brand.ftl`, `brand.properties`
  - `pref/firefox-branding.js`
- **Icon và logo:** logo "Pebble O" (chữ O trắng dáng viên sỏi trên nền xanh `#2563eb`,
  bản private màu tím `#6d28d9`). Bản gốc nằm trong vpock (file "Opz Browser", trang "Logo 1").
  `scripts/logo.py branding/opz --car` vẽ lại toàn bộ:
  - `default*.png`, `content/about-logo*`, `content/about.png`, `content/*-wordmark.svg`
  - Windows: `firefox.ico`, `firefox64.ico`, `pbmode.ico`, `VisualElements_*.png`,
    `PrivateBrowsing_*.png` (màu nền tile nằm trong `*.VisualElementsManifest.xml`)
  - macOS: `firefox.icns` và `Assets.car` (`--car` cần macOS có Xcode)

  Sau đó chạy `scripts/build.sh`. Các icon phụ (`document*`, `disk.icns`, `newtab.ico`,
  `newwindow.ico`) vẫn là hình quả cầu của branding unofficial.
- **Hạn chế của artifact build:** binary và dữ liệu ứng dụng biên dịch sẵn vẫn là Firefox,
  vì phần C++ là bản của Mozilla. Cách xử lý không cần patch:
  - `application.ini` riêng (Name=Opz, RemotingName=opz, `UAName=Firefox`), được nạp qua
    `XUL_APP_FILE`. Việc này do `run.sh` làm khi dev và do launcher `opz` làm ở bản phát hành.
  - Vendor vẫn là "Mozilla", nên profile nằm ở `~/.config/mozilla/opz`.
    `MOZ_APP_VENDOR` không đặt được từ mozconfig.
  - Không dùng tên và logo "Firefox" cho bản phát hành (trademark của Mozilla).
    UA vẫn chứa `Firefox/<ver>` để tương thích web, giống các bản fork khác.

## Theme

Theme mặc định là **Opz** (`browser/themes/addons/opz/manifest.json`, patch `0007`): một theme
tĩnh chỉ gồm màu, không ảnh nền hay gradient.
- Thanh tab, thanh công cụ và sidebar cùng một màu xám; tab đang chọn và ô địa chỉ sáng hơn
  (chế độ sáng: `#f2f2f2` / `#ffffff`) hoặc nhạt hơn (chế độ tối: `#1c1c1e` / `#2c2c2e`).
- Không có màu nhấn: không vạch màu trên tab, viền ô địa chỉ khi focus là xám `#8e8e93`.
- `dark_theme` trong manifest: tự đổi sáng/tối theo hệ thống.
- Mỗi profile, mới hay cũ, được chuyển sang Opz **một lần** lúc khởi động (`BuiltInThemes.sys.mjs`,
  đánh dấu bằng `opz.defaultThemeApplied`). Sau đó người dùng tự đổi theme trong
  Add-ons and themes → Themes thì lựa chọn đó được giữ.
- Đổi màu: sửa `manifest.json` trong `engine/`, tăng `version` ở cả manifest và
  `BuiltInThemeConfig.sys.mjs` (không tăng thì profile cũ không cài lại), `scripts/build.sh faster`.
- **Vùng nội dung** (patch `0008`, cuối `browser/themes/shared/tabbrowser/content-area.css`): là một
  "thẻ" bo đủ bốn góc (`--border-radius-medium`, 8px), có viền, cách mép phải và mép dưới cửa sổ một
  khoảng = bán kính góc cửa sổ − 8px (tối thiểu 4px), nên góc dưới đồng tâm với góc cửa sổ. Firefox
  gốc chỉ bo góc giáp thanh công cụ/sidebar. Khi toàn màn hình thì trở về như Firefox.
- **Ô URL** (patch `0009`, cuối `browser/themes/shared/urlbar.css`):
  - Khi không được chọn và không có danh sách gợi ý, ô chỉ rộng vừa địa chỉ (`field-sizing: content`),
    nằm đúng giữa cửa sổ (không phải giữa khoảng trống giữa các nút, vì bên trái nhiều nút hơn bên
    phải; cửa sổ hẹp hơn 900px thì ô quay về vị trí thường) và không có nền/viền.
  - Khoảng trống hai bên địa chỉ kéo được để di chuyển cửa sổ như phần còn lại của thanh công cụ
    (`-moz-window-dragging: drag` cho `#urlbar-container`, `no-drag` cho `#urlbar`). Trừ lúc Customize. Bấm vào ô (hoặc mở tab mới) thì ô giãn hết chiều
    rộng và có nền như cũ.
  - Không có khiên (trust icon), nút dịch và ngôi sao bookmark. Riêng trang không an toàn (http, trang
    bị lộ dữ liệu) vẫn hiện khiên kèm chữ "Not Secure". Bookmark bằng Cmd/Ctrl+D, dịch trang bằng
    menu ba gạch → Translate page.

[← Mục lục](../README.md)
