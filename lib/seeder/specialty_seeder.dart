import 'package:cloud_firestore/cloud_firestore.dart';

class SpecialtySeeder {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ==========================================
  // DANH SÁCH 30 CHUYÊN KHOA MẪU
  // ==========================================
  static final List<Map<String, String>> _specialtiesPool = [
    {
      'ten_khoa': 'Khoa Nội tổng quát',
      'mo_ta': 'Khám và điều trị các bệnh lý nội khoa chung',
    },
    {
      'ten_khoa': 'Khoa Ngoại tổng quát',
      'mo_ta': 'Phẫu thuật và điều trị các bệnh lý ngoại khoa',
    },
    {
      'ten_khoa': 'Khoa Cấp cứu',
      'mo_ta': 'Tiếp nhận và xử trí khẩn cấp các trường hợp nguy kịch',
    },
    {
      'ten_khoa': 'Khoa Tim mạch',
      'mo_ta': 'Chẩn đoán và điều trị các bệnh lý về tim và mạch máu',
    },
    {
      'ten_khoa': 'Khoa Tiêu hóa',
      'mo_ta': 'Chuyên sâu về các bệnh lý dạ dày, ruột, gan, mật',
    },
    {
      'ten_khoa': 'Khoa Hô hấp',
      'mo_ta': 'Điều trị các bệnh về phổi và đường hô hấp',
    },
    {
      'ten_khoa': 'Khoa Thần kinh',
      'mo_ta': 'Chẩn đoán và điều trị các bệnh lý về não bộ và thần kinh',
    },
    {
      'ten_khoa': 'Khoa Cơ xương khớp',
      'mo_ta': 'Điều trị các bệnh lý về xương, khớp và cột sống',
    },
    {
      'ten_khoa': 'Khoa Sản phụ khoa',
      'mo_ta': 'Chăm sóc sức khỏe sinh sản, thai sản và phụ khoa',
    },
    {
      'ten_khoa': 'Khoa Nhi',
      'mo_ta': 'Khám và điều trị các bệnh lý dành riêng cho trẻ em',
    },
    {
      'ten_khoa': 'Khoa Mắt',
      'mo_ta': 'Chẩn đoán và điều trị các bệnh lý về mắt và thị lực',
    },
    {
      'ten_khoa': 'Khoa Tai Mũi Họng',
      'mo_ta': 'Điều trị các bệnh lý vùng tai, mũi và họng',
    },
    {
      'ten_khoa': 'Khoa Răng Hàm Mặt',
      'mo_ta': 'Chăm sóc sức khỏe răng miệng và phẫu thuật hàm mặt',
    },
    {
      'ten_khoa': 'Khoa Da liễu',
      'mo_ta': 'Chẩn đoán và điều trị các bệnh lý về da, tóc, móng',
    },
    {
      'ten_khoa': 'Khoa Ung bướu',
      'mo_ta': 'Tầm soát, chẩn đoán và điều trị các bệnh lý ung thư',
    },
    {
      'ten_khoa': 'Khoa Thận - Tiết niệu',
      'mo_ta': 'Điều trị các bệnh lý về thận và hệ bài tiết',
    },
    {
      'ten_khoa': 'Khoa Nội tiết',
      'mo_ta': 'Điều trị các bệnh rối loạn chuyển hóa, tuyến giáp, tiểu đường',
    },
    {
      'ten_khoa': 'Khoa Truyền nhiễm',
      'mo_ta': 'Điều trị các bệnh lý do vi khuẩn, virus gây ra',
    },
    {
      'ten_khoa': 'Khoa Hồi sức tích cực (ICU)',
      'mo_ta': 'Theo dõi và điều trị chuyên sâu cho bệnh nhân nguy kịch',
    },
    {
      'ten_khoa': 'Khoa Gây mê hồi sức',
      'mo_ta': 'Đảm bảo an toàn cho bệnh nhân trong và sau phẫu thuật',
    },
    {
      'ten_khoa': 'Khoa Chẩn đoán hình ảnh',
      'mo_ta': 'Thực hiện các kỹ thuật X-quang, CT, MRI, siêu âm',
    },
    {
      'ten_khoa': 'Khoa Xét nghiệm',
      'mo_ta': 'Phân tích mẫu bệnh phẩm để hỗ trợ chẩn đoán',
    },
    {
      'ten_khoa': 'Khoa Vật lý trị liệu',
      'mo_ta': 'Phục hồi chức năng vận động sau chấn thương hoặc phẫu thuật',
    },
    {
      'ten_khoa': 'Khoa Tâm thần',
      'mo_ta': 'Chẩn đoán và điều trị các rối loạn sức khỏe tâm thần',
    },
    {
      'ten_khoa': 'Khoa Y học cổ truyền',
      'mo_ta': 'Điều trị bệnh bằng các phương pháp y học cổ truyền, châm cứu',
    },
    {
      'ten_khoa': 'Khoa Dinh dưỡng',
      'mo_ta': 'Tư vấn và điều trị các vấn đề liên quan đến dinh dưỡng',
    },
    {
      'ten_khoa': 'Khoa Huyết học',
      'mo_ta': 'Chuyên về các bệnh lý về máu và truyền máu',
    },
    {
      'ten_khoa': 'Khoa Lão khoa',
      'mo_ta': 'Chăm sóc sức khỏe chuyên biệt cho người cao tuổi',
    },
    {
      'ten_khoa': 'Khoa Thẩm mỹ',
      'mo_ta': 'Thực hiện các dịch vụ chăm sóc và phẫu thuật thẩm mỹ',
    },
    {
      'ten_khoa': 'Khoa Kiểm soát nhiễm khuẩn',
      'mo_ta': 'Đảm bảo quy trình vô trùng và phòng ngừa lây nhiễm trong bệnh viện',
    },
  ];

  /// Hàm đẩy 30 chuyên khoa lên collection 'chuyen_khoa'
  static Future<void> seedSpecialties() async {
    print('⏳ Đang tạo dữ liệu 30 chuyên khoa lên Firestore...');
    int successCount = 0;
    int failedCount = 0;

    for (int i = 0; i < _specialtiesPool.length; i++) {
      final specialty = _specialtiesPool[i];
      
      // Tự động sinh ID đẹp: CK01, CK02, ..., CK30
      final specialtyId = 'CK${(i + 1).toString().padLeft(2, '0')}';

      try {
        final docRef = _firestore.collection('chuyen_khoa').doc(specialtyId);
        final docSnapshot = await docRef.get();

        await docRef.set({
          'id': specialtyId,
          'ten_khoa': specialty['ten_khoa'],
          'mo_ta': specialty['mo_ta'],
          if (!docSnapshot.exists) 'ngay_tao': FieldValue.serverTimestamp(),
          'ngay_cap_nhat': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        successCount++;
        print('   ✅ Đã tạo: ${specialty['ten_khoa']} (ID: $specialtyId)');
      } catch (e) {
        failedCount++;
        print('   ❌ Lỗi khi tạo chuyên khoa ${specialty['ten_khoa']}: $e');
      }
    }

    print('\n🎉 HOÀN TẤT SEEDING!');
    print('📊 Thành công: $successCount / 30');
    if (failedCount > 0) {
      print('⚠️ Thất bại: $failedCount');
    }
  }
}