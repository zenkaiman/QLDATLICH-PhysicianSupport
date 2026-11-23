# -*- coding: utf-8 -*-
"""
Công cụ đồng bộ và khởi tạo Firebase cho Quản trị viên (QLDATLICH-Admin)
Sử dụng khóa dịch vụ Firebase Admin SDK
"""
import sys
import os
import firebase_admin
from firebase_admin import credentials, firestore

sys.stdout.reconfigure(encoding='utf-8')

KEY_PATH = os.path.join(os.path.dirname(__file__), "firebase-adminsdk.json")

if not os.path.exists(KEY_PATH):
    # Thử đường dẫn gốc
    KEY_PATH = r"g:\datlichkham-37558-firebase-adminsdk-fbsvc-86c35dd975.json"

if not os.path.exists(KEY_PATH):
    print(f"❌ Không tìm thấy file khóa Firebase Admin SDK: {KEY_PATH}")
    sys.exit(1)

print(f"🔑 Đang kết nối Firebase qua Service Account: {KEY_PATH}")
cred = credentials.Certificate(KEY_PATH)
try:
    firebase_admin.initialize_app(cred)
except ValueError:
    pass

db = firestore.client()

def seed_sample_bug_reports():
    print("⏳ Kiểm tra và tạo dữ liệu báo cáo lỗi (BaoCaoLoi)...")
    sample_reports = [
        {
            "id": "qr_001",
            "tieu_de": "Quét QR không auto điền form tiếp nhận",
            "loai": "qr",
            "noi_dung": "Camera quét mã của bệnh nhân Nguyễn Văn A báo mã hợp lệ nhưng không tự load thông tin khám tiếp nhận tại quầy.",
            "nguoi_gui": "BV Đa Khoa Tâm Anh (Quầy tiếp đón)",
            "thoi_gian_hien_thi": "10 phút trước",
            "trang_thai_xu_ly": "CHO_XU_LY",
            "da_doc": False,
            "ngay_tao": firestore.SERVER_TIMESTAMP,
        },
        {
            "id": "booking_002",
            "tieu_de": "Trùng ca khám buổi sáng Khoa Tim Mạch",
            "loai": "booking",
            "noi_dung": "Hệ thống ghi nhận 2 bệnh nhân trùng số thứ tự 05 vào lúc 08:30 sáng nay tại phòng khám 102.",
            "nguoi_gui": "Bệnh nhân Trần Mai Lan",
            "thoi_gian_hien_thi": "1 giờ trước",
            "trang_thai_xu_ly": "CHO_XU_LY",
            "da_doc": False,
            "ngay_tao": firestore.SERVER_TIMESTAMP,
        },
        {
            "id": "qr_003",
            "tieu_de": "Mã QR Check-in quá hạn không tự hủy",
            "loai": "qr",
            "noi_dung": "Bệnh nhân quét mã lịch khám của ngày hôm qua nhưng ứng dụng vẫn báo check-in thành công.",
            "nguoi_gui": "Lễ tân Bệnh viện Bạch Mai",
            "thoi_gian_hien_thi": "3 giờ trước",
            "trang_thai_xu_ly": "CHO_XU_LY",
            "da_doc": False,
            "ngay_tao": firestore.SERVER_TIMESTAMP,
        },
        {
            "id": "booking_004",
            "tieu_de": "Lỗi hủy lịch không hoàn lại ca khám",
            "loai": "booking",
            "noi_dung": "Bệnh nhân đã hủy lịch trước 24h nhưng hệ thống phòng khám vẫn khóa slot và không mở lại cho bệnh nhân khác.",
            "nguoi_gui": "Bệnh nhân Lê Quốc Bảo",
            "thoi_gian_hien_thi": "Hôm qua",
            "trang_thai_xu_ly": "CHO_XU_LY",
            "da_doc": False,
            "ngay_tao": firestore.SERVER_TIMESTAMP,
        }
    ]

    for rep in sample_reports:
        doc_ref = db.collection('BaoCaoLoi').document(rep['id'])
        doc_ref.set(rep, merge=True)
    print("✅ Đã đồng bộ 4 báo cáo lỗi mẫu vào collection BaoCaoLoi!")

def check_hospitals():
    print("⏳ Kiểm tra danh sách Bệnh viện...")
    bvs = list(db.collection('BenhVien').limit(5).stream())
    print(f"✅ Đã tìm thấy các bệnh viện trong hệ thống (Mẫu: {[b.id for b in bvs]})")

def check_requests():
    print("⏳ Kiểm tra hồ sơ duyệt YeuCauHopTac...")
    ycs = list(db.collection('YeuCauHopTac').stream())
    print(f"✅ Tìm thấy {len(ycs)} yêu cầu hợp tác chờ duyệt hoặc đã xử lý.")

if __name__ == "__main__":
    print("=== BẮT ĐẦU ĐỒNG BỘ DỮ LIỆU FIREBASE ADMIN ===")
    seed_sample_bug_reports()
    check_hospitals()
    check_requests()
    print("=== HOÀN TẤT THÀNH CÔNG ===")
