const { onDocumentUpdated } = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");

const VN_OFFSET_MS = 7 * 60 * 60 * 1000;
const DAY_MS = 24 * 60 * 60 * 1000;

const TRANG_THAI_PHONG = { TAM_DUNG: 12, DANG_KHAM: 13, DONG_CUA: 14 };

// Lịch hẹn chưa khám: 1 chờ duyệt, 2 đã xác nhận, 7 đến trễ (5 hoàn thành, 3/4 đã hủy, 6 vắng mặt thì không gửi)
const TRANG_THAI_LICH_CHUA_KHAM = [1, 2, 7];

/**
 * getTodayRangeVN: trả về khoảng [00:00, 24:00) của hôm nay theo giờ Việt Nam dưới dạng Date UTC.
 */
function getTodayRangeVN() {
  const vnNow = new Date(Date.now() + VN_OFFSET_MS);
  const startAsUTC = Date.UTC(
    vnNow.getUTCFullYear(),
    vnNow.getUTCMonth(),
    vnNow.getUTCDate(),
    0, 0, 0, 0
  );
  const start = new Date(startAsUTC - VN_OFFSET_MS);
  const end = new Date(start.getTime() + DAY_MS);
  return { start, end };
}

/**
 * taoNoiDungThongBao: tạo loại, tiêu đề và nội dung thông báo theo trạng thái mới của phòng khám.
 */
function taoNoiDungThongBao(trangThaiMoi, tenPhong, tenKhoa, tenBenhVien) {
  const noiKham = `${tenPhong} (${tenKhoa}) - ${tenBenhVien}`;

  if (trangThaiMoi === TRANG_THAI_PHONG.TAM_DUNG) {
    return {
      loaiThongBao: "phong_kham_tam_dung",
      tieuDe: "Phòng khám đang tạm dừng",
      noiDung: `${noiKham} đang tạm dừng. Giờ dự kiến đến lượt của bạn sẽ được cộng thêm thời gian tạm dừng.`,
    };
  }
  if (trangThaiMoi === TRANG_THAI_PHONG.DONG_CUA) {
    return {
      loaiThongBao: "phong_kham_dong_cua",
      tieuDe: "Phòng khám đã đóng cửa",
      noiDung: `${noiKham} đã đóng cửa. Vui lòng liên hệ quầy tiếp đón để được hỗ trợ hoặc đặt lại lịch khám.`,
    };
  }
  if (trangThaiMoi === TRANG_THAI_PHONG.DANG_KHAM) {
    return {
      loaiThongBao: "phong_kham_tiep_tuc",
      tieuDe: "Phòng khám đã tiếp tục khám",
      noiDung: `${noiKham} đã tiếp tục khám. Bạn vui lòng theo dõi số thứ tự và có mặt khi đến lượt.`,
    };
  }
  return null;
}

/**
 * guiPush: gửi thông báo đẩy cho một bệnh nhân nếu bệnh nhân có FCM token.
 */
async function guiPush(db, benhNhanId, tieuDe, noiDung, lichHenId) {
  const userDoc = await db.collection("BenhNhan").doc(benhNhanId).get();
  const fcmToken = userDoc.data()?.fcm_token;
  if (!fcmToken) return;

  await admin.messaging().send({
    notification: { title: tieuDe, body: noiDung },
    data: {
      type: "PHONG_KHAM_STATUS",
      screen: "appointment_tracking",
      lichHenId: lichHenId,
    },
    token: fcmToken,
    android: {
      priority: "high",
      notification: { sound: "default", channelId: "lich_hen_channel" },
    },
    apns: { payload: { aps: { sound: "default" } } },
  });
}

/**
 * onPhongKhamStatusChanged: khi trạng thái phòng khám đổi (12 tạm dừng, 13 đang khám, 14 đóng cửa),
 * gửi thông báo cho các bệnh nhân có lịch khám hôm nay tại phòng đó và chưa khám xong.
 */
