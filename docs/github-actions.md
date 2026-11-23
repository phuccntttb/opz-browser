# Phát hành bằng GitHub Actions

`.github/workflows/release.yml` build từ đầu trên máy của GitHub, rồi chạy
`scripts/release.sh` (xem [Bản tự cập nhật](self-update.md)): ra `.tar.xz` cho Linux, `.dmg` đã ký và notarize cho macOS,
`.win64.zip` cho Windows, kèm file `.mar` đã ký và `update.xml` cho từng hệ điều hành. Linux
và Windows build trên Ubuntu 24.04 (Windows build chéo, `OPZ_TARGET=win`), macOS build trên
macOS 26 Apple Silicon (runner `macos-26`, Xcode mới nhất có sẵn) vì phải ký và notarize trên Mac.

- **Push tag `v*`** (vd. `git tag v159.0.1-2 && git push origin v159.0.1-2`): build cả ba
  và **phát hành luôn**. Mọi máy đã cài sẽ tự cập nhật.
- **Actions → Release → Run workflow**: chọn hệ điều hành; mặc định không phát hành, chỉ
  build. Bộ cài nằm ở mục Artifacts của lần chạy, giữ 14 ngày.
- Lần đầu biên dịch toàn bộ Firefox, mất vài tiếng mỗi hệ điều hành; giới hạn là 6 tiếng mỗi
  job. Kết quả biên dịch (sccache) được giữ trong cache của Actions, kể cả khi build lỗi hay
  hết giờ (bước Build tự dừng ở phút 320), nên các lần sau chỉ biên dịch lại phần thay đổi.

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

[← Mục lục](../README.md)
