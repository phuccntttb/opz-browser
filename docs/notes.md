# Lưu ý

- **Guard dung lượng:** mỗi lần tải/build lớn, script so dung lượng trống của `/`
  trước và sau, và báo lỗi nếu giảm quá 500MB (`OPZ_ROOT_MAX_LOSS_MB`).
- **`fetch.sh`:** kiểm tra toàn vẹn bằng cách băm lại toàn bộ file (`verify-engine.sh`).
  Có thể chạy lại lệnh này bất cứ lúc nào nghi ổ đĩa có vấn đề.
- **Policy hệ thống:** Linux đọc `/etc/firefox/policies/policies.json` trước file của Opz,
  vì tên `firefox` được biên dịch sẵn trong binary. Nếu máy có file đó, nó thắng.
- **Safe Browsing:** build tự dựng không có Google Safe Browsing API key, nên danh sách
  Safe Browsing không được cập nhật.
- **Mạng khi chạy:** bản dev và bản phát hành vẫn kết nối tới các dịch vụ đã giữ lại
  ở [Gỡ bloat](debloat.md). Ngoài ra còn có `location.services.mozilla.com`, dùng để xác định vùng
  cho công cụ tìm kiếm mặc định.

[← Mục lục](../README.md)