exports.onPhongKhamStatusChanged = onDocumentUpdated(
  "PhongKham/{phongKhamId}",
  async (event) => {
    const phongKhamId = event.params.phongKhamId;
    const before = Number(event.data.before.data().trang_thai_id);
    const afterData = event.data.after.data();
    const after = Number(afterData.trang_thai_id);

    // Bước 1: bỏ qua nếu trạng thái không đổi.
    if (before === after) return null;

    // Bước 2: chỉ báo "tiếp tục khám" khi phòng quay lại từ tạm dừng hoặc đóng cửa (đang khám ban đầu thì không gửi gì).
    const quayLaiKham =
      before === TRANG_THAI_PHONG.TAM_DUNG ||
      before === TRANG_THAI_PHONG.DONG_CUA;
    if (after === TRANG_THAI_PHONG.DANG_KHAM && !quayLaiKham) return null;
    if (!Object.values(TRANG_THAI_PHONG).includes(after)) return null;

    try {
      const db = admin.firestore();

      // Bước 3: lấy các lịch hẹn hôm nay (theo giờ Việt Nam) rồi lọc đúng phòng và trạng thái chưa khám.
      const { start, end } = getTodayRangeVN();
      const snapshot = await db
        .collection("LichHen")
        .where("ngay_dat", ">=", admin.firestore.Timestamp.fromDate(start))
        .where("ngay_dat", "<", admin.firestore.Timestamp.fromDate(end))
        .get();

      const lichHenCanBao = snapshot.docs.filter((doc) => {
        const d = doc.data();
        return (
          d.phong_kham_id === phongKhamId &&
          d.benh_nhan_id &&
          TRANG_THAI_LICH_CHUA_KHAM.includes(Number(d.trang_thai_id))
        );
      });

      console.log(
        `Phòng ${phongKhamId}: ${before} -> ${after}, báo cho ${lichHenCanBao.length} lịch hẹn.`
      );
      if (lichHenCanBao.length === 0) return null;

      // Bước 4: ghi thông báo vào tab Thông báo và gửi thông báo đẩy (mỗi bệnh nhân chỉ nhận một thông báo đẩy).
      const daGuiPush = new Set();

      for (const doc of lichHenCanBao) {
        const data = doc.data();
        const benhNhanId = data.benh_nhan_id;

        const tenPhong =
          afterData.ten_phong ||
          afterData.tenPhong ||
          data.ten_phong_kham ||
          "Phòng khám";
        const tenKhoa = data.ten_khoa || afterData.ten_khoa_goc || "Khoa";
        const tenBenhVien = data.ten_benh_vien || "Bệnh viện";

        const noiDungTB = taoNoiDungThongBao(after, tenPhong, tenKhoa, tenBenhVien);
        if (!noiDungTB) continue;
        const { loaiThongBao, tieuDe, noiDung } = noiDungTB;

        const thongBaoId = `TB_${loaiThongBao}_${doc.id}_${Date.now()}`;

        try {
          await db
            .collection("ThongBao")
            .doc(benhNhanId)
            .collection("danh_sach")
            .doc(thongBaoId)
            .set({
              thong_bao_id: thongBaoId,
              benh_nhan_id: benhNhanId,
              loai_thong_bao: loaiThongBao,
              tieu_de: tieuDe,
              noi_dung: noiDung,
              lich_hen_id: doc.id,
              benh_vien_id: data.benh_vien_id || null,
              khoa_id: data.khoa_id || null,
              phong_kham_id: phongKhamId,
              ten_benh_vien: tenBenhVien,
              ten_khoa: tenKhoa,
              ngay_tao: admin.firestore.FieldValue.serverTimestamp(),
              da_doc: false,
            });

          if (!daGuiPush.has(benhNhanId)) {
            daGuiPush.add(benhNhanId);
            await guiPush(db, benhNhanId, tieuDe, noiDung, doc.id);
          }
        } catch (error) {
          console.error(`Lỗi gửi thông báo phòng khám cho lịch ${doc.id}:`, error);
        }
      }
    } catch (error) {
      console.error("Lỗi trong onPhongKhamStatusChanged:", error);
    }

    return null;
  }
);