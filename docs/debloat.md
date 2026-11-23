# Gỡ bloat

Phần lớn nằm trong `prefs/`; chỉ những chỗ không có pref/policy nào tắt được mới dùng patch
(`0002`–`0006`).

- **`prefs/policies.json`**:
  - **Khoá:**
    - telemetry (`DisableTelemetry`)
    - studies/Normandy/Nimbus (`DisableFirefoxStudies`, `DisableRemoteImprovements`)
    - cập nhật (`DisableAppUpdate`, `DisableSystemAddonUpdate`)
    - tài khoản/Sync (`DisableAccounts`)
    - lệnh gửi feedback cho Mozilla (`DisableFeedbackCommands`)
    - VPN (`IPProtectionAvailable`)
    - Terms of Use, trang first-run/post-update
    - bookmark mặc định trỏ về trang Mozilla (`NoDefaultBookmarks`, chỉ có tác dụng với profile mới)
  - **Không khoá** (người dùng bật lại được):
    - `FirefoxHome`: New Tab trống hẳn (tắt ô tìm kiếm, Top Sites, Highlights, Stories, tài trợ, Weather)
    - `FirefoxSuggest`
    - `UserMessaging` (onboarding, gợi ý, More from Mozilla, Labs)
    - `AIControls` (chặn mọi tính năng AI trừ Translations)
- **`prefs/opz.js`**: pref không có policy tương ứng, người dùng bật lại được trong `about:config`:
  - promo VPN/Monitor/Relay, đề xuất add-on, UITour, khảo sát feedback
  - sponsored top sites trên thanh URL và việc tải tile tài trợ (Contile), trending
  - Google Lens (visual search) trong menu chuột phải ảnh
  - phần AI còn sót (smart tab groups, semantic history)
  - lời nhắc "đặt làm trình duyệt mặc định" lúc khởi động (Settings vẫn có nút)
  - **nút chọn công cụ tìm kiếm** ở đầu thanh URL (`browser.urlbar.scotchBonnet.enableOverride`):
    quay về thanh URL cổ điển, biểu tượng các công cụ tìm kiếm nằm ở cuối danh sách gợi ý
  - **thanh bookmark** ẩn mặc định và không thêm nút "Import bookmarks..."
    (Cmd/Ctrl+Shift+B để hiện lại thanh bookmark)
  - **New Tab trống hẳn** (`browser.newtabpage.enabled = false`): không có nút bút chì (Customize) và không có panel tuỳ chỉnh, hình nền, widget, section, nội dung tài trợ
  - **widget và hình nền New Tab** (đồng hồ, danh sách, focus timer, ô chữ...)
  - **hộp "Translate this page?" tự bật** trên trang tiếng nước ngoài (`browser.translations.automaticallyPopup`);
    nút dịch trong ô URL vẫn còn, bấm vào thì mở đúng hộp đó
  - **Profiles** (trình quản lý nhiều hồ sơ kiểu mới; vẫn bật nếu đã từng tạo hồ sơ bằng nó)
    và **Backup**
  - **luôn mở lại phiên trước** (`browser.startup.page` = 3), không hiện trang "Sorry..." sau crash
  - **cuộn mượt kiểu quán tính** (`general.smoothScroll.msdPhysics.*`, theo Smoothfox V3) và lăn
    chuột nhanh gấp 3 (`mousewheel.default.delta_multiplier_y` = 300; touchpad quá nhanh thì giảm số này)
  - **giảm RAM**:
    - tự giải phóng tab nền khi máy sắp hết RAM (`browser.tabs.unloadOnLowMemory`; Firefox chỉ bật
      sẵn trên macOS/Windows, Opz bật cả Linux). Tab dùng trong 10 phút gần nhất, đang phát tiếng,
      đang Picture-in-Picture, đang gọi (WebRTC) hoặc tab riêng tư thì không bị giải phóng.
    - không nạp sẵn trang New Tab ẩn (`browser.newtab.preload`)
    - không giữ sẵn tiến trình nội dung chờ trang tiếp theo (`dom.ipc.processPrelaunch.enabled`)
    - bộ đệm Back/Forward giữ tối đa 2 trang cho mọi tab (`browser.sessionhistory.max_total_viewers`,
      Firefox tự chọn tới 8). Lùi xa hơn thì trang tải lại.
    - thẻ xem trước khi rê chuột lên tab không có ảnh chụp (`browser.tabs.hoverPreview.showThumbnails`)
    - không ghi tương tác trang (thời gian xem, cuộn, gõ) vào places.sqlite (`browser.places.interactions.enabled`)
    - Xem RAM theo từng tab/tiến trình ở `about:processes`.
  - Trong một thư mục, Firefox đọc file pref theo thứ tự **ngược bảng chữ cái**,
    nên file được cài với tên `00-opz.js` để đọc sau và thắng `firefox.js`.
