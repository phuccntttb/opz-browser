# Cài và dùng bản phát hành

File phát hành: `dist/opz-<version>.linux-x86_64.tar.xz`, kèm file `.sha256`.

```bash
sha256sum -c opz-159.0.1.linux-x86_64.tar.xz.sha256
tar -xJf opz-159.0.1.linux-x86_64.tar.xz -C ~/Apps
~/Apps/opz/opz
```

Thêm vào menu ứng dụng. Lệnh này ghi một file duy nhất,
`~/.local/share/applications/opz.desktop`, và không cần root:

```bash
~/Apps/opz/install-desktop.sh
```

Gỡ khỏi menu bằng `~/Apps/opz/install-desktop.sh --remove`. Gỡ hẳn thì xoá thêm
thư mục `opz/`.

- **Luôn chạy qua `opz/opz`** (launcher), không chạy thẳng `opz-bin`.
  - Launcher đặt `XUL_APP_FILE` trỏ vào `browser/application.ini` của Opz.
  - Nếu chạy `opz-bin` trực tiếp, trình duyệt sẽ dùng dữ liệu ứng dụng của Firefox
    được biên dịch sẵn, và profile sẽ là của Firefox.
- **Profile:** `~/.config/mozilla/opz/`, tách hẳn khỏi Firefox (`~/.config/mozilla/firefox/`).
- **Cập nhật:** bản phát hành từ full build ([Bản tự cập nhật](self-update.md)) tự cập nhật từ server của Opz.
  Bản artifact cũ (không có updater) thì giải nén đè thư mục `opz/`.
- **Window class / Wayland app_id:** `opz`.

[← Mục lục](../README.md)
