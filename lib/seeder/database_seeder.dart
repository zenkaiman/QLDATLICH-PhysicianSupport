import 'package:cloud_firestore/cloud_firestore.dart';

class DatabaseSeeder {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ==========================================
  // 1. DANH SÁCH 7 NHÓM CHUYÊN KHOA
  // ==========================================
  static final List<Map<String, dynamic>> _specialtyGroups = [
    {'ma_nhom': 'N01', 'ten_nhom': 'Nội khoa', 'ten_tieng_anh': 'Internal Medicine', 'mo_ta': 'Chẩn đoán và điều trị các bệnh lý nội tạng', 'icon': 'stethoscope', 'mau_sac': '#3B82F6', 'thu_tu': 1, 'da_xoa': false},
    {'ma_nhom': 'N02', 'ten_nhom': 'Ngoại khoa', 'ten_tieng_anh': 'Surgery', 'mo_ta': 'Điều trị các bệnh lý bằng phương pháp phẫu thuật', 'icon': 'medical_services', 'mau_sac': '#10B981', 'thu_tu': 2, 'da_xoa': false},
    {'ma_nhom': 'N03', 'ten_nhom': 'Sản phụ khoa', 'ten_tieng_anh': 'Obstetrics & Gynecology', 'mo_ta': 'Chăm sóc sức khỏe sinh sản, thai sản', 'icon': 'pregnant_woman', 'mau_sac': '#EC4899', 'thu_tu': 3, 'da_xoa': false},
    {'ma_nhom': 'N04', 'ten_nhom': 'Nhi khoa', 'ten_tieng_anh': 'Pediatrics', 'mo_ta': 'Chăm sóc và điều trị bệnh lý cho trẻ em', 'icon': 'child_care', 'mau_sac': '#FBBF24', 'thu_tu': 4, 'da_xoa': false},
    {'ma_nhom': 'N05', 'ten_nhom': 'Chuyên khoa lẻ', 'ten_tieng_anh': 'Other Specialties', 'mo_ta': 'Mắt, Tai Mũi Họng, Da liễu, Răng Hàm Mặt...', 'icon': 'category', 'mau_sac': '#8B5CF6', 'thu_tu': 5, 'da_xoa': false},
    {'ma_nhom': 'N06', 'ten_nhom': 'Y học cổ truyền', 'ten_tieng_anh': 'Traditional Medicine', 'mo_ta': 'Điều trị bằng Đông y, châm cứu, bấm huyệt', 'icon': 'spa', 'mau_sac': '#059669', 'thu_tu': 6, 'da_xoa': false},
    {'ma_nhom': 'N07', 'ten_nhom': 'Cận lâm sàng', 'ten_tieng_anh': 'Paraclinical Services', 'mo_ta': 'Xét nghiệm, Chẩn đoán hình ảnh', 'icon': 'biotech', 'mau_sac': '#64748B', 'thu_tu': 7, 'da_xoa': false},
  ];

