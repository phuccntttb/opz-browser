# Cấu trúc repo

```
opz/
├── README.md          giới thiệu + mục lục tài liệu
├── docs/              tài liệu, mỗi chủ đề một file
├── env.sh             biến môi trường (mọi script tự source); dừng nếu /mnt/ffbuild chưa mount
├── upstream.env       repo + tag Firefox đang bám (FIREFOX_TAG)
├── mozconfig          cấu hình build (artifact build, branding, tắt crashreporter/updater)
├── mozconfig.full     full build có updater (OPZ_BUILD=full, docs/self-update.md)
├── updates/
│   ├── update.env     URL server cập nhật + đích rsync
│   └── certs/         chứng chỉ ký .mar (biên dịch vào updater)
├── patches/           NNNN-<mô tả>.patch — mỗi patch một mục đích, áp theo thứ tự tên
├── branding/opz/      tên, logo, prefs của branding (symlink vào engine/browser/branding/opz)
├── prefs/
│   ├── policies.json  enterprise policies (→ distribution/policies.json)
│   └── opz.js         pref mặc định, không khoá (→ browser/defaults/preferences/00-opz.js)
├── packaging/
│   ├── opz                launcher của bản phát hành
│   ├── opz.desktop.in     mẫu file menu (@OPZ_DIR@ được thay khi cài)
│   └── install-desktop.sh người dùng tự chạy để thêm/gỡ menu
├── scripts/
│   ├── fetch.sh           shallow clone tag vào engine/ + kiểm tra toàn vẹn
│   ├── verify-engine.sh   băm lại mọi file trong engine/ so với git
│   ├── bootstrap.sh       mach bootstrap (artifact mode, không apt/sudo)
│   ├── apply.sh           engine/ = tag + patches/*.patch trên nhánh "opz"
│   ├── export-patches.sh  commit trên nhánh "opz" → patches/*.patch
│   ├── build.sh           ./mach build   (build.sh faster: chỉ JS/CSS/HTML)
│   ├── run.sh             ./mach run     (profile tạm trong objdir)
│   ├── package.sh         ./mach package + repack → dist/opz-<ver>.linux-x86_64.tar.xz
│   ├── install-local.sh   package.sh + cài/cập nhật ~/Apps/opz (giữ bản cũ để rollback)
│   ├── mar-keys.sh        tạo khoá ký .mar (một lần)
│   ├── release.sh         bản phát hành tự cập nhật: gói + .mar đã ký + update.xml
│   ├── publish.sh         rsync dist/release/site/ lên server (release.sh --publish gọi nó)
│   ├── ci-secrets.sh      đưa khoá lên GitHub Secrets cho workflow Release (chạy trên Mac)
│   └── logo.py            vẽ logo Opz (PNG, ICO, ICNS, Assets.car, SVG)
├── dist/              (gitignore) tarball phát hành
└── engine/            (gitignore) source Firefox + objdir engine/obj-artifact
```

[← Mục lục](../README.md)
