# Bản tự cập nhật (full build)

Artifact build ([Build, chạy, đóng gói](build.md)) dùng phần C++/Rust do Mozilla biên dịch sẵn, nên updater
trong đó chỉ tin chữ ký của Mozilla và bị tắt. Bản phát hành tự cập nhật được
build **đầy đủ** (`OPZ_BUILD=full`, `mozconfig.full`). Updater trong bản này chỉ
cài file cập nhật (`.mar`) được ký bằng khoá của Opz.

| | Artifact (mặc định) | Full (`OPZ_BUILD=full`) |
|---|---|---|
| mozconfig / objdir | `mozconfig` / `engine/obj-artifact` | `mozconfig.full` / `engine/obj-full` |
| Biên dịch C++/Rust | không | có (M2: ~53 phút lần đầu, nhanh hơn nhiều khi `sccache` có sẵn) |
| Updater | tắt | bật, tin `updates/certs/*.der` |
| Dùng cho | sửa front-end hằng ngày | phát hành |

**Một lần cho mỗi máy build:**

```bash
OPZ_BUILD=full scripts/bootstrap.sh   # clang, Rust, macOS SDK... vào $FFB_ROOT/toolchain
scripts/mar-keys.sh                   # khoá ký (chỉ chạy MỘT lần cho cả dự án)
```

- Khoá bí mật nằm ở `$FFB_ROOT/keys/mar/` (ngoài repo). Chứng chỉ công khai ở
  `updates/certs/` (trong repo, được biên dịch vào updater qua patch 0045).
- **Sao lưu `$FFB_ROOT/keys/mar/` ra nơi an toàn.** Mất cả hai khoá thì các máy đã cài
  không bao giờ tự cập nhật được nữa, phải cài lại bằng tay.
  - `primary` ký mọi bản.
  - `secondary` là khoá dự phòng, cất offline.
- Máy build Linux: chép `$FFB_ROOT/keys/mar/` sang (không chạy lại `mar-keys.sh`).

**Điền server** trong `updates/update.env`:
- `OPZ_UPDATE_BASE_URL`: URL gốc mà các máy cài Opz hỏi cập nhật (http hoặc https).
- `OPZ_UPDATE_PUBLISH`: đích `rsync` trỏ vào thư mục web phía sau URL đó.

URL được ghi vào `distribution/policies.json` (`AppUpdateURL`) của từng bản phát hành.
Bản nào ra với URL sai thì chỉ sửa được bằng cách cài lại bằng tay.

**Mỗi lần phát hành:**

```bash
OPZ_BUILD=full scripts/build.sh
scripts/release.sh --publish
```

`release.sh` làm các bước sau:
1. Đóng gói. macOS: `Opz.app` (bundle id `org.opz.browser`) → `.dmg`. Linux: tarball như `package.sh`.
   Windows: `.win64.zip` chứa thư mục `Opz\` (chưa có bộ cài, chưa ký Authenticode).
2. Đổi policies: bỏ `DisableAppUpdate`, thêm `AppUpdateURL`.
3. Tạo file cập nhật đầy đủ (`make_full_update.sh`), ký bằng `signmar` (công cụ NSS lấy
   từ chính build), rồi kiểm tra chữ ký bằng chứng chỉ trong `updates/certs/`.
4. Ghi `dist/release/site/<BUILD_TARGET>/update.xml`.
5. `--publish`: gọi `scripts/publish.sh`. Script `rsync` file `.mar`/bộ cài trước,
   `update.xml` sau cùng, và không xoá gì trên server. Máy không có rsync (Windows) thì chép
   `dist/release/site/` sang máy khác rồi chạy `scripts/publish.sh <thư-mục>` ở đó.

Bố cục trên server:

```
<OPZ_UPDATE_BASE_URL>/
├── Darwin_aarch64-gcc3/update.xml
├── Linux_x86_64-gcc3/update.xml
├── WINNT_x86_64-msvc-x64/update.xml       Windows x64
├── WINNT_x86_64-msvc-aarch64/update.xml   Windows ARM chạy bản x64 (cùng nội dung)
├── files/opz-<ver>-<buildid>.<BUILD_TARGET>.complete.mar, bộ cài .dmg / .tar.xz / .win64.zip
└── latest/opz-mac.dmg, opz-linux-x86_64.tar.xz, opz-win64.zip   (symlink tới bản mới nhất)
```

Trên Windows, `%BUILD_TARGET%` có thêm đuôi là CPU của máy đang chạy (`-x64`, `-aarch64`).

- Opz kiểm tra cập nhật khoảng 12 tiếng một lần, tải ngầm, và cài khi khởi động lại.
- Cùng phiên bản Firefox (vd. 159.0.1) nhưng BuildID mới vẫn được coi là bản mới.
- Máy đang chạy bản artifact (không có updater) phải cài tay **một lần** bản full từ
  `.dmg`/`.tar.xz`. Từ đó trở đi tự cập nhật. Profile giữ nguyên.
- Mỗi máy build ra bản cho hệ điều hành của nó: Mac ra bản macOS, máy Linux
  (`/mnt/ffbuild`) ra bản Linux, máy Windows (MozillaBuild) ra bản Windows. Riêng máy Linux
  còn build chéo được bản Windows x64 (cách CI của Mozilla và Zen làm, nhanh hơn build trên
  Windows nhiều lần): cần `apt install msitools`, rồi chạy các script với `OPZ_TARGET=win`
  (objdir riêng `obj-full-win`):

  ```bash
  export OPZ_TARGET=win OPZ_BUILD=full
  scripts/bootstrap.sh && scripts/build.sh && scripts/release.sh
  ```

  `bootstrap.sh` tải Windows SDK và MSVC từ Microsoft (`get_vs.py` của Firefox) vào
  `$FFB_ROOT/toolchain/vs`; configure tự tải wine. Không chạy được `signmar` của bản Windows,
  nên `release.sh` ký MAR bằng openssl và gói Python `mar` của Mozilla (cùng kiểu chữ ký
  RSA-SHA384). Các máy dùng chung khoá và chung server.
- **Windows:** build không kèm Mozilla Maintenance Service, vì dịch vụ này chỉ chạy updater có
  chữ ký của Mozilla (`mozconfig.full`). Giải nén zip vào thư mục user ghi được, vd.
  `%LOCALAPPDATA%\Opz`, thì Opz tự cập nhật mà không cần quyền admin. Đặt trong
  `Program Files` thì mỗi lần cập nhật đều phải có quyền admin. Bản chưa ký Authenticode, nên
  lần đầu mở SmartScreen sẽ cảnh báo (**More info → Run anyway**).

[← Mục lục](../README.md)