  // ==========================================
  // 2. DANH SÁCH ĐẦY ĐỦ 40 CHUYÊN KHOA
  // ==========================================
  static final List<Map<String, dynamic>> _specialties = [
    // ===== NỘI KHOA (N01) =====
    {'ma_chuyen_khoa': 'CK001', 'ten_chuyen_khoa': 'Tim mạch', 'ten_tieng_anh': 'Cardiology', 'nhom_chuyen_khoa_id': 'N01', 'ten_nhom': 'Nội khoa', 'mo_ta': 'Chẩn đoán và điều trị các bệnh lý về tim và mạch máu', 'icon': 'favorite', 'mau_sac': '#EF4444', 'pho_bien': true, 'thu_tu': 1, 'da_xoa': false},
    {'ma_chuyen_khoa': 'CK002', 'ten_chuyen_khoa': 'Tiêu hóa', 'ten_tieng_anh': 'Gastroenterology', 'nhom_chuyen_khoa_id': 'N01', 'ten_nhom': 'Nội khoa', 'mo_ta': 'Chuyên về các bệnh lý dạ dày, ruột, gan, mật', 'icon': 'biotech', 'mau_sac': '#F59E0B', 'pho_bien': true, 'thu_tu': 2, 'da_xoa': false},
    {'ma_chuyen_khoa': 'CK003', 'ten_chuyen_khoa': 'Hô hấp', 'ten_tieng_anh': 'Pulmonology', 'nhom_chuyen_khoa_id': 'N01', 'ten_nhom': 'Nội khoa', 'mo_ta': 'Điều trị các bệnh về phổi và đường hô hấp', 'icon': 'air', 'mau_sac': '#3B82F6', 'pho_bien': true, 'thu_tu': 3, 'da_xoa': false},
    {'ma_chuyen_khoa': 'CK004', 'ten_chuyen_khoa': 'Thận - Tiết niệu', 'ten_tieng_anh': 'Nephrology & Urology', 'nhom_chuyen_khoa_id': 'N01', 'ten_nhom': 'Nội khoa', 'mo_ta': 'Chuyên khoa về thận, bàng quang và hệ tiết niệu', 'icon': 'water_drop', 'mau_sac': '#06B6D4', 'pho_bien': false, 'thu_tu': 4, 'da_xoa': false},
    {'ma_chuyen_khoa': 'CK005', 'ten_chuyen_khoa': 'Nội tiết', 'ten_tieng_anh': 'Endocrinology', 'nhom_chuyen_khoa_id': 'N01', 'ten_nhom': 'Nội khoa', 'mo_ta': 'Điều trị tiểu đường, tuyến giáp và các bệnh nội tiết', 'icon': 'science', 'mau_sac': '#8B5CF6', 'pho_bien': true, 'thu_tu': 5, 'da_xoa': false},
    {'ma_chuyen_khoa': 'CK006', 'ten_chuyen_khoa': 'Thần kinh', 'ten_tieng_anh': 'Neurology', 'nhom_chuyen_khoa_id': 'N01', 'ten_nhom': 'Nội khoa', 'mo_ta': 'Chẩn đoán và điều trị các bệnh về não, tủy sống, thần kinh', 'icon': 'psychology', 'mau_sac': '#A855F7', 'pho_bien': true, 'thu_tu': 6, 'da_xoa': false},
    {'ma_chuyen_khoa': 'CK007', 'ten_chuyen_khoa': 'Cơ xương khớp', 'ten_tieng_anh': 'Rheumatology', 'nhom_chuyen_khoa_id': 'N01', 'ten_nhom': 'Nội khoa', 'mo_ta': 'Điều trị viêm khớp, loãng xương và bệnh tự miễn', 'icon': 'accessibility', 'mau_sac': '#EC4899', 'pho_bien': true, 'thu_tu': 7, 'da_xoa': false},
    {'ma_chuyen_khoa': 'CK008', 'ten_chuyen_khoa': 'Huyết học', 'ten_tieng_anh': 'Hematology', 'nhom_chuyen_khoa_id': 'N01', 'ten_nhom': 'Nội khoa', 'mo_ta': 'Chuyên về các bệnh lý về máu', 'icon': 'bloodtype', 'mau_sac': '#DC2626', 'pho_bien': false, 'thu_tu': 8, 'da_xoa': false},
    {'ma_chuyen_khoa': 'CK009', 'ten_chuyen_khoa': 'Truyền nhiễm', 'ten_tieng_anh': 'Infectious Diseases', 'nhom_chuyen_khoa_id': 'N01', 'ten_nhom': 'Nội khoa', 'mo_ta': 'Điều trị các bệnh truyền nhiễm, viêm gan, HIV', 'icon': 'coronavirus', 'mau_sac': '#B91C1C', 'pho_bien': false, 'thu_tu': 9, 'da_xoa': false},
    {'ma_chuyen_khoa': 'CK010', 'ten_chuyen_khoa': 'Dị ứng - Miễn dịch', 'ten_tieng_anh': 'Allergy & Immunology', 'nhom_chuyen_khoa_id': 'N01', 'ten_nhom': 'Nội khoa', 'mo_ta': 'Chuyên về dị ứng và các bệnh tự miễn', 'icon': 'vaccines', 'mau_sac': '#F97316', 'pho_bien': false, 'thu_tu': 10, 'da_xoa': false},
    {'ma_chuyen_khoa': 'CK011', 'ten_chuyen_khoa': 'Lão khoa', 'ten_tieng_anh': 'Geriatrics', 'nhom_chuyen_khoa_id': 'N01', 'ten_nhom': 'Nội khoa', 'mo_ta': 'Chăm sóc sức khỏe người cao tuổi', 'icon': 'elderly', 'mau_sac': '#78716C', 'pho_bien': false, 'thu_tu': 11, 'da_xoa': false},

    // ===== NGOẠI KHOA (N02) =====
    {'ma_chuyen_khoa': 'CK012', 'ten_chuyen_khoa': 'Ngoại tổng quát', 'ten_tieng_anh': 'General Surgery', 'nhom_chuyen_khoa_id': 'N02', 'ten_nhom': 'Ngoại khoa', 'mo_ta': 'Phẫu thuật các bệnh lý ổ bụng, tuyến giáp, vú', 'icon': 'medical_services', 'mau_sac': '#10B981', 'pho_bien': true, 'thu_tu': 12, 'da_xoa': false},
    {'ma_chuyen_khoa': 'CK013', 'ten_chuyen_khoa': 'Chấn thương chỉnh hình', 'ten_tieng_anh': 'Orthopedics', 'nhom_chuyen_khoa_id': 'N02', 'ten_nhom': 'Ngoại khoa', 'mo_ta': 'Điều trị gãy xương, thoái hóa khớp, cột sống', 'icon': 'sports_kabaddi', 'mau_sac': '#059669', 'pho_bien': true, 'thu_tu': 13, 'da_xoa': false},
    {'ma_chuyen_khoa': 'CK014', 'ten_chuyen_khoa': 'Thần kinh cột sống', 'ten_tieng_anh': 'Neurosurgery', 'nhom_chuyen_khoa_id': 'N02', 'ten_nhom': 'Ngoại khoa', 'mo_ta': 'Phẫu thuật não, tủy sống và cột sống', 'icon': 'neurology', 'mau_sac': '#7C3AED', 'pho_bien': false, 'thu_tu': 14, 'da_xoa': false},
    {'ma_chuyen_khoa': 'CK015', 'ten_chuyen_khoa': 'Tiết niệu', 'ten_tieng_anh': 'Urology', 'nhom_chuyen_khoa_id': 'N02', 'ten_nhom': 'Ngoại khoa', 'mo_ta': 'Phẫu thuật hệ tiết niệu và sinh dục nam', 'icon': 'urology', 'mau_sac': '#0891B2', 'pho_bien': false, 'thu_tu': 15, 'da_xoa': false},
    {'ma_chuyen_khoa': 'CK016', 'ten_chuyen_khoa': 'Lồng ngực - Mạch máu', 'ten_tieng_anh': 'Cardiothoracic Surgery', 'nhom_chuyen_khoa_id': 'N02', 'ten_nhom': 'Ngoại khoa', 'mo_ta': 'Phẫu thuật tim, phổi và mạch máu', 'icon': 'cardiology', 'mau_sac': '#E11D48', 'pho_bien': false, 'thu_tu': 16, 'da_xoa': false},
    {'ma_chuyen_khoa': 'CK017', 'ten_chuyen_khoa': 'Tạo hình - Thẩm mỹ', 'ten_tieng_anh': 'Plastic Surgery', 'nhom_chuyen_khoa_id': 'N02', 'ten_nhom': 'Ngoại khoa', 'mo_ta': 'Phẫu thuật tạo hình và thẩm mỹ', 'icon': 'face', 'mau_sac': '#DB2777', 'pho_bien': false, 'thu_tu': 17, 'da_xoa': false},
    {'ma_chuyen_khoa': 'CK018', 'ten_chuyen_khoa': 'Gây mê hồi sức', 'ten_tieng_anh': 'Anesthesiology', 'nhom_chuyen_khoa_id': 'N02', 'ten_nhom': 'Ngoại khoa', 'mo_ta': 'Gây mê và hồi sức sau phẫu thuật', 'icon': 'bedtime', 'mau_sac': '#6366F1', 'pho_bien': false, 'thu_tu': 18, 'da_xoa': false},

    // ===== SẢN PHỤ KHOA (N03) =====
    {'ma_chuyen_khoa': 'CK019', 'ten_chuyen_khoa': 'Sản khoa', 'ten_tieng_anh': 'Obstetrics', 'nhom_chuyen_khoa_id': 'N03', 'ten_nhom': 'Sản phụ khoa', 'mo_ta': 'Chăm sóc thai sản và sinh nở', 'icon': 'pregnant_woman', 'mau_sac': '#EC4899', 'pho_bien': true, 'thu_tu': 19, 'da_xoa': false},
    {'ma_chuyen_khoa': 'CK020', 'ten_chuyen_khoa': 'Phụ khoa', 'ten_tieng_anh': 'Gynecology', 'nhom_chuyen_khoa_id': 'N03', 'ten_nhom': 'Sản phụ khoa', 'mo_ta': 'Điều trị các bệnh lý phụ khoa', 'icon': 'female', 'mau_sac': '#F472B6', 'pho_bien': true, 'thu_tu': 20, 'da_xoa': false},
    {'ma_chuyen_khoa': 'CK021', 'ten_chuyen_khoa': 'Kế hoạch hóa gia đình', 'ten_tieng_anh': 'Family Planning', 'nhom_chuyen_khoa_id': 'N03', 'ten_nhom': 'Sản phụ khoa', 'mo_ta': 'Tư vấn và thực hiện các biện pháp kế hoạch hóa gia đình', 'icon': 'family_restroom', 'mau_sac': '#F9A8D4', 'pho_bien': false, 'thu_tu': 21, 'da_xoa': false},

    // ===== NHI KHOA (N04) =====
    {'ma_chuyen_khoa': 'CK022', 'ten_chuyen_khoa': 'Nhi khoa', 'ten_tieng_anh': 'Pediatrics', 'nhom_chuyen_khoa_id': 'N04', 'ten_nhom': 'Nhi khoa', 'mo_ta': 'Khám và điều trị bệnh cho trẻ em', 'icon': 'child_care', 'mau_sac': '#FBBF24', 'pho_bien': true, 'thu_tu': 22, 'da_xoa': false},
    {'ma_chuyen_khoa': 'CK023', 'ten_chuyen_khoa': 'Sơ sinh', 'ten_tieng_anh': 'Neonatology', 'nhom_chuyen_khoa_id': 'N04', 'ten_nhom': 'Nhi khoa', 'mo_ta': 'Chăm sóc đặc biệt cho trẻ sơ sinh', 'icon': 'baby_changing_station', 'mau_sac': '#FCD34D', 'pho_bien': false, 'thu_tu': 23, 'da_xoa': false},

    // ===== CHUYÊN KHOA LẺ (N05) =====
    {'ma_chuyen_khoa': 'CK024', 'ten_chuyen_khoa': 'Da liễu', 'ten_tieng_anh': 'Dermatology', 'nhom_chuyen_khoa_id': 'N05', 'ten_nhom': 'Chuyên khoa lẻ', 'mo_ta': 'Điều trị các bệnh về da, tóc, móng', 'icon': 'coronavirus', 'mau_sac': '#F59E0B', 'pho_bien': true, 'thu_tu': 24, 'da_xoa': false},
    {'ma_chuyen_khoa': 'CK025', 'ten_chuyen_khoa': 'Mắt', 'ten_tieng_anh': 'Ophthalmology', 'nhom_chuyen_khoa_id': 'N05', 'ten_nhom': 'Chuyên khoa lẻ', 'mo_ta': 'Khám và điều trị các bệnh về mắt', 'icon': 'visibility', 'mau_sac': '#3B82F6', 'pho_bien': true, 'thu_tu': 25, 'da_xoa': false},
    {'ma_chuyen_khoa': 'CK026', 'ten_chuyen_khoa': 'Tai Mũi Họng', 'ten_tieng_anh': 'ENT', 'nhom_chuyen_khoa_id': 'N05', 'ten_nhom': 'Chuyên khoa lẻ', 'mo_ta': 'Điều trị các bệnh về tai, mũi, họng', 'icon': 'hearing', 'mau_sac': '#8B5CF6', 'pho_bien': true, 'thu_tu': 26, 'da_xoa': false},
    {'ma_chuyen_khoa': 'CK027', 'ten_chuyen_khoa': 'Răng Hàm Mặt', 'ten_tieng_anh': 'Dentistry', 'nhom_chuyen_khoa_id': 'N05', 'ten_nhom': 'Chuyên khoa lẻ', 'mo_ta': 'Nha khoa và phẫu thuật hàm mặt', 'icon': 'dentistry', 'mau_sac': '#14B8A6', 'pho_bien': true, 'thu_tu': 27, 'da_xoa': false},
    {'ma_chuyen_khoa': 'CK028', 'ten_chuyen_khoa': 'Tâm thần', 'ten_tieng_anh': 'Psychiatry', 'nhom_chuyen_khoa_id': 'N05', 'ten_nhom': 'Chuyên khoa lẻ', 'mo_ta': 'Điều trị các rối loạn tâm thần và tâm lý', 'icon': 'psychology_alt', 'mau_sac': '#6366F1', 'pho_bien': false, 'thu_tu': 28, 'da_xoa': false},
    {'ma_chuyen_khoa': 'CK029', 'ten_chuyen_khoa': 'Phục hồi chức năng', 'ten_tieng_anh': 'Rehabilitation', 'nhom_chuyen_khoa_id': 'N05', 'ten_nhom': 'Chuyên khoa lẻ', 'mo_ta': 'Vật lý trị liệu và phục hồi chức năng', 'icon': 'fitness_center', 'mau_sac': '#10B981', 'pho_bien': false, 'thu_tu': 29, 'da_xoa': false},
    {'ma_chuyen_khoa': 'CK030', 'ten_chuyen_khoa': 'Ung bướu', 'ten_tieng_anh': 'Oncology', 'nhom_chuyen_khoa_id': 'N05', 'ten_nhom': 'Chuyên khoa lẻ', 'mo_ta': 'Chẩn đoán và điều trị ung thư', 'icon': 'cancer', 'mau_sac': '#7C2D12', 'pho_bien': false, 'thu_tu': 30, 'da_xoa': false},
    {'ma_chuyen_khoa': 'CK031', 'ten_chuyen_khoa': 'Nam học', 'ten_tieng_anh': 'Andrology', 'nhom_chuyen_khoa_id': 'N05', 'ten_nhom': 'Chuyên khoa lẻ', 'mo_ta': 'Điều trị các bệnh lý về sinh lý nam', 'icon': 'male', 'mau_sac': '#2563EB', 'pho_bien': false, 'thu_tu': 31, 'da_xoa': false},
    {'ma_chuyen_khoa': 'CK032', 'ten_chuyen_khoa': 'Dinh dưỡng', 'ten_tieng_anh': 'Nutrition', 'nhom_chuyen_khoa_id': 'N05', 'ten_nhom': 'Chuyên khoa lẻ', 'mo_ta': 'Tư vấn và điều trị các vấn đề dinh dưỡng', 'icon': 'restaurant', 'mau_sac': '#84CC16', 'pho_bien': false, 'thu_tu': 32, 'da_xoa': false},
    {'ma_chuyen_khoa': 'CK033', 'ten_chuyen_khoa': 'Hồi sức cấp cứu', 'ten_tieng_anh': 'Emergency Medicine', 'nhom_chuyen_khoa_id': 'N05', 'ten_nhom': 'Chuyên khoa lẻ', 'mo_ta': 'Cấp cứu và hồi sức bệnh nhân nguy kịch', 'icon': 'emergency', 'mau_sac': '#DC2626', 'pho_bien': false, 'thu_tu': 33, 'da_xoa': false},
    {'ma_chuyen_khoa': 'CK034', 'ten_chuyen_khoa': 'Y học thể thao', 'ten_tieng_anh': 'Sports Medicine', 'nhom_chuyen_khoa_id': 'N05', 'ten_nhom': 'Chuyên khoa lẻ', 'mo_ta': 'Điều trị chấn thương vận động viên', 'icon': 'sports_soccer', 'mau_sac': '#0EA5E9', 'pho_bien': false, 'thu_tu': 34, 'da_xoa': false},
    {'ma_chuyen_khoa': 'CK035', 'ten_chuyen_khoa': 'Liệu pháp tâm lý', 'ten_tieng_anh': 'Psychotherapy', 'nhom_chuyen_khoa_id': 'N05', 'ten_nhom': 'Chuyên khoa lẻ', 'mo_ta': 'Tư vấn và trị liệu tâm lý', 'icon': 'self_improvement', 'mau_sac': '#A78BFA', 'pho_bien': false, 'thu_tu': 35, 'da_xoa': false},

    // ===== Y HỌC CỔ TRUYỀN (N06) =====
    {'ma_chuyen_khoa': 'CK036', 'ten_chuyen_khoa': 'Y học cổ truyền', 'ten_tieng_anh': 'Traditional Medicine', 'nhom_chuyen_khoa_id': 'N06', 'ten_nhom': 'Y học cổ truyền', 'mo_ta': 'Điều trị bằng đông y, châm cứu, bấm huyệt', 'icon': 'spa', 'mau_sac': '#059669', 'pho_bien': true, 'thu_tu': 36, 'da_xoa': false},
    {'ma_chuyen_khoa': 'CK037', 'ten_chuyen_khoa': 'Châm cứu', 'ten_tieng_anh': 'Acupuncture', 'nhom_chuyen_khoa_id': 'N06', 'ten_nhom': 'Y học cổ truyền', 'mo_ta': 'Điều trị bằng phương pháp châm cứu', 'icon': 'ac_unit', 'mau_sac': '#047857', 'pho_bien': false, 'thu_tu': 37, 'da_xoa': false},

    // ===== CẬN LÂM SÀNG (N07) =====
    {'ma_chuyen_khoa': 'CK038', 'ten_chuyen_khoa': 'Chẩn đoán hình ảnh', 'ten_tieng_anh': 'Radiology', 'nhom_chuyen_khoa_id': 'N07', 'ten_nhom': 'Cận lâm sàng', 'mo_ta': 'Chụp X-quang, CT, MRI, siêu âm', 'icon': 'radiology', 'mau_sac': '#64748B', 'pho_bien': false, 'thu_tu': 38, 'da_xoa': false},
    {'ma_chuyen_khoa': 'CK039', 'ten_chuyen_khoa': 'Xét nghiệm', 'ten_tieng_anh': 'Laboratory Medicine', 'nhom_chuyen_khoa_id': 'N07', 'ten_nhom': 'Cận lâm sàng', 'mo_ta': 'Xét nghiệm máu, nước tiểu và các dịch cơ thể', 'icon': 'biotech', 'mau_sac': '#475569', 'pho_bien': false, 'thu_tu': 39, 'da_xoa': false},
    {'ma_chuyen_khoa': 'CK040', 'ten_chuyen_khoa': 'Giải phẫu bệnh', 'ten_tieng_anh': 'Pathology', 'nhom_chuyen_khoa_id': 'N07', 'ten_nhom': 'Cận lâm sàng', 'mo_ta': 'Chẩn đoán bệnh qua mô bệnh học', 'icon': 'microscope', 'mau_sac': '#334155', 'pho_bien': false, 'thu_tu': 40, 'da_xoa': false},
  ];