- **`mozconfig`**: `--disable-crashreporter` (không gửi crash về Mozilla dưới tên Firefox)
  và `--disable-updater` (updater sẽ kéo bản Firefox về).

- **Patch `0002-Help-menu-...`**: ẩn "Share ideas and feedback" và "Switch to a new device"
  khỏi menu Help và menu ba gạch (mục "Switch to a new device" không có pref/policy nào để tắt).
  Mục giới thiệu Firefox (referrals) đã ẩn sẵn nhờ `browser.referrals.enabled=false`.
- **Patch `0003-Firefox-View-...`**: bỏ nút Firefox View (kể cả trong bảng Customize), ẩn mục
  Tools → Firefox View và nút "View all tabs" trong menu danh sách tab. Không có pref nào tắt
  được Firefox View; `about:firefoxview` vẫn mở được nếu gõ tay (sidebar dùng chung code của nó).
- **Patch `0004-Sidebar-...`**: khi `sidebar.revamp` tắt, ẩn mục "Browser layout" (chọn tab dọc)
  trong Settings và "Turn on vertical tabs" trong menu chuột phải thanh tab, vì tab dọc cần
  sidebar mới. Bật lại `sidebar.revamp` thì các mục này hiện lại.
- **Patch `0006-Sidebar-...`**: **tab dọc bật mặc định**. Bật một lần cho mỗi profile, ngay sau
  khi cửa sổ đầu tiên mở (đánh dấu bằng `opz.verticalTabsDefaultApplied`), theo đúng đường
  Firefox dùng khi người dùng tự bật. Không đặt `sidebar.verticalTabs=true` làm mặc định trong
  `opz.js`, vì profile mới khởi động thẳng vào tab dọc sẽ bị Firefox xếp sai thanh công cụ (mất
  nút sidebar và nút reload, thứ tự bị đảo). Khi đang dùng tab dọc, cột bên trái chỉ có tab: các
  icon công cụ (bookmark, history, synced tabs, password, AI, nút Customize) bị ẩn bằng
  `visibility` và chiều cao 0 chứ không dùng `display: none`, vì cột tab thu gọn lấy chiều rộng
  từ các icon này. Các panel đó vẫn mở được qua View → Sidebar hoặc phím tắt (macOS: Cmd+B,
  Cmd+Shift+H; Linux: Ctrl+B, Ctrl+H). Người dùng chuyển về tab ngang được trong Settings → Tabs and browsing hoặc
  chuột phải thanh tab. Với tab ngang, mặc định là `sidebar.visibility = "hide-launcher"` (sửa
  `DEFAULT_HORIZONTAL_VISIBILITY` trong `SidebarManager.sys.mjs`): không có cột icon bên trái,
  bookmark/history mở thành panel có nút chọn panel ở tiêu đề. Bật lại cột icon được bằng ô
  "Open tools from sidebar" trong Customize của sidebar.
- **Patch `0011-Toolbar-...`**: bỏ nút sidebar khỏi bố cục mặc định của thanh công cụ, và gỡ nút
  sidebar cùng nút New Tab khỏi thanh công cụ của profile cũ một lần (đánh dấu bằng
  `opz.customizableui.navBarButtonsRemoved`). Việc gỡ sửa bố cục đã lưu trước khi dựng thanh công cụ,
  nên không kích hoạt quy tắc "gỡ nút sidebar thì tắt tab dọc" của Firefox. Tab mới: nút "+ New Tab"
  trong cột tab hoặc Cmd/Ctrl+T. Thêm lại được qua Customize Toolbar.
- **Nút Extensions** (mảnh ghép): ẩn bằng `extensions.unifiedExtensions.button.always_visible=false`
  trong `prefs/opz.js`. Nút vẫn hiện khi một tiện ích cần chú ý; quản lý tiện ích qua menu → Add-ons
  and themes; tiện ích đã ghim lên thanh công cụ vẫn có nút riêng.
- **Patch `0010-Sidebar-...`**: với tab dọc, mặc định là `sidebar.visibility = "expand-on-hover"`
  (sửa `DEFAULT_VERTICAL_VISIBILITY` trong `SidebarManager.sys.mjs` và giá trị tương ứng trong
  `browser-sidebar.js`): cột tab thu gọn thành icon, rê chuột vào thì mở rộng, rời chuột thì thu lại.
  Profile cũ đang để "always-show" được chuyển một lần (đánh dấu bằng `opz.expandOnHoverApplied`);
  muốn cột luôn mở rộng thì chọn lại trong Customize của sidebar.
