# Nâng cấp lên bản Firefox mới

Ví dụ nâng từ 159.0.1 lên 159.0.2 (hoặc 160.0):

1. **Lưu hết công việc** trong `engine/`:

   ```bash
   scripts/export-patches.sh
   git add patches && git commit -m "..."
   ```

2. **Chọn tag mới** trong <https://github.com/mozilla-firefox/firefox/tags> (dạng
   `FIREFOX_160_0_RELEASE`) và sửa `FIREFOX_TAG` trong `upstream.env`.
3. **Tải lại source.** Lệnh này xoá `engine/` cũ (kể cả objdir), sau khi đã kiểm tra
   không mất patch nào:

   ```bash
   scripts/fetch.sh --force
   ```

4. **Áp lại patch:**

   ```bash
   scripts/apply.sh
   ```

   Nếu một patch không áp được, `apply.sh` dừng giữa chừng `git am`. Khi đó:

   ```bash
   cd engine
   # sửa file bị xung đột (git status để xem), rồi:
   git add <file> && git am --continue
   cd .. && scripts/export-patches.sh
   scripts/apply.sh
   ```

   Chạy lại `apply.sh` ở bước cuối để dựng nhánh sạch từ `patches/` mới và gắn overlay branding.

5. **Build và đóng gói:** `scripts/build.sh` (tải artifact của tag mới, ~2 phút),
   rồi `scripts/package.sh`.
6. **Chạy [checklist](checklist.md).** Bản mới có thể thêm pref, policy hoặc
   tính năng bloat mới. Hãy tra `browser/components/enterprisepolicies/schemas/policies-schema.json`
   và `browser/app/profile/firefox.js` của bản mới.
7. **Commit** `upstream.env` và `patches/`.

Lần đầu bootstrap trên ổ mới mới cần chạy `bootstrap.sh`; khi nâng cấp chỉ cần chạy lại
nếu `mach build` báo thiếu toolchain.

Artifact build chỉ hoạt động khi CI của Mozilla có bản build cho đúng commit của tag.
Các tag `*_RELEASE` mới thường có sẵn artifact; với bản cũ, CI có thể đã xoá artifact.
Nếu `build.sh` báo không tìm thấy artifact, hãy chọn một tag mới hơn.

[← Mục lục](../README.md)
