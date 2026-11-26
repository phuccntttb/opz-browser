# Checklist kiểm tra

Chạy sau mỗi lần build lớn hoặc nâng cấp Firefox:

- [ ] `opz/opz --version` → `Mozilla Opz <ver>`
- [ ] `about:support`:
  - Name là Opz
  - Profile nằm trong `~/.config/mozilla/opz`
  - User Agent kết thúc bằng `Firefox/<ver>`
- [ ] `about:policies`:
  - tab Active có đủ policy
  - tab Errors trống
- [ ] `about:config`: `browser.vpn_promo.enabled` = false (chứng tỏ `00-opz.js` đã được nạp)
- [ ] **New Tab:** không có Stories hay ô tài trợ.
- [ ] **Settings:**
  - không có More from Mozilla, Labs
  - Account and sync đăng nhập được
  - không có dòng "Your browser is being managed by your organization"
- [ ] **Sidebar:** không có chatbot AI.
- [ ] **Menu Help:** không có "Share ideas and feedback", "Switch to a new device".
- [ ] **Firefox View:** không có nút ở thanh tab, không có trong Customize và menu Tools.
- [ ] **Tab dọc:** profile mới mở ra với tab dọc bên trái, không có icon công cụ ở đáy cột; cột tab
  thu gọn thành icon, rê chuột vào thì mở rộng, rời chuột thì thu lại; Settings →
  Tabs and browsing có "Browser layout" để chuyển về tab ngang. Chuyển sang tab ngang thì cột
  bên trái biến mất hẳn; Cmd+B / Ctrl+B mở panel bookmark có nút chọn panel ở tiêu đề.
- [ ] **New Tab:** trống hẳn: không có ô tìm kiếm, Top Sites, Highlights, widget hay hình nền.
- [ ] **Thanh công cụ:** chỉ có lùi/tiến/tải lại, ô địa chỉ ở giữa và menu ba gạch (không có nút
  sidebar, Extensions, New Tab, "List all tabs"); thanh URL không có nút chọn
  công cụ tìm kiếm; thanh bookmark ẩn, không có "Import bookmarks...".
- [ ] **Settings:** không có mục Backup, Profiles.
- [ ] **Đăng nhập Google:** đăng nhập được, không bị báo "trình duyệt không an toàn".
- [ ] **AMO:** cài một add-on từ addons.mozilla.org.
- [ ] **Chào mừng:** profile mới hiện màn chào mừng toàn cửa sổ; đi hết các bước với "Yes, block ads"
  → uBlock Origin có trong Add-ons and themes, công cụ tìm kiếm đã chọn là mặc định. Khởi động lại
  thì không hiện nữa.
- [ ] **GPC:** `about:config` → `privacy.globalprivacycontrol.enabled` = true.
- [ ] **DRM:** phát một video DRM (bật DRM khi được hỏi).
- [ ] **Web app (Linux):** mở Gmail, bấm nút "Add tab to taskbar" ở ô URL → có cửa sổ app riêng
  và app có trong menu ứng dụng; đóng rồi mở lại từ menu; bấm lại nút trong cửa sổ app → app bị gỡ. Trong cửa sổ app thanh công cụ ẩn,
  rê lên mép trên thì hiện, rời chuột thì ẩn; Ctrl+L giữ nó hiện. Cửa sổ thường: bấm phải chỗ
  trống trên thanh → tích "Show toolbar only on hover" thì cũng ẩn như vậy.
- [ ] **Không đụng tới Firefox:** không có thư mục mới trong `~/.config/mozilla/firefox`.

[← Mục lục](../README.md)