  /// Hàm seed dữ liệu Nhóm chuyên khoa
  static Future<void> seedSpecialtyGroups() async {
    print('⏳ Đang kiểm tra và tạo dữ liệu Nhóm chuyên khoa...');
    final collectionRef = _firestore.collection('nhom_chuyen_khoa');
    var failedCount = 0;

    for (var group in _specialtyGroups) {
      try {
        final docId = group['ma_nhom'] as String;
        final docRef = collectionRef.doc(docId);
        final docSnapshot = await docRef.get();

        await docRef.set({
          ...group,
          if (!docSnapshot.exists) 'ngay_tao': FieldValue.serverTimestamp(),
          'ngay_cap_nhat': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        if (!docSnapshot.exists) {
          print('✅ Đã tạo nhóm: ${group['ten_nhom']}');
        } else {
          print('🔄 Đã cập nhật nhóm: ${group['ten_nhom']}');
        }
      } catch (e) {
        failedCount++;
        print('❌ Lỗi khi tạo nhóm ${group['ten_nhom']}: $e');
      }
    }
    
    if (failedCount > 0) throw StateError('Có $failedCount nhóm chuyên khoa chưa được ghi.');
    print('✅ Hoàn tất seeding ${_specialtyGroups.length} nhóm chuyên khoa!\n');
  }

  /// Hàm seed dữ liệu Chuyên khoa theo cấu trúc phân cấp
  static Future<void> seedSpecialties() async {
    print('⏳ Đang kiểm tra và tạo dữ liệu Chuyên khoa theo cấu trúc nhóm...');
    final mainCollectionRef = _firestore.collection('chuyen_khoa');
    var failedCount = 0;

    // BƯỚC 1: Tạo Document cha (đại diện cho Nhóm)
    for (final group in _specialtyGroups) {
      try {
        final groupId = group['ma_nhom'] as String;
        final groupDocRef = mainCollectionRef.doc(groupId);
        final groupSnapshot = await groupDocRef.get();

        await groupDocRef.set({
          'ma_nhom': groupId,
          'ten_nhom': group['ten_nhom'],
          'icon': group['icon'],
          'mau_sac': group['mau_sac'],
          'thu_tu': group['thu_tu'],
          if (!groupSnapshot.exists) 'ngay_tao': FieldValue.serverTimestamp(),
          'ngay_cap_nhat': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (e) {
        failedCount++;
        print('❌ Lỗi khi tạo document nhóm cha ${group['ten_nhom']}: $e');
      }
    }

    // BƯỚC 2: Tạo các document chuyên khoa BÊN TRONG document nhóm cha
    for (var specialty in _specialties) {
      try {
        final groupId = specialty['nhom_chuyen_khoa_id'] as String; 
        final specialtyId = specialty['ma_chuyen_khoa'] as String;  

        // ĐƯỜNG DẪN: chuyen_khoa (Collection) -> N01 (Document) -> danh_sach (Subcollection) -> CK001 (Document)
        final specialtyDocRef = mainCollectionRef
            .doc(groupId)
            .collection('danh_sach')
            .doc(specialtyId);

        final docSnapshot = await specialtyDocRef.get();

        // ✅ LOẠI BỎ HOÀN TOÀN DỮ LIỆU CỦA NHÓM KHỎI DOCUMENT CHUYÊN KHOA
        final specialtyData = Map<String, dynamic>.from(specialty);
        specialtyData.remove('ma_chuyen_khoa');       // Đã là ID của Document
        specialtyData.remove('nhom_chuyen_khoa_id');  // Đã là ID của Document cha
        specialtyData.remove('ten_nhom');             // Không cần lưu tên nhóm ở đây

        await specialtyDocRef.set({
          ...specialtyData, // Lúc này chỉ còn: ten_chuyen_khoa, ten_tieng_anh, mo_ta, icon, mau_sac, pho_bien, thu_tu, da_xoa
          if (!docSnapshot.exists) 'ngay_tao': FieldValue.serverTimestamp(),
          'ngay_cap_nhat': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        if (!docSnapshot.exists) {
          print('✅ Đã tạo: ${specialty['ten_chuyen_khoa']} (Trong nhóm: $groupId)');
        } else {
          print('🔄 Đã cập nhật: ${specialty['ten_chuyen_khoa']} (Trong nhóm: $groupId)');
        }
      } catch (e) {
        failedCount++;
        print('❌ Lỗi khi tạo ${specialty['ten_chuyen_khoa']}: $e');
      }
    }

    if (failedCount > 0) throw StateError('Có $failedCount mục chưa được ghi vào Firestore.');
    print('✅ Hoàn tất seeding ${_specialties.length} chuyên khoa!');
  }

  /// Hàm chạy tất cả các tác vụ seeding
  static Future<void> seedAllData() async {
    print('⏳ Bắt đầu quá trình seeding dữ liệu mẫu...');
    try {
      await seedSpecialtyGroups(); 
      await seedSpecialties();     
      print('\n🎉 HOÀN TẤT SEEDING TẤT CẢ DỮ LIỆU MẪU!');
    } catch (error) {
      print('❌ Seeder thất bại: $error');
    }
  }
}