- **Patch `0005-Toolbar-...`**: bỏ nút "List all tabs" (biểu tượng cửa sổ có kính lúp) khỏi bố cục
  mặc định, và gỡ nó khỏi profile cũ một lần (đánh dấu bằng `opz.customizableui.allTabsButtonRemoved`).
  Người dùng thêm lại được qua Customize Toolbar.

## Chặn tracker và quảng cáo

Opz không tự viết bộ chặn riêng (giống Zen):
- **Tracker:** dùng Enhanced Tracking Protection của Firefox ở mức **Standard** (chặn tracker
  mạng xã hội, cookie chéo trang, cryptominer, fingerprinter đã biết; Total Cookie Protection).
  Không đặt Strict làm mặc định vì dễ làm hỏng đăng nhập và nội dung nhúng; người dùng tự chọn
  trong Settings → Privacy & Security. `opz.js` bật thêm **Global Privacy Control**
  (`privacy.globalprivacycontrol.enabled`), báo cho trang web đừng bán/chia sẻ dữ liệu.
- **Quảng cáo:** patch `0013` phủ một **màn chào mừng toàn cửa sổ** lên cửa sổ đầu tiên, **một lần
  mỗi profile** (đánh dấu bằng `opz.welcome.shown`):
  - Màn mở đầu: nền xanh của logo, tiêu đề "Welcome to Opz Browser" hiện từng chữ, nút "Get started".
  - Sau đó là một khung 2 cột, mỗi bước có Back / Skip / Continue (Skip = không làm gì ở bước đó):
    1. **Import**: "Start fresh" (mặc định) hoặc nhập từ trình duyệt khác. Chọn nhập thì sau khi
       đóng màn chào mừng sẽ mở hộp thoại Import browser data của Firefox.
    2. **Công cụ tìm kiếm**: danh sách công cụ đang có, chọn sẵn cái mặc định hiện tại.
    3. **Chặn quảng cáo**: mặc định **Yes**: cài uBlock Origin (`latest.xpi` từ addons.mozilla.org,
       không hỏi quyền thêm vì người dùng vừa đồng ý). Không có mạng thì bỏ qua, ghi lỗi ra
       Browser Console. Bỏ bước này nếu uBlock đã cài.
    4. **Trình duyệt mặc định**: giống nút trong Settings. Bỏ bước này nếu Opz đã là mặc định
       hoặc policy cấm.
    5. **Xong**: "Start browsing".
  - Màn chào mừng là một `<iframe>` chrome (`chrome://browser/content/opz/welcome.xhtml`) đặt
    trên cùng cửa sổ. `gBrowserInit._maybeShowOpzWelcome` (`browser-init.js`) chèn nó ngay trong
    `onBeforeInitialXULLayout`, trước khi cửa sổ vẽ lần đầu, nên không thấy trình duyệt lóe lên
    trước. Overlay giữ focus bàn phím cho đến khi xong. Trang chỉ thu lựa chọn; hàm đó thực hiện
    chúng sau khi gỡ iframe.
  - File: `browser/base/content/opz/welcome.{xhtml,mjs,css}`, chuỗi trong
    `browser/locales/en-US/browser/opzWelcome.ftl`. Sửa giao diện chỉ cần khởi động lại (file là symlink).
  - Xem lại: đặt `opz.welcome.shown` = false trong `about:config` rồi khởi động lại.
  - Vì nút Extensions bị ẩn, popup của uBlock mở qua menu → Add-ons and themes, hoặc ghim nút
    uBlock lên thanh công cụ.
- **Telemetry và nội dung tài trợ còn sót** (thêm vào `opz.js`): các ping telemetry
  (archive, new-profile, shutdown, BHR, update), tự gửi báo cáo crash, Firefox Suggest kể cả
  gợi ý tài trợ, ô "Support Firefox" (tài trợ) trong Settings → Home, quảng cáo app di động/VPN
  trong trang báo cáo bảo vệ.

Vì có policy nên Settings hiện dòng *"Your browser is being managed by your organization"*;
xem chi tiết ở `about:policies`.

**Giữ lại:** Remote Settings (blocklist bảo mật, thu hồi chứng chỉ, model dịch),
kiểm tra captive portal, Web Push, tải GMP (Widevine/OpenH264), blocklist add-on và
đăng nhập Google.

DRM (Widevine) trên Linux tắt mặc định như Firefox: lần đầu gặp trang DRM sẽ có thanh
"Enable DRM"; bấm vào thì Widevine được tải về.

[← Mục lục](../README.md)
