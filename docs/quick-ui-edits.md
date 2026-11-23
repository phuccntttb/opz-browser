# Sửa giao diện nhanh

Trong `engine/obj-artifact/dist/bin`, phần lớn file front-end là **symlink** về `engine/`,
nên sửa xong chỉ cần khởi động lại trình duyệt:

| Sửa gì | Cần làm | Thời gian đo |
|---|---|---|
| `.js`/`.mjs`, `.css`, `.ftl` thường (symlink) | khởi động lại trình duyệt | 0s build |
| file tiền xử lý (`browser.xhtml`, `preferences.xhtml`, file có `#ifdef`), file mới, `jar.mn` | `scripts/build.sh faster` | ~6s |
| `mozconfig`, `moz.build`, branding `configure.sh` | `scripts/build.sh` | ~10s |
| `prefs/*` | khởi động lại trình duyệt (đã symlink) | 0s |

Muốn biết một file có phải symlink không: `ls -l engine/obj-artifact/dist/bin/browser/chrome/...`.

[← Mục lục](../README.md)
