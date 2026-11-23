# Dựng môi trường build trên ổ mới

Áp dụng khi làm trên ổ ngoài hoặc máy khác. Mọi thứ nằm trên **một phân vùng ext4 mount
ở `/mnt/ffbuild`**, ổ hệ thống gần như không bị ghi gì.

## Yêu cầu
- **Máy:** Linux x86_64, có mạng (để tải source, toolchain và artifact).
- **Dung lượng:** cần khoảng **10 GB**, nên để từ 20 GB trở lên.
  - Source và git: 4.9 GB
  - Objdir: 1.2 GB
  - Toolchain: 1.6 GB
  - Tarball và tmp: khoảng 1 GB
- **Định dạng phân vùng: ext4.** **Không** dùng NTFS/exFAT hay file image đặt trên
  NTFS (FUSE). Đã từng gặp lỗi hỏng file âm thầm với cách này.

## Gói hệ thống (tự chạy, cần root)
Artifact build không cần thêm gói nào ngoài những thứ thường có sẵn:

```bash
sudo apt install --no-install-recommends git curl python3 unzip make perl xz-utils
```

`mach bootstrap` được gọi với `--no-system-changes`, nên **không** chạy apt/sudo.

## Phân vùng và mount (tự chạy, cần root)
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

## Lấy repo và build lần đầu

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

## macOS (Apple Silicon, ổ ngoài)

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

## Windows

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
- `package.sh` chỉ dành cho Linux. Bản phát hành Windows do `release.sh` đóng gói (xem [Bản tự cập nhật](self-update.md)).

[← Mục lục](../README.md)
