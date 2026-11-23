# Opz Browser

Trình duyệt dựa trên Firefox (kênh Release, hiện là **Firefox 159.0.1**).

Repo này **không chứa source Firefox**. Nó chỉ gồm patch, branding, prefs và script.
Source Firefox được tải vào `engine/` (gitignore) theo tag ghi trong `upstream.env`,
rồi build bằng **artifact build**: phần C++/Rust tải sẵn từ CI của Mozilla, chỉ
JS/CSS/HTML/prefs được build trên máy. Nhờ vậy build mất khoảng 10 giây đến 2 phút
thay vì nhiều giờ.

## Tài liệu

**Dùng Opz**
- [Cài và dùng bản phát hành](docs/install.md)

**Build**
- [Cấu trúc repo](docs/repo-layout.md)
- [Dựng môi trường build trên ổ mới](docs/setup.md): Linux, macOS, Windows
- [Build, chạy, đóng gói](docs/build.md)

**Phát hành**
- [Bản tự cập nhật (full build)](docs/self-update.md): full build, ký `.mar`, `update.xml`
- [Phát hành bằng GitHub Actions](docs/github-actions.md)
- [Nâng cấp lên bản Firefox mới](docs/upgrade-firefox.md)
- [Checklist kiểm tra](docs/checklist.md)

**Tuỳ biến**
- [Sửa giao diện nhanh](docs/quick-ui-edits.md)
- [Thêm / sửa patch](docs/patches.md)
- [Branding và tên ứng dụng](docs/branding.md)
- [Gỡ bloat](docs/debloat.md)

**Khác**
- [Lưu ý](docs/notes.md)
