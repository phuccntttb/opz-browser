# Opz Browser

Trình duyệt dựa trên Firefox (kênh Release, hiện là **Firefox 159.0.1**).

Repo này **không chứa source Firefox**. Nó chỉ gồm patch, branding, prefs và script.
Source Firefox được tải vào `engine/` (gitignore) theo tag ghi trong `upstream.env`,
rồi build bằng **artifact build**: phần C++/Rust tải sẵn từ CI của Mozilla, chỉ
JS/CSS/HTML/prefs được build trên máy. Nhờ vậy build mất khoảng 10 giây đến 2 phút
thay vì nhiều giờ.

Mục lục:
1. [Cài và dùng bản phát hành](#1-cài-và-dùng-bản-phát-hành)
2. [Cấu trúc repo](#2-cấu-trúc-repo)
3. [Dựng môi trường build trên ổ mới](#3-dựng-môi-trường-build-trên-ổ-mới)
4. [Build, chạy, đóng gói](#4-build-chạy-đóng-gói)
5. [Sửa giao diện nhanh](#5-sửa-giao-diện-nhanh)
6. [Thêm / sửa patch](#6-thêm--sửa-patch)
7. [Nâng cấp lên bản Firefox mới](#7-nâng-cấp-lên-bản-firefox-mới)
8. [Branding và tên ứng dụng](#8-branding-và-tên-ứng-dụng)
9. [Gỡ bloat](#9-gỡ-bloat)
10. [Checklist kiểm tra](#10-checklist-kiểm-tra)
11. [Lưu ý](#11-lưu-ý)

---

## 1. Cài và dùng bản phát hành

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
- **Cập nhật:** bản phát hành từ full build (mục 4b) tự cập nhật từ server của Opz.
  Bản artifact cũ (không có updater) thì giải nén đè thư mục `opz/`.
- **Window class / Wayland app_id:** `opz`.

## 2. Cấu trúc repo

```
opz/
├── env.sh             biến môi trường (mọi script tự source); dừng nếu /mnt/ffbuild chưa mount
├── upstream.env       repo + tag Firefox đang bám (FIREFOX_TAG)
├── mozconfig          cấu hình build (artifact build, branding, tắt crashreporter/updater)
├── mozconfig.full     full build có updater (OPZ_BUILD=full, mục 4b)
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

## 3. Dựng môi trường build trên ổ mới

Áp dụng khi làm trên ổ ngoài hoặc máy khác. Mọi thứ nằm trên **một phân vùng ext4 mount
ở `/mnt/ffbuild`**, ổ hệ thống gần như không bị ghi gì.

### 3.1. Yêu cầu
- **Máy:** Linux x86_64, có mạng (để tải source, toolchain và artifact).
- **Dung lượng:** cần khoảng **10 GB**, nên để từ 20 GB trở lên.
  - Source và git: 4.9 GB
  - Objdir: 1.2 GB
  - Toolchain: 1.6 GB
  - Tarball và tmp: khoảng 1 GB
- **Định dạng phân vùng: ext4.** **Không** dùng NTFS/exFAT hay file image đặt trên
  NTFS (FUSE). Đã từng gặp lỗi hỏng file âm thầm với cách này.

### 3.2. Gói hệ thống (tự chạy, cần root)
Artifact build không cần thêm gói nào ngoài những thứ thường có sẵn:

```bash
sudo apt install --no-install-recommends git curl python3 unzip make perl xz-utils
```

`mach bootstrap` được gọi với `--no-system-changes`, nên **không** chạy apt/sudo.

### 3.3. Phân vùng và mount (tự chạy, cần root)
Thay `/dev/sdX1` bằng phân vùng thật, kiểm tra kỹ bằng `lsblk` trước:

```bash
sudo mkfs.ext4 -L ffbuild /dev/sdX1
sudo mkdir -p /mnt/ffbuild
echo 'LABEL=ffbuild /mnt/ffbuild ext4 noatime,nofail 0 2' | sudo tee -a /etc/fstab
sudo mount /mnt/ffbuild
sudo chown "$USER": /mnt/ffbuild
```

`nofail` giúp máy vẫn khởi động bình thường khi rút ổ ngoài. Mọi script đều kiểm tra
`mountpoint -q /mnt/ffbuild` và **dừng** nếu chưa mount, nên không ghi nhầm vào `/home`.

### 3.4. Lấy repo và build lần đầu

```bash
git clone <đường-dẫn-hoặc-URL-repo-opz> /mnt/ffbuild/opz
cd /mnt/ffbuild/opz
scripts/fetch.sh        # ~3.5 phút: clone tag + kiểm tra toàn vẹn từng file
scripts/bootstrap.sh    # ~2 phút, chỉ lần đầu trên ổ này (toolchain vào /mnt/ffbuild/toolchain)
scripts/apply.sh        # nhánh opz = tag + patches/
scripts/build.sh        # ~2 phút (tải artifact), các lần sau ~10s
scripts/run.sh          # chạy thử
scripts/package.sh      # ~50s → dist/opz-<ver>.linux-x86_64.tar.xz
```

Bạn không cần sửa `~/.bashrc`. Muốn có môi trường trong shell hiện tại thì chạy
`. /mnt/ffbuild/opz/env.sh`. Môi trường dùng chung, nằm ngoài repo:

| Đường dẫn | Biến |
|---|---|
| `/mnt/ffbuild/toolchain/mozbuild` | `MOZBUILD_STATE_PATH` |
| `/mnt/ffbuild/toolchain/rustup` | `RUSTUP_HOME` |
| `/mnt/ffbuild/toolchain/cargo` | `CARGO_HOME` (`bin/` đứng đầu `PATH`) |
| `/mnt/ffbuild/cache` | `XDG_CACHE_HOME`, `SCCACHE_DIR`, `PIP_CACHE_DIR`, `UV_CACHE_DIR`, `npm_config_cache` |
| `/mnt/ffbuild/tmp` | `TMPDIR` |

### 3.5. macOS (Apple Silicon, ổ ngoài)

`env.sh` tự nhận macOS. Khi đó repo phải nằm trên ổ ngoài `/Volumes/<tên-ổ>/...`, và mọi thứ
khác nằm trong `/Volumes/<tên-ổ>/ffbuild` (đổi bằng biến `FFB_ROOT`):

| Đường dẫn | Nội dung |
|---|---|
| `ffbuild/toolchain/{mozbuild,python,uv,bin}` | toolchain của mach, Python 3.12 (mach cần ≥ 3.10, macOS chỉ có 3.9) |
| `ffbuild/cache`, `ffbuild/tmp` | cache và file tạm |
| `ffbuild/opz-engine` | source Firefox, dùng khi đường dẫn repo có dấu cách (build Firefox không chịu dấu cách); `engine` trong repo là symlink tới đây |

Cài Python một lần (cần Xcode và Command Line Tools):

```bash
T=/Volumes/<tên-ổ>/ffbuild/toolchain
# tải uv-aarch64-apple-darwin.tar.gz từ github.com/astral-sh/uv/releases, giải nén uv vào $T/uv/bin
UV_PYTHON_INSTALL_DIR=$T/python $T/uv/bin/uv python install 3.12 --no-bin
mkdir -p $T/bin && ln -sfn "$(UV_PYTHON_INSTALL_DIR=$T/python $T/uv/bin/uv python find 3.12 --managed-python)" $T/bin/python3
```

Sau đó các bước giống 3.4 (`fetch.sh`, `bootstrap.sh`, `apply.sh`, `build.sh`, `run.sh`).
Bản build chạy từ `engine/obj-artifact/dist/Opz Browser.app`. `package.sh` chỉ dành cho Linux.

**Bản dùng hằng ngày và bản dev trên macOS** (chạy song song được):

| | Bản thật | Bản dev |
|---|---|---|
| Cài / chạy | `scripts/install-local.sh` → `~/Applications/Opz.app` | `scripts/run.sh` |
| Profile | `~/Library/Application Support/Opz` | profile tạm trong objdir |
| Bundle id | `org.opz.browser` | `org.mozilla.opzbrowser` |

`install-local.sh` trên macOS gọi `scripts/install-local-mac.sh`: chạy `build.sh`, copy
`Opz Browser.app` ra (thay mọi symlink trỏ vào source/objdir bằng file thật, nên bản cài không
phụ thuộc ổ ngoài), thêm launcher `Contents/MacOS/opz` đặt `XUL_APP_FILE`, đổi tên/bundle id rồi
ký ad-hoc. Các tuỳ chọn `--no-package` (bỏ qua build), `--wait`, `--rollback` (về `Opz.prev.app`)
giống bản Linux. Mở bằng Finder/Spotlight hoặc `open ~/Applications/Opz.app`.

### 3.6. Windows

`env.sh` tự nhận Windows (shell MozillaBuild). Mọi thứ nằm trong `C:\ffbuild` (đổi bằng biến
`FFB_ROOT`):

| Đường dẫn | Nội dung |
|---|---|
| `C:\ffbuild\opz-engine` | source Firefox + objdir. Windows mặc định không bật long paths nên source cần đường dẫn ngắn; `engine` trong repo là junction tới đây (do `fetch.sh` tạo) |
| `C:\ffbuild\toolchain`, `cache`, `tmp` | toolchain của mach, cache và file tạm |

1. Cài [MozillaBuild](https://ftp.mozilla.org/pub/mozilla/libraries/win32/MozillaBuildSetup-Latest.exe)
   vào `C:\mozilla-build` (cần quyền admin).
2. Clone repo **với `core.autocrlf=false`**. Git for Windows thường bật `autocrlf`, khi đó script
   và patch bị đổi sang CRLF và hỏng:

   ```bash
   git clone -c core.autocrlf=false <đường-dẫn-hoặc-URL-repo-opz> opz
   ```

3. Mở `C:\mozilla-build\start-shell.bat`, `cd` vào repo rồi chạy các bước như 3.4
   (`fetch.sh`, `bootstrap.sh`, `apply.sh`, `build.sh`, `run.sh`). Git Bash không chạy được `mach`.

Khác với Linux:
- Symlink trên Windows cần quyền admin, nên branding được gắn bằng **junction**, còn `prefs/*`
  được **copy** vào objdir: sửa prefs xong phải chạy lại `scripts/build.sh`.
- `package.sh` chỉ dành cho Linux. Bản phát hành Windows do `release.sh` đóng gói (xem 4b).

## 4. Build, chạy, đóng gói

| Lệnh | Làm gì | Thời gian đo (máy dev) |
|---|---|---|
| `scripts/build.sh` | `mach build` + gắn `application.ini`, prefs, policies vào objdir | ~10s (incremental), ~30s sau khi xoá objdir, ~2 phút khi cần tải artifact |
| `scripts/build.sh faster` | chỉ front-end | ~6s |
| `scripts/run.sh [args]` | `mach run -purgecaches` với app data của Opz (`build.sh faster` không đổi build ID, nên phải xoá cache khởi động để chạy code mới) | — |
| `scripts/package.sh` | `mach package` + repack thành `opz/` + sha256 | ~50s, tarball 87 MB |
| `scripts/install-local.sh` | `package.sh` rồi cài vào `~/Apps/opz` (bản dùng hằng ngày), giữ bản cũ ở `~/Apps/opz.prev` | ~50s + vài giây giải nén |

### Vừa dùng vừa sửa

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

## 4b. Bản tự cập nhật (full build)

Artifact build (mục 4) dùng phần C++/Rust do Mozilla biên dịch sẵn, nên updater
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
- Mỗi máy build chỉ ra được bản cho hệ điều hành của nó: Mac ra bản macOS, máy Linux
  (`/mnt/ffbuild`) ra bản Linux, máy Windows (MozillaBuild) ra bản Windows. Các máy dùng
  chung khoá và chung server.
- **Windows:** build không kèm Mozilla Maintenance Service, vì dịch vụ này chỉ chạy updater có
  chữ ký của Mozilla (`mozconfig.full`). Giải nén zip vào thư mục user ghi được, vd.
  `%LOCALAPPDATA%\Opz`, thì Opz tự cập nhật mà không cần quyền admin. Đặt trong
  `Program Files` thì mỗi lần cập nhật đều phải có quyền admin. Bản chưa ký Authenticode, nên
  lần đầu mở SmartScreen sẽ cảnh báo (**More info → Run anyway**).

### Phát hành bằng GitHub Actions

`.github/workflows/release.yml` build từ đầu trên máy của GitHub (Ubuntu 24.04, macOS 15
Apple Silicon, Windows Server 2022 với MozillaBuild), rồi chạy `scripts/release.sh` như trên:
ra `.tar.xz` cho Linux, `.dmg` đã ký và notarize cho macOS, `.win64.zip` cho Windows, kèm
file `.mar` đã ký và `update.xml` cho từng hệ điều hành. Windows không có rsync, nên job
`publish-windows` (Ubuntu) đẩy bản Windows lên server bằng `scripts/publish.sh`.

- **Push tag `v*`** (vd. `git tag v159.0.1-2 && git push origin v159.0.1-2`): build cả ba
  và **phát hành luôn**. Mọi máy đã cài sẽ tự cập nhật.
- **Actions → Release → Run workflow**: chọn hệ điều hành; mặc định không phát hành, chỉ
  build. Bộ cài nằm ở mục Artifacts của lần chạy, giữ 14 ngày.
- Mỗi lần là một máy trắng biên dịch lại toàn bộ Firefox, nên mất vài tiếng mỗi hệ điều hành.
  Giới hạn là 6 tiếng mỗi job.

**Cài đặt một lần** (trên Mac đang giữ khoá, `gh` đăng nhập tài khoản có quyền với repo):

```bash
scripts/ci-secrets.sh
```

Script đặt các secret sau, rồi in ra dòng `authorized_keys` cho server và hỏi có thêm luôn qua
`ssh sg-1` không:

| Secret | Từ đâu |
|---|---|
| `MAR_PRIMARY_KEY` | `$FFB_ROOT/keys/mar/primary.key.pem` |
| `MAC_DEVELOPER_ID_P12`, `MAC_DEVELOPER_ID_P12_PASSWORD` | chứng chỉ Developer ID trong Keychain, khoá `$FFB_ROOT/keys/developer-id/`, kèm chứng chỉ trung gian của Apple |
| `APPLE_ID`, `APPLE_APP_PASSWORD` | nhập khi chạy (app-specific password) |
| `DEPLOY_SSH_KEY` | khoá mới `$FFB_ROOT/keys/ci/opz_deploy` |

- Khoá deploy chỉ dùng được cho `rrsync /srv/opz/updates`. Nó không mở shell được và không
  ghi được ra ngoài thư mục đó.
- Secret không được đưa cho workflow chạy từ pull request của fork. Workflow này cũng chỉ
  chạy khi push tag hoặc bấm tay, tức là chỉ người có quyền ghi vào repo mới kích hoạt được.
- Ai giữ được `MAR_PRIMARY_KEY` **và** ghi được lên server thì đẩy được bản cập nhật tới mọi
  máy. Chỉ cấp quyền ghi repo cho người tin cậy.

## 5. Sửa giao diện nhanh

Trong `engine/obj-artifact/dist/bin`, phần lớn file front-end là **symlink** về `engine/`,
nên sửa xong chỉ cần khởi động lại trình duyệt:

| Sửa gì | Cần làm | Thời gian đo |
|---|---|---|
| `.js`/`.mjs`, `.css`, `.ftl` thường (symlink) | khởi động lại trình duyệt | 0s build |
| file tiền xử lý (`browser.xhtml`, `preferences.xhtml`, file có `#ifdef`), file mới, `jar.mn` | `scripts/build.sh faster` | ~6s |
| `mozconfig`, `moz.build`, branding `configure.sh` | `scripts/build.sh` | ~10s |
| `prefs/*` | khởi động lại trình duyệt (đã symlink) | 0s |

Muốn biết một file có phải symlink không: `ls -l engine/obj-artifact/dist/bin/browser/chrome/...`.

## 6. Thêm / sửa patch

1. `scripts/apply.sh` — đưa `engine/` về nhánh `opz` = tag + các patch hiện có.
2. Sửa trong `engine/`, rồi `scripts/build.sh faster` (nếu cần) và `scripts/run.sh` để thử.
3. Commit trên nhánh `opz` trong `engine/`. **Một commit = một patch = một mục đích.**
   Tiêu đề commit sẽ thành tên file patch.

   ```bash
   cd engine && git commit -am "Settings: <mô tả ngắn>" && cd ..
   ```

   Sửa một patch cũ:

   ```bash
   git commit --fixup <commit>
   git rebase -i --autosquash FIREFOX_..._RELEASE
   ```

4. `scripts/export-patches.sh` — ghi lại toàn bộ `patches/` từ nhánh `opz`.
5. Commit `patches/` trong repo này.

Patch hiện có:
- `0001-Settings-show-Opz-logo-...`: thay hình linh vật Firefox (Kit) ở thẻ "Default browser"
  bằng `chrome://branding/content/about-logo.svg`.
- `0002-Help-menu-hide-...`: ẩn hai mục Help trỏ về trang Mozilla.
- `0003-Firefox-View-...`: bỏ nút và các mục menu của Firefox View.
- `0004-Sidebar-...`: ẩn công tắc tab dọc khi sidebar mới bị tắt.
- `0005-Toolbar-...`: bỏ nút "List all tabs" khỏi thanh tab.
- `0006-Sidebar-...`: bật tab dọc mặc định, cột tab không có icon công cụ; với tab ngang thì không có cột bên trái.
- `0007-Theme-...`: thêm theme "Opz" (xám phẳng, không màu nhấn, sáng/tối theo hệ thống).
- `0008-Content-area-...`: vùng nội dung trang bo tròn đủ bốn góc, cách mép cửa sổ một khoảng nhỏ (phía giáp cột tab dọc thì không cách, để icon tab nằm giữa cột).
- `0009-URL-bar-...`: khi không gõ, ô URL chỉ rộng vừa địa chỉ, nằm giữa thanh công cụ, không có nền (bấm vào thì giãn hết chiều rộng, thanh công cụ giữ nguyên chiều cao); bỏ khiên, nút dịch, ngôi sao bookmark.
- `0010-Sidebar-...`: cột tab dọc thu gọn thành icon, rê chuột vào thì mở rộng, rời chuột thì thu lại (mặc định `sidebar.visibility = "expand-on-hover"` cũng đặt trong `prefs/opz.js`, vì giá trị trùng mặc định của Firefox không được lưu vào profile).
- `0011-Toolbar-...`: bỏ nút sidebar và nút New Tab khỏi thanh công cụ; nút sidebar không bị Firefox tự thêm lại vào cuối thanh công cụ (qua pref `sidebar.revamp`) ở lần khởi động sau.
- `0012-URL-bar-...`: đang gõ trong ô URL mà bấm ra chỗ khác thì bỏ chữ đã gõ, hiện lại địa chỉ trang và thu gọn ô URL (trừ khi vừa Enter hoặc chọn một kết quả).
- `0013-Welcome-...`: màn chào mừng toàn cửa sổ lần đầu chạy: import, công cụ tìm kiếm, chặn quảng cáo (cài uBlock Origin), trình duyệt mặc định (xem [Chặn tracker và quảng cáo](#chặn-tracker-và-quảng-cáo)).
- `0014-URL-bar-float-...`: bấm vào ô URL thì nó nổi ra giữa cửa sổ thành một khung (kiểu Zen), kết quả hiện ngay bên dưới, phần còn lại của cửa sổ tối đi; bấm ra ngoài là đóng.
- `0015-Session-restore-...`: nếu trong phiên đã lưu có tab "Sorry. We're having trouble getting your pages back" (bị lưu lại khi trang đó đang mở), khởi động lại sẽ thay tab đó bằng các tab nó đang giữ thay vì hiện lại trang đó. Cùng với `browser.startup.page = 3` và `browser.sessionstore.max_resumed_crashes = -1` trong `prefs/opz.js`, Opz luôn mở lại phiên trước, kể cả sau crash.
- `0016-URL-bar-a-right-click-...`: chuột phải vào ô URL (để Copy/Paste) chỉ mở menu ngữ cảnh, không làm gì khác: ô URL đang nằm trên thanh công cụ thì đứng yên tại chỗ, không nổi ra giữa; đang nổi ra kèm danh sách kết quả thì danh sách vẫn mở dưới menu (Firefox gốc đóng nó, để lại khung trống ở giữa). Paste hay gõ chữ thì ô URL mới nổi ra như bấm chuột trái.
- `0017-Toolbar-...`: nút extension (uBlock...) và nút menu ở bên phải thanh công cụ ẩn đi, chỉ hiện khi rê chuột vào thanh công cụ (hoặc đang focus/mở panel của chúng); vị trí giữ nguyên nên không bị xô lệch.
- `0018-Tabs-...`: tab luôn dọc, không có đường chuyển sang ngang: bỏ mục "Turn off vertical tabs" trong menu chuột phải, công tắc trong Customize sidebar và lựa chọn bố cục trong Settings; Reset toolbar không tắt tab dọc; mỗi lần khởi động profile nào đang ngang cũng được đặt lại thành dọc.
- `0019-Toolbar-...`: bấm phải vào thanh công cụ không còn hiện menu (Menu Bar / Bookmarks Toolbar / Customize Toolbar); riêng nút extension vẫn giữ menu của nó.
- `0020-App-menu-...`: bỏ mục "Customize toolbar" trong menu ☰ > More tools.
- `0021-Sidebar-...`: nút ghim (chỉ có icon) ở đáy cột tab dọc, chỉ hiện khi cột đang mở rộng và đang rê chuột vào cột: bấm để tắt tự thu gọn (`sidebar.visibility = always-show`, nút sáng lên), bấm lại để bật lại tự thu gọn khi rời chuột.
- `0022-New-tab-...`: bấm nút "New Tab" (hoặc Ctrl+T) không tạo tab trống: ô URL mở thành khung nổi ngay trên tab hiện tại; chọn/Enter thì kết quả mở trong một tab mới, Esc hoặc bấm ra ngoài thì không có gì xảy ra.
- `0023-URL-bar-...`: bấm ở bất kỳ đâu ngoài ô URL (kể cả cột tab hay chỗ trống trên thanh công cụ, những nơi không nhận focus) đều đóng khung nổi.
- `0024-URL-bar-...`: khi ô URL đang mở có một lớp trong suốt phủ cả cửa sổ: bấm ra ngoài chỉ đóng ô URL, không bấm xuyên xuống nội dung bên dưới (trước đó phần mờ cho bấm xuyên qua).
- `0025-New-tab-...`: khi bấm New Tab, ô URL ẩn cho tới khi danh sách kết quả sẵn sàng (tối đa 0,4 giây) để ô nhập và danh sách hiện cùng lúc, không bị giật.
- `0026-URL-bar-...`: khung ô URL và danh sách kết quả hiện dần lên (fade 180ms); tắt khi hệ thống bật "giảm chuyển động".
- `0027-URL-bar-...`: khi ô URL chưa dùng, các icon hai bên (thông tin trang/quyền ở trái, nút page action ở phải) ẩn đi, chỉ hiện khi rê chuột vào bất kỳ chỗ nào trên thanh công cụ (kể cả chỗ trống); giữ nguyên chỗ nên không xô lệch.
- `0028-URL-bar-...`: các icon hai bên khung ô URL đang mở bấm được (trước đó bấm vào là khung co lại ngay dưới con trỏ nên mất click); nền phía sau khung (cột tab và nội dung trang, `#browser`) được làm mờ bằng `filter: blur(10px)` thay vì chỉ tối đi.
- `0029-URL-bar-...`: bấm icon hai bên khung ô URL đang mở thì panel của icon mở ra và khung giữ nguyên cho tới khi panel đóng (trước đó panel lấy focus làm khung co lại và panel biến mất ngay).
- `0030-URL-bar-...`: lớp phủ trong suốt phủ cửa sổ khi ô URL mở đã nằm đè lên icon hai bên khung (nên bấm vào chỉ làm khung đóng); đưa lớp phủ xuống dưới các phần tử của thanh công cụ (`z-index: -1`) để icon nhận click, còn chỗ trống vẫn đóng khung.
- `0031-URL-bar-...`: nhấn Esc khi khung ô URL đang mở thì đóng cả khung cùng danh sách kết quả trong một lần nhấn (trước đó Esc chỉ đóng danh sách, khung còn lại thu nhỏ thành một thanh).
- `0034-Tabs-private-tabs-...`: tab riêng tư nằm chung cửa sổ với tab thường. Chuột phải nút New Tab ở cột tab → "New private tab" (ngay dưới "New Tab"): khung ô URL mở như New Tab, kết quả chọn mở trong tab mới thuộc một container ẩn mới (userContextId từ `0x70000000`, không có trong `containers.json`, không hiện trong menu/Settings container). Tab mở ra từ tab riêng tư (link `target=_blank`, popup, duplicate) dùng chung container; menu chuột phải của tab (và của vùng trống cột tab) cũng có "New private tab" ngay dưới "New Tab Below", mở một session riêng tư mới; chuột phải tab riêng tư → "New private tab in this session" mở thêm tab cùng container. Các tab của một session riêng tư luôn nằm liền nhau: tab mới được xếp cạnh session, kéo một tab của session đi thì các tab còn lại đi theo, thả một tab khác vào giữa session thì nó được đặt ra sau session; mỗi tab riêng tư có nền phủ một lớp tối mờ ở giao diện sáng, một lớp pha màu của session ở giao diện tối (tab đang chọn nhẹ hơn ở giao diện sáng, đậm hơn ở giao diện tối để vẫn nổi lên; không có viền màu) và huy hiệu mặt nạ trên icon theo màu của session (6 màu xoay vòng), thấy cả khi cột thu gọn lẫn mở rộng. Không lưu lịch sử (`disableglobalhistory`), không vào session restore / tab đã đóng / cửa sổ đã đóng, không sync, không lưu từ khoá tìm kiếm (ô URL, ô tìm kiếm, ô tìm của trang New Tab), form history, lịch sử download, ảnh thu nhỏ trang. Đóng tab cuối của một container (kể cả khi đóng cửa sổ; chuyển tab sang cửa sổ khác không tính) thì sau 2 giây cookie/storage/cache của container đó bị xoá; id đang có dữ liệu được ghi trong `opz-private-tabs.json` trong profile để xoá lúc khởi động nếu trước đó bị crash. Giới hạn: tiện ích mở rộng (extension) vẫn thấy và chạy trên tab riêng tư như trên tab container thường, kể cả extension không được cấp quyền "Run in Private Windows". Logic nằm trong `browser/modules/OpzPrivateTabs.sys.mjs`.
- `0035-Sidebar-Containers-...`: nút Containers (chỉ có icon hàng rào, tooltip "Manage containers") ở đáy cột tab dọc, nằm bên trái nút ghim của `0021`, cùng kích thước và cùng quy tắc hiện (chỉ khi cột đang mở rộng và đang rê chuột vào cột). Bấm mở một popup cài đặt container ngay bên phải cột tab (bấm lại nút hoặc Escape để đóng), thay cho trang Settings: danh sách container kéo-thả/đổi thứ tự được, nút sửa (form tên/màu/icon ngay trong popup, dùng chung `ContainerEditor`), nút xoá (hỏi xác nhận nếu container đang có tab), "Add new container", và 2 tuỳ chọn "Select a container for each new tab" / "Don’t use containers for links opened from external apps". Chuỗi lấy từ Fluent của trang Settings. Logic nằm trong `browser/components/contextualidentity/content/OpzContainersPanel.mjs`. Trang `about:preferences#containers` và mục "Manage containers" giữ nguyên.
- `0036-Tabs-a-shorter-tab-context-menu-...`: menu chuột phải của tab gọn hơn và có style riêng. Trên cùng là một hàng icon (Reload, Mute/Unmute, Pin/Unpin, Duplicate, Bookmark; tên hiện ở tooltip, icon ghim có màu nhấn khi tab đang ghim). "Select All Tabs" chuyển vào menu con "Move Tab", "Close Duplicate Tabs" vào "Close Multiple Tabs"; mục cấp ngoài đang bị vô hiệu (ví dụ "Reopen Closed Tab" khi chưa đóng tab nào) được ẩn hẳn thay vì làm mờ. Menu và các menu con bo góc 12px, mục cao hơn, highlight khi rê chuột màu nhạt (riêng "Close Tab" màu đỏ). Chuột phải vào vùng trống của cột tab dọc cũng mở menu này cho tab đang chọn (`opzOpenTabMenuOnEmptyArea` trong `sidebar-main.mjs`; tab, nút New Tab và các nút khác giữ menu riêng). Bố cục là descriptor `MENU_SECTIONS.opz` trong `tab-context-menu.js` (luôn dùng, bỏ qua pref `browser.tabs.contextmenu.altstructure.enabled`); CSS ở cuối `browser/themes/shared/contextmenu.css`.
- `0037-Containers-Add-new-container-...`: chọn "Add new container" trong menu con "Open in New Container Tab" của menu chuột phải tab, hoặc trong popup chuột phải nút New Tab ở cột tab, thì sau khi bấm Create trong panel tạo container, tab mở ra ngay trong container mới: từ menu tab là mở lại trang của (các) tab đó trong container mới (như khi chọn một container có sẵn trong menu con), từ nút New Tab là một tab New Tab trong container mới (như các mục container khác của popup). Huỷ hoặc đóng panel thì không mở gì. Callback `opzOnContainerCreated` của `createUserContextMenu` (`utilityOverlay.js`) được chuyển cho `ContainerCreationPanel.open`; `ContainerEditor.commit()` trả về container vừa tạo. "Manage containers", nút Containers của `0035` và trang Settings giữ nguyên.
- `0038-Tabs-New-Container-Tab-...`: menu chuột phải của tab (và của vùng trống cột tab) có menu con "New Container Tab" ngay dưới "New Tab Below" / "New private tab" (/ "New private tab in this session" khi có): liệt kê các container, chọn một container thì mở một tab New Tab mới trong container đó (giống hệt chọn container đó trong popup chuột phải nút New Tab, khác "Open in New Container Tab" là mở lại trang đang xem). Cuối menu con có "Add new container" (tạo xong mở tab mới trong container đó, xem `0037`), không có "Manage containers". Ẩn khi `privacy.userContext.enabled` tắt. Chèn bằng JS sau khi bố cục `MENU_SECTIONS.opz` đã dựng (`TabContextMenu.opzUpdateNewContainerTabMenu` trong `tab-context-menu.js`), dùng lại chuỗi `menu-file-new-container-tab` của `menubar.ftl`.
- `0039-Tabs-container-tabs-get-an-icon-badge-...`: tab thuộc container (không phải tab riêng tư) không còn vạch màu `.tab-context-line` vắt ngang tab trong cột tab dọc; thay vào đó là huy hiệu tròn 11px ở góc dưới phải icon tab, nền màu của container, bên trong là icon của container (cùng kiểu và vị trí với huy hiệu mặt nạ của tab riêng tư ở `0034`). Chỉ CSS, cuối `browser/themes/shared/tabbrowser/tabs.css`, dùng `--identity-icon`/`--identity-icon-color` từ class `identity-icon-*`/`identity-color-*` mà `ContextualIdentityService.setTabStyle` gắn vào tab.
- `0040-Tabs-in-the-expanded-column-the-container-icon-...`: khi cột tab dọc đang mở rộng (ghim hoặc rê chuột), tab container không có huy hiệu trên favicon (của `0039`); icon của container (tô màu container, không có nền tròn) nằm đúng chỗ nút đóng tab ở cuối tab. Rê chuột vào tab thì icon ẩn và nút đóng hiện ở chỗ đó; tab container đang chọn mà không rê chuột cũng hiện icon thay vì nút đóng. Cột thu gọn thì vẫn là huy hiệu trên favicon. Chỉ CSS, cuối `browser/themes/shared/tabbrowser/tabs.css` (`.tab-content::after`).
- `0041-Tabs-Expand-sidebar-on-hover-toggle-...`: cuối menu chuột phải của tab (và của vùng trống cột tab), sau một đường phân cách, có mục có dấu tích "Expand sidebar on hover" (chuỗi có sẵn trong `sidebar.ftl`): có tích là cột tab tự mở rộng khi rê chuột và thu lại khi rời chuột (`sidebar.visibility = expand-on-hover`), bỏ tích là cột luôn mở rộng (`always-show`). Gọi cùng hàm `opzToggleAutoCollapse` với nút ghim của `0021` nên hai chỗ luôn khớp nhau. Chèn bằng JS (`TabContextMenu.opzUpdateAutoExpandItem` trong `tab-context-menu.js`).
- `0042-Tabs-in-the-expanded-column-the-private-icon-also-...`: tab ẩn danh cũng theo quy tắc của `0040`: khi cột tab dọc đang mở rộng, icon mặt nạ (tô màu phiên ẩn danh, không có nền tròn) nằm ở chỗ nút đóng tab thay cho huy hiệu trên favicon; rê chuột vào tab thì nút đóng hiện ở chỗ đó. Cột thu gọn thì vẫn là huy hiệu trên favicon. Chỉ CSS, cùng quy tắc trong `browser/themes/shared/tabbrowser/tabs.css`.
- `0044-URL-bar-typing-searches-bookmarks-first`: gõ vào ô URL thì tự vào chế độ tìm Bookmarks (không hiện chip, thuộc tính `opz-bookmarks-auto` trên `#urlbar` ẩn nó; chọn Bookmarks thủ công ở hàng one-off vẫn có chip), danh sách chỉ hiện bookmark khớp; mũi tên xuống + Enter để mở bookmark. Enter khi chưa chọn kết quả nào thì vẫn mở địa chỉ đã gõ hoặc tìm bằng công cụ tìm kiếm mặc định (Firefox gốc không làm gì trong chế độ này). Xoá hết chữ rồi Backspace thêm một lần để ra khỏi chế độ này (hiện lại mọi kết quả); nó không tự bật lại cho tới khi rời ô URL. Logic trong `_on_input` và `handleNavigation` của `UrlbarInputBase.mjs`.

Các chốt an toàn:
- `apply.sh` từ chối chạy khi `engine/` có thay đổi chưa commit (`--force` để bỏ các thay đổi đó).
- `apply.sh` lưu nhánh `opz` cũ thành `opz-backup-<thời gian>`.
- `export-patches.sh` từ chối khi còn thay đổi chưa commit.
- `fetch.sh --force` từ chối xoá `engine/` nếu nhánh `opz` khác `patches/`.

## 7. Nâng cấp lên bản Firefox mới

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
6. **Chạy [checklist](#10-checklist-kiểm-tra).** Bản mới có thể thêm pref, policy hoặc
   tính năng bloat mới. Hãy tra `browser/components/enterprisepolicies/schemas/policies-schema.json`
   và `browser/app/profile/firefox.js` của bản mới.
7. **Commit** `upstream.env` và `patches/`.

Lần đầu bootstrap trên ổ mới mới cần chạy `bootstrap.sh`; khi nâng cấp chỉ cần chạy lại
nếu `mach build` báo thiếu toolchain.

Artifact build chỉ hoạt động khi CI của Mozilla có bản build cho đúng commit của tag.
Các tag `*_RELEASE` mới thường có sẵn artifact; với bản cũ, CI có thể đã xoá artifact.
Nếu `build.sh` báo không tìm thấy artifact, hãy chọn một tag mới hơn.

## 8. Branding và tên ứng dụng

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

### Theme

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

## 9. Gỡ bloat

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

### Chặn tracker và quảng cáo

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

## 10. Checklist kiểm tra

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
  - Account báo không khả dụng
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
- [ ] **Không đụng tới Firefox:** không có thư mục mới trong `~/.config/mozilla/firefox`.

## 11. Lưu ý

- **Guard dung lượng:** mỗi lần tải/build lớn, script so dung lượng trống của `/`
  trước và sau, và báo lỗi nếu giảm quá 500MB (`OPZ_ROOT_MAX_LOSS_MB`).
- **`fetch.sh`:** kiểm tra toàn vẹn bằng cách băm lại toàn bộ file (`verify-engine.sh`).
  Có thể chạy lại lệnh này bất cứ lúc nào nghi ổ đĩa có vấn đề.
- **Policy hệ thống:** Linux đọc `/etc/firefox/policies/policies.json` trước file của Opz,
  vì tên `firefox` được biên dịch sẵn trong binary. Nếu máy có file đó, nó thắng.
- **Safe Browsing:** build tự dựng không có Google Safe Browsing API key, nên danh sách
  Safe Browsing không được cập nhật.
- **Mạng khi chạy:** bản dev và bản phát hành vẫn kết nối tới các dịch vụ đã giữ lại
  ở mục 9. Ngoài ra còn có `location.services.mozilla.com`, dùng để xác định vùng
  cho công cụ tìm kiếm mặc định.
