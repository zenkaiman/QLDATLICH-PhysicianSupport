import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import '../../config/app_routes.dart';
import '../../providers/auth_provider.dart';
import '../../providers/hospital_provider.dart';
import '../../services/location_service.dart';
import '../patient/chat_detail_screen.dart';

/// Chỉnh độ trong suốt an toàn cho mọi phiên bản Flutter (thay withOpacity).
extension _ColorX on Color {
  Color o(double opacity) => withAlpha((opacity * 255).round().clamp(0, 255));
}

/// Màn hình danh sách bệnh viện: tìm kiếm, bộ lọc và đặt lịch khám.
class HospitalFilterScreen extends StatefulWidget {
  const HospitalFilterScreen({super.key});

  @override
  State<HospitalFilterScreen> createState() => _HospitalFilterScreenState();
}

class _HospitalFilterScreenState extends State<HospitalFilterScreen> {
  // ═══════════════════════════════════════════════════════════════
  // 1. HẰNG SỐ & TRẠNG THÁI
  // ═══════════════════════════════════════════════════════════════
  static const _primary = Color(0xFF0B63CE);
  static const _primaryDark = Color(0xFF084A9E);
  static const _primarySoft = Color(0xFFE8F1FC);
  static const _accent = Color(0xFF0FA3A3);
  static const _accentSoft = Color(0xFFE0F5F5);
  static const _warm = Color(0xFFB45309);
  static const _warmSoft = Color(0xFFFEF3C7);
  static const _bgColor = Color(0xFFF3F7FB);
  static const _textDark = Color(0xFF0B1F3A);
  static const _textGrey = Color(0xFF5B6B80);
  static const _border = Color(0xFFE3EAF2);

  final _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  Timer? _debounce; // chờ ngừng gõ rồi mới tìm

  final LocationService _locationService = LocationService();
  Position? _currentUserPosition; // vị trí người dùng (để tính khoảng cách)

  bool _isFilterExpanded = false;
  RangeValues _distanceRange = const RangeValues(0, 50);
  RangeValues _ratingRange = const RangeValues(0, 5);
  String? _insuranceType;
  String? _facilityType;
  final List<String> _selectedSpecialties = []; // id chuyên khoa, vd: 'CK01'

  // ═══════════════════════════════════════════════════════════════
  // 2. VÒNG ĐỜI
  // ═══════════════════════════════════════════════════════════════

  /// initState(): lấy vị trí và khởi tạo dữ liệu bệnh viện.
  @override
  void initState() {
    super.initState();
    _initLocation();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HospitalProvider>().init();
    });
  }

  /// dispose(): giải phóng controller, focus và timer.
  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  /// _initLocation(): lấy vị trí người dùng một lần khi vào màn hình.
  Future<void> _initLocation() async {
    final result = await _locationService.getUserLocationWithSource(null);
    if (mounted) setState(() => _currentUserPosition = result.position);
  }

  // ═══════════════════════════════════════════════════════════════
  // 3. XỬ LÝ LỌC & TÌM KIẾM
  // ═══════════════════════════════════════════════════════════════

  /// _getCoSoId(): id loại cơ sở đang chọn (Cong_lap / Tu_nhan).
  String? _getCoSoId([HospitalProvider? provider]) =>
      provider?.selectedCoSoId ??
      (_facilityType == 'Công lập'
          ? 'Cong_lap'
          : (_facilityType == 'Tư nhân' ? 'Tu_nhan' : null));

  /// _getBhytId(): id loại BHYT đang chọn (Co_BHYT / Khong_BHYT).
  String? _getBhytId([HospitalProvider? provider]) =>
      provider?.selectedBhytId ??
      (_insuranceType == 'Có BHYT'
          ? 'Co_BHYT'
          : (_insuranceType == 'Không BHYT' ? 'Khong_BHYT' : null));

  /// _applyFilters(): lọc bệnh viện theo cơ sở, BHYT, đánh giá, chuyên khoa.
  void _applyFilters([HospitalProvider? provider]) {
    final currentProvider = provider ?? context.read<HospitalProvider>();
    currentProvider.fetchAndFilterHospitals(
      coSoId: _getCoSoId(currentProvider),
      bhytId: _getBhytId(currentProvider),
      minRating: _ratingRange.start,
      specialtyIds: _selectedSpecialties,
    );
  }

  /// _searchByKeyword(): tìm bệnh viện theo từ khóa.
  void _searchByKeyword(String keyword, [HospitalProvider? provider]) {
    final currentProvider = provider ?? context.read<HospitalProvider>();
    currentProvider.searchHospitalsByKeyword(keyword);
  }

  /// _resetFilters(): đưa toàn bộ bộ lọc và ô tìm kiếm về mặc định.
  void _resetFilters() {
    setState(() {
      _distanceRange = const RangeValues(0, 50);
      _ratingRange = const RangeValues(0, 5);
      _insuranceType = null;
      _facilityType = null;
      _selectedSpecialties.clear();
      _searchCtrl.clear();
    });
    context.read<HospitalProvider>().resetFilters();
  }

  /// _onScroll(): gần cuối danh sách thì tải thêm bệnh viện.
  bool _onScroll(ScrollNotification info, HospitalProvider provider) {
    if (info.metrics.pixels >= info.metrics.maxScrollExtent - 300) {
      if (!provider.isLoadingMore && provider.hasMore && !provider.isLoading) {
        provider.loadMoreHospitals();
      }
    }
    return true;
  }

  /// _activeFilterCount(): số nhóm bộ lọc đang bật (hiện trên nút lọc).
  int _activeFilterCount(HospitalProvider provider) {
    var count = 0;
    if (_distanceRange.start > 0 || _distanceRange.end < 50) count++;
    if (_ratingRange.start > 0 || _ratingRange.end < 5) count++;
    if (_selectedSpecialties.isNotEmpty) count++;
    if (provider.selectedBhytId != null) count++;
    if (provider.selectedCoSoId != null) count++;
    return count;
  }

  // ═══════════════════════════════════════════════════════════════
  // 4. GIAO DIỆN CHÍNH
  // ═══════════════════════════════════════════════════════════════

  /// build(): khung màn hình: phần đầu (chào, tìm kiếm) + bộ lọc + danh sách.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: Consumer<HospitalProvider>(
        builder: (context, provider, child) {
          return NotificationListener<ScrollNotification>(
            onNotification: (info) => _onScroll(info, provider),
            child: CustomScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              slivers: [
                SliverToBoxAdapter(child: _buildHeroHeader(provider)),
                SliverToBoxAdapter(child: _buildFilterSection(provider)),
                SliverToBoxAdapter(child: _buildListTitle(provider)),
                _buildHospitalList(provider),
                const SliverToBoxAdapter(child: SizedBox(height: 40)),
              ],
            ),
          );
        },
      ),
    );
  }

  /// _buildListTitle(): tiêu đề "Danh sách bệnh viện" + số lượng kết quả.
  Widget _buildListTitle(HospitalProvider provider) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 12),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Bệnh viện gần bạn',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: _textDark,
                letterSpacing: -0.2,
              ),
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (child, animation) =>
                FadeTransition(opacity: animation, child: child),
            child: Container(
              key: ValueKey(provider.currentFilteredCount),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _primarySoft,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${provider.currentFilteredCount} kết quả',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: _primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// _buildHospitalList(): sliver danh sách (đang tải / lỗi / rỗng / có dữ liệu).
  Widget _buildHospitalList(HospitalProvider provider) {
    if (provider.isLoading) {
      return SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 7),
            child: _SkeletonCard(),
          ),
          childCount: 3,
        ),
      );
    }
    if (provider.errorMessage != null) {
      return SliverToBoxAdapter(
        child: _buildErrorState(provider.errorMessage!),
      );
    }
    if (provider.hospitals.isEmpty) {
      return SliverToBoxAdapter(child: _buildEmptyState());
    }
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) => _buildHospitalItem(provider, index),
        childCount: provider.hospitals.length + (provider.hasMore ? 1 : 0),
      ),
    );
  }

  /// _buildHospitalItem(): 1 dòng danh sách (thẻ bệnh viện hoặc vòng tải thêm).
  Widget _buildHospitalItem(HospitalProvider provider, int index) {
    if (index == provider.hospitals.length) {
      return const Padding(
        padding: EdgeInsets.all(20.0),
        child: Center(
          child: SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(strokeWidth: 3, color: _primary),
          ),
        ),
      );
    }

    final hospital = provider.hospitals[index];
    final name = hospital['ten_benh_vien']?.toString() ?? 'Cơ sở y tế';
    final type =
        hospital['co_so']?.toString() ??
        hospital['loai_hinh']?.toString() ??
        'Chưa cập nhật';
    final ratingValue =
        hospital['diem_danh_gia_tb'] ?? hospital['diem_danh_gia'];
    final reviewCountValue =
        hospital['tong_so_danh_gia'] ?? hospital['so_luong_danh_gia'];
    final isPublic = type == 'Công lập';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
      child: _buildHospitalCard(
        hospitalData: hospital,
        id: hospital['id']?.toString() ?? '',
        name: name,
        address: hospital['dia_chi']?.toString() ?? 'Chưa cập nhật địa chỉ',
        type: type,
        rating: ratingValue is num ? ratingValue.toDouble() : 0.0,
        reviewCount: reviewCountValue is num ? reviewCountValue.toInt() : 0,
        initials: _getInitials(name),
        bgColor: isPublic ? _accentSoft : _warmSoft,
        textColor: isPublic ? _accent : _warm,
        distance: _distanceTo(hospital),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 5. PHẦN ĐẦU: LỜI CHÀO & TÌM KIẾM
  // ═══════════════════════════════════════════════════════════════

  /// _buildHeroHeader(): nền gradient xanh bo cong chứa lời chào + ô tìm kiếm.
  Widget _buildHeroHeader(HospitalProvider provider) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_primaryDark, _primary, Color(0xFF1F8FE8)],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Stack(
        children: [
          // Vòng tròn trang trí mờ
          Positioned(
            right: -40,
            top: -30,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.o(0.07),
              ),
            ),
          ),
          Positioned(
            right: 50,
            bottom: -50,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.o(0.05),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 26),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 22),
                  const Text(
                    'Tìm bệnh viện\nphù hợp với bạn',
                    style: TextStyle(
                      fontSize: 26,
                      height: 1.2,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _buildSearchRow(provider),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// _buildHeader(): nút quay lại, ảnh chữ cái, lời chào theo giờ, tên và nút thông báo.
  Widget _buildHeader() {
    final userName = context.watch<AuthProvider>().user?.hoTen ?? '';
    final canPop = Navigator.of(
      context,
    ).canPop(); // có trang trước để quay lại?

    // Chữ cái đầu của từ cuối trong tên: "Nguyễn Văn A" -> "A"
    final words = userName.trim().split(' ');
    final initial = words.last.isNotEmpty ? words.last[0].toUpperCase() : '?';

    final hour = DateTime.now().hour;
    final greeting = hour < 11
        ? 'Chào buổi sáng'
        : hour < 14
        ? 'Chào buổi trưa'
        : hour < 18
        ? 'Chào buổi chiều'
        : 'Chào buổi tối';

    return Row(
      children: [
        // Nút quay lại (chỉ hiện khi có trang trước)
        if (canPop) ...[_buildBackButton(), const SizedBox(width: 12)],

        // Ảnh đại diện chữ cái
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.o(0.18),
            border: Border.all(color: Colors.white.o(0.7), width: 1.5),
          ),
          child: Center(
            child: Text(
              initial,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Lời chào + tên
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greeting,
                style: TextStyle(
                  fontSize: 12.5,
                  color: Colors.white.o(0.8),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                userName.isEmpty ? 'Bạn' : userName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),

        // Nút thông báo + chấm đỏ
        Stack(
          clipBehavior: Clip.none,
          children: [
            Material(
              color: Colors.white.o(0.16),
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () {
                  // TODO: mở màn hình thông báo
                },
                child: const SizedBox(
                  width: 44,
                  height: 44,
                  child: Icon(
                    Icons.notifications_none_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 9,
              right: 10,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF5A5F),
                  shape: BoxShape.circle,
                  border: Border.all(color: _primary, width: 2),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// _buildBackButton(): nút quay lại trang trước, cùng kiểu với nút thông báo.
  Widget _buildBackButton() {
    return Tooltip(
      message: 'Quay lại',
      child: Material(
        color: Colors.white.o(0.16),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => Navigator.maybePop(context),
          child: const SizedBox(
            width: 44,
            height: 44,
            child: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
              size: 19,
            ),
          ),
        ),
      ),
    );
  }

  /// _buildSearchRow(): ô tìm kiếm + nút mở bộ lọc (có số bộ lọc đang bật).
  Widget _buildSearchRow(HospitalProvider provider) {
    final activeCount = _activeFilterCount(provider);

    return Row(
      children: [
        Expanded(child: _buildSearchBar()),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: () => setState(() => _isFilterExpanded = !_isFilterExpanded),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: _isFilterExpanded ? _textDark : Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.o(0.12),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Icon(
                  Icons.tune_rounded,
                  size: 24,
                  color: _isFilterExpanded ? Colors.white : _primary,
                ),
                if (activeCount > 0)
                  Positioned(
                    top: -5,
                    right: -5,
                    child: Container(
                      constraints: const BoxConstraints(
                        minWidth: 20,
                        minHeight: 20,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      decoration: BoxDecoration(
                        color: _accent,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: Center(
                        child: Text(
                          '$activeCount',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// _buildSearchBar(): ô tìm kiếm (debounce 300ms, nút xóa khi có chữ).
  Widget _buildSearchBar() {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.o(0.12),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: _searchCtrl,
        builder: (context, value, _) {
          final hasText = value.text.isNotEmpty;

          return TextField(
            controller: _searchCtrl,
            focusNode: _searchFocus,
            onTapOutside: (_) => _searchFocus.unfocus(),
            cursorColor: _primary,
            textInputAction: TextInputAction.search,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: _textDark,
            ),
            // Gõ xong 300ms mới tìm
            onChanged: (text) {
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 300), () {
                _searchByKeyword(text);
              });
            },
            // Bấm "Tìm" trên bàn phím: tìm ngay
            onSubmitted: (text) {
              _debounce?.cancel();
              _searchByKeyword(text);
              _searchFocus.unfocus();
            },
            decoration: InputDecoration(
              hintText: 'Tên bệnh viện, địa chỉ...',
              hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
              filled: true,
              fillColor: Colors.white,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: _primary,
                size: 24,
              ),
              suffixIcon: hasText
                  ? IconButton(
                      tooltip: 'Xóa',
                      icon: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                      onPressed: () {
                        _debounce?.cancel();
                        _searchCtrl.clear();
                        _searchByKeyword(''); // trả danh sách về ban đầu
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: _accent, width: 1.5),
              ),
            ),
          );
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 6. BỘ LỌC
  // ═══════════════════════════════════════════════════════════════

  /// _buildFilterSection(): bảng bộ lọc, trượt mở / thu gọn.
  Widget _buildFilterSection(HospitalProvider provider) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      alignment: Alignment.topCenter,
      child: _isFilterExpanded
          ? Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              child: Container(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: _border),
                  boxShadow: [
                    BoxShadow(
                      color: _primary.o(0.06),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFilterHeader(),
                    const Divider(height: 1, color: _border),
                    const SizedBox(height: 18),
                    _buildSpecialtyFilter(provider),
                    const SizedBox(height: 22),
                    _buildDistanceFilter(provider),
                    const SizedBox(height: 14),
                    _buildRatingFilter(provider),
                    const SizedBox(height: 12),
                    const Divider(height: 1, color: _border),
                    const SizedBox(height: 18),
                    _buildBhytFilter(provider),
                    const SizedBox(height: 20),
                    _buildCoSoFilter(provider),
                  ],
                ),
              ),
            )
          : const SizedBox(width: double.infinity),
    );
  }

  /// _buildFilterHeader(): tiêu đề bảng lọc + nút "Đặt lại".
  Widget _buildFilterHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Bộ lọc',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: _textDark,
              ),
            ),
          ),
          TextButton.icon(
            onPressed: _resetFilters,
            icon: const Icon(Icons.refresh_rounded, size: 17),
            label: const Text(
              'Đặt lại',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            style: TextButton.styleFrom(
              foregroundColor: _primary,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
      ),
    );
  }

  /// _buildDistanceFilter(): thanh trượt khoảng cách 0–50 km.
  Widget _buildDistanceFilter(HospitalProvider provider) {
    final showLocationNote =
        provider.locationMessage != null &&
        (_distanceRange.start > 0 || _distanceRange.end < 50);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          Icons.near_me_outlined,
          'Khoảng cách',
          trailing: _buildValuePill(
            '${_distanceRange.start.toStringAsFixed(0)} – ${_distanceRange.end.toStringAsFixed(0)} km',
          ),
        ),
        SliderTheme(
          data: _sliderTheme(),
          child: RangeSlider(
            values: _distanceRange,
            min: 0,
            max: 50,
            divisions: 50,
            labels: RangeLabels(
              '${_distanceRange.start.round()} km',
              '${_distanceRange.end.round()} km',
            ),
            onChanged: (values) => setState(() => _distanceRange = values),
            onChangeEnd: (values) => provider.fetchAndFilterHospitals(
              minDistance: values.start,
              maxDistance: values.end,
            ),
          ),
        ),
        if (showLocationNote)
          Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _primarySoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 16, color: _primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    provider.locationMessage!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: _primary,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// _buildSpecialtyFilter(): ô chọn chuyên khoa (bấm để mở bottom sheet).
  Widget _buildSpecialtyFilter(HospitalProvider provider) {
    final hasSelection = _selectedSpecialties.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(Icons.medical_services_outlined, 'Chuyên khoa'),
        const SizedBox(height: 10),
        InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: _showSpecialtySelection,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: hasSelection ? _primarySoft : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: hasSelection ? _primary : _border),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.health_and_safety_outlined,
                  size: 20,
                  color: hasSelection ? _primary : _textGrey,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _getSelectedSpecialtyNames(provider),
                    style: TextStyle(
                      fontSize: 14,
                      color: hasSelection ? _textDark : _textGrey,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(Icons.keyboard_arrow_down_rounded, color: _textGrey),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// _buildRatingFilter(): thanh trượt số sao 0–5.
  Widget _buildRatingFilter(HospitalProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          Icons.star_rounded,
          'Đánh giá',
          trailing: _buildValuePill(
            '${_ratingRange.start.toStringAsFixed(1)} – ${_ratingRange.end.toStringAsFixed(1)} sao',
          ),
        ),
        SliderTheme(
          data: _sliderTheme(),
          child: RangeSlider(
            values: _ratingRange,
            min: 0,
            max: 5,
            divisions: 10,
            labels: RangeLabels(
              '${_ratingRange.start.toStringAsFixed(1)} sao',
              '${_ratingRange.end.toStringAsFixed(1)} sao',
            ),
            onChanged: (values) => setState(() => _ratingRange = values),
            onChangeEnd: (values) => provider.fetchAndFilterHospitals(
              minRating: values.start,
              maxRating: values.end,
            ),
          ),
        ),
      ],
    );
  }

  /// _buildBhytFilter(): chọn có / không BHYT.
  Widget _buildBhytFilter(HospitalProvider provider) {
    final options = provider.bhytList.isEmpty
        ? [
            {'ten_bhyt': 'Có BHYT', 'id': 'Co_BHYT'},
            {'ten_bhyt': 'Không BHYT', 'id': 'Khong_BHYT'},
          ]
        : provider.bhytList;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(Icons.verified_user_outlined, 'Bảo hiểm y tế'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options
              .map<Widget>(
                (bhyt) => _buildChoiceChip(
                  (bhyt['ten_bhyt'] ?? 'BHYT').toString(),
                  (bhyt['id'] ?? '').toString(),
                  provider.selectedBhytId,
                  (val) {
                    provider.setSelectedBhytId(val);
                    _applyFilters(provider);
                  },
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  /// _buildCoSoFilter(): chọn công lập / tư nhân.
  Widget _buildCoSoFilter(HospitalProvider provider) {
    final options = provider.coSoList.isEmpty
        ? [
            {'ten_co_so': 'Công lập', 'id': 'Cong_lap'},
            {'ten_co_so': 'Tư nhân', 'id': 'Tu_nhan'},
          ]
        : provider.coSoList;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(Icons.apartment_rounded, 'Loại hình cơ sở'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options
              .map<Widget>(
                (coSo) => _buildChoiceChip(
                  (coSo['ten_co_so'] ?? 'Cơ sở').toString(),
                  (coSo['id'] ?? '').toString(),
                  provider.selectedCoSoId,
                  (val) {
                    provider.setSelectedCoSoId(val);
                    _applyFilters(provider);
                  },
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  /// _buildSectionTitle(): tiêu đề từng mục lọc: icon + chữ (+ nhãn giá trị).
  Widget _buildSectionTitle(IconData icon, String title, {Widget? trailing}) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: _primarySoft,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, size: 16, color: _primary),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: _textDark,
            ),
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  /// _buildValuePill(): nhãn hiện giá trị đang chọn của thanh trượt.
  Widget _buildValuePill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _primarySoft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          color: _primary,
        ),
      ),
    );
  }

  /// _sliderTheme(): kiểu dáng thanh trượt (thanh mỏng, nút tròn).
  SliderThemeData _sliderTheme() {
    return SliderTheme.of(context).copyWith(
      trackHeight: 4,
      activeTrackColor: _primary,
      inactiveTrackColor: _primary.o(0.14),
      rangeThumbShape: const RoundRangeSliderThumbShape(enabledThumbRadius: 10),
      thumbColor: Colors.white,
      overlayColor: _primary.o(0.12),
      activeTickMarkColor: Colors.transparent,
      inactiveTickMarkColor: Colors.transparent,
      valueIndicatorColor: _primary,
      showValueIndicator: ShowValueIndicator.onlyForDiscrete,
    );
  }

  /// _buildChoiceChip(): chip chọn 1 giá trị (thay cho radio).
  Widget _buildChoiceChip(
    String label,
    String value,
    String? groupValue,
    ValueChanged<String> onChanged,
  ) {
    final selected = value == groupValue;
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: () => onChanged(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? _primary : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: selected ? _primary : _border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              const Icon(Icons.check_rounded, size: 16, color: Colors.white),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : _textDark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 7. CHỌN CHUYÊN KHOA (BOTTOM SHEET)
  // ═══════════════════════════════════════════════════════════════

  /// _getSelectedSpecialtyNames(): chuỗi tên các chuyên khoa đã chọn.
  String _getSelectedSpecialtyNames(HospitalProvider provider) {
    if (_selectedSpecialties.isEmpty) return 'Chọn chuyên khoa';

    final names = provider.specialtiesList
        .where((spec) => _selectedSpecialties.contains(spec['id']))
        .map((spec) => spec['ten_khoa'] as String)
        .toList();

    return names.join(', ');
  }

  /// _showSpecialtySelection(): mở bottom sheet chọn nhiều chuyên khoa, có tìm kiếm.
  void _showSpecialtySelection() {
    String query = ''; // từ khóa tìm trong sheet
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true, // sheet không chui xuống status bar
      backgroundColor: Colors.transparent,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final provider = context.watch<HospitalProvider>();

            // Lọc danh sách theo từ khóa
            final list = provider.specialtiesList.where((s) {
              final name = (s['ten_khoa'] as String).toLowerCase();
              return name.contains(query.trim().toLowerCase());
            }).toList();

            return Padding(
              // Đẩy sheet lên khi bàn phím hiện
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildSheetHandle(),
                    _buildSheetTitle(
                      () => setModalState(() => _selectedSpecialties.clear()),
                    ),
                    _buildSheetSearch((v) => setModalState(() => query = v)),
                    _buildSheetList(provider, list, setModalState),
                    _buildSheetApplyButton(sheetContext),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// _buildSheetHandle(): thanh kéo nhỏ ở đầu sheet.
  Widget _buildSheetHandle() {
    return Column(
      children: [
        const SizedBox(height: 10),
        Container(
          width: 44,
          height: 5,
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ],
    );
  }

  /// _buildSheetTitle(): tiêu đề sheet, số khoa đã chọn và nút "Xóa tất cả".
  Widget _buildSheetTitle(VoidCallback onClearAll) {
    final hasSelection = _selectedSpecialties.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _primarySoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.medical_services_outlined,
              color: _primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Chọn chuyên khoa',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: _textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hasSelection
                      ? 'Đã chọn ${_selectedSpecialties.length} chuyên khoa'
                      : 'Có thể chọn nhiều chuyên khoa',
                  style: TextStyle(
                    fontSize: 13,
                    color: hasSelection ? _primary : _textGrey,
                    fontWeight: hasSelection
                        ? FontWeight.w600
                        : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          if (hasSelection)
            TextButton(
              onPressed: onClearAll,
              style: TextButton.styleFrom(
                foregroundColor: Colors.red.shade600,
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
              child: const Text(
                'Xóa tất cả',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
    );
  }

  /// _buildSheetSearch(): ô tìm chuyên khoa trong sheet.
  Widget _buildSheetSearch(ValueChanged<String> onChanged) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: TextField(
        onChanged: onChanged,
        cursorColor: _primary,
        decoration: InputDecoration(
          hintText: 'Tìm chuyên khoa...',
          hintStyle: TextStyle(color: Colors.grey.shade500),
          prefixIcon: Icon(Icons.search, color: Colors.grey.shade500),
          filled: true,
          fillColor: const Color(0xFFF1F5F9),
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _primary, width: 1.2),
          ),
        ),
      ),
    );
  }

  /// _buildSheetList(): danh sách chuyên khoa (đang tải / rỗng / có dữ liệu).
  Widget _buildSheetList(
    HospitalProvider provider,
    List<dynamic> list,
    StateSetter setModalState,
  ) {
    if (provider.isLookupLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child: CircularProgressIndicator(color: _primary),
      );
    }

    if (list.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          children: [
            Icon(Icons.search_off, size: 44, color: Colors.grey.shade400),
            const SizedBox(height: 8),
            Text(
              'Không tìm thấy chuyên khoa',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return Flexible(
      child: ListView.separated(
        shrinkWrap: true,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        itemCount: list.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final specialty = list[index];
          final specId = specialty['id'] as String;
          final isSelected = _selectedSpecialties.contains(specId);

          return _buildSpecialtyOption(
            name: specialty['ten_khoa'] as String,
            isSelected: isSelected,
            onTap: () => setModalState(() {
              if (isSelected) {
                _selectedSpecialties.remove(specId);
              } else {
                _selectedSpecialties.add(specId);
              }
            }),
          );
        },
      ),
    );
  }

  /// _buildSpecialtyOption(): 1 dòng chuyên khoa có ô tick.
  Widget _buildSpecialtyOption({
    required String name,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? _primarySoft : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? _primary : _border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isSelected ? Colors.white : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.health_and_safety_outlined,
                color: isSelected ? _primary : _textGrey,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                name,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? _primary : _textDark,
                ),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? _primary : Colors.transparent,
                border: Border.all(
                  color: isSelected ? _primary : Colors.grey.shade300,
                  width: 1.5,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  /// _buildSheetApplyButton(): nút "Áp dụng bộ lọc": đóng sheet và lọc.
  Widget _buildSheetApplyButton(BuildContext sheetContext) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
          child: SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(sheetContext);
                _applyFilters();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.filter_alt_rounded, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    _selectedSpecialties.isEmpty
                        ? 'Áp dụng bộ lọc'
                        : 'Áp dụng bộ lọc (${_selectedSpecialties.length})',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 8. THẺ BỆNH VIỆN
  // ═══════════════════════════════════════════════════════════════

  /// _buildHospitalCard(): thẻ bệnh viện; bấm vào mở màn hình đặt lịch.
  Widget _buildHospitalCard({
    required Map<String, dynamic> hospitalData,
    required String id,
    required String name,
    required String address,
    required String type,
    required double rating,
    required int reviewCount,
    required String initials,
    required Color bgColor,
    required Color textColor,
    required double distance,
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: _primary.o(0.07),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.white,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: _border),
        ),
        child: InkWell(
          onTap: () => Navigator.pushNamed(
            context,
            AppRoutes.bookAppointment,
            arguments: hospitalData,
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCardTop(
                  id: id,
                  name: name,
                  type: type,
                  rating: rating,
                  reviewCount: reviewCount,
                  initials: initials,
                  bgColor: bgColor,
                  textColor: textColor,
                ),
                const SizedBox(height: 14),
                _buildCardAddress(address),
                const SizedBox(height: 14),
                const Divider(height: 1, color: _border),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _buildDistanceBadge(distance)),
                    const SizedBox(width: 10),
                    _buildBookButton(),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// _buildCardTop(): hàng đầu thẻ: chữ viết tắt, tên, loại hình, đánh giá, nút chat.
  Widget _buildCardTop({
    required String id,
    required String name,
    required String type,
    required double rating,
    required int reviewCount,
    required String initials,
    required Color bgColor,
    required Color textColor,
  }) {
    final hasRating = rating > 0;
    final isPublic = type == 'Công lập';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Chữ viết tắt trên nền dịu
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: Text(
              initials,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: textColor,
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),

        // Tên + loại hình + đánh giá
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontSize: 15.5,
                  height: 1.25,
                  fontWeight: FontWeight.w800,
                  color: _textDark,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isPublic
                              ? Icons.verified_rounded
                              : Icons.business_rounded,
                          size: 13,
                          color: textColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          type,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: textColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.star_rounded,
                        size: 17,
                        color: hasRating
                            ? const Color(0xFFF59E0B)
                            : Colors.grey.shade400,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        hasRating
                            ? rating.toStringAsFixed(1)
                            : 'Chưa có đánh giá',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: hasRating ? _textDark : _textGrey,
                        ),
                      ),
                      if (hasRating)
                        Text(
                          ' ($reviewCount)',
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: _textGrey,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),

        // Nút chat
        Tooltip(
          message: 'Nhắn tin với CSKH',
          child: Material(
            color: _primarySoft,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () =>
                  openHospitalChat(context, benhVienId: id, tenBenhVien: name),
              child: const Padding(
                padding: EdgeInsets.all(9),
                child: Icon(
                  Icons.chat_bubble_outline_rounded,
                  color: _primary,
                  size: 19,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// _buildCardAddress(): dòng địa chỉ bệnh viện.
  Widget _buildCardAddress(String address) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 1),
          child: Icon(Icons.location_on_outlined, color: _textGrey, size: 17),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            address,
            style: const TextStyle(fontSize: 13, height: 1.4, color: _textGrey),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  /// _buildDistanceBadge(): "Cách bạn X km" (hoặc chưa xác định).
  Widget _buildDistanceBadge(double distance) {
    final hasDistance = distance > 0;

    return Row(
      children: [
        Icon(
          Icons.near_me_rounded,
          size: 15,
          color: hasDistance ? _primary : _textGrey,
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            hasDistance
                ? 'Cách bạn ${distance.toStringAsFixed(1)} km'
                : 'Chưa xác định',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: hasDistance ? _primary : _textGrey,
            ),
          ),
        ),
      ],
    );
  }

  /// _buildBookButton(): nút giả "Đặt lịch" cuối thẻ (bấm cả thẻ để đặt).
  Widget _buildBookButton() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: _primary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.calendar_month_rounded, color: Colors.white, size: 17),
          SizedBox(width: 7),
          Text(
            'Đặt lịch khám',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 9. TRẠNG THÁI RỖNG & LỖI
  // ═══════════════════════════════════════════════════════════════

  /// _buildEmptyState(): thông báo không có bệnh viện phù hợp.
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 40, 32, 20),
        child: Column(
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: const BoxDecoration(
                color: _primarySoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.local_hospital_outlined,
                size: 46,
                color: _primary,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Không tìm thấy bệnh viện nào',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: _textDark,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Hãy thử bỏ bớt bộ lọc hoặc đổi từ khóa tìm kiếm.',
              style: TextStyle(fontSize: 14, height: 1.4, color: _textGrey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: _resetFilters,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Đặt lại bộ lọc'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _primary,
                side: const BorderSide(color: _primary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// _buildErrorState(): thông báo lỗi tải dữ liệu + nút "Thử lại".
  Widget _buildErrorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 40, 32, 20),
        child: Column(
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.wifi_off_rounded,
                size: 44,
                color: Colors.red.shade400,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Không tải được dữ liệu',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: _textDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(
                fontSize: 14,
                height: 1.4,
                color: _textGrey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: () => _applyFilters(),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Thử lại'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 10. TIỆN ÍCH
  // ═══════════════════════════════════════════════════════════════

  /// _getInitials(): chữ viết tắt từ tên bệnh viện (2 chữ cái đầu của 2 từ đầu).
  String _getInitials(String name) {
    final words = name.trim().split(RegExp(r'\s+'));
    if (words.first.isEmpty) return '?';
    if (words.length >= 2) {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    }
    return words[0]
        .substring(0, words[0].length > 2 ? 2 : words[0].length)
        .toUpperCase();
  }

  /// _distanceTo(): khoảng cách (km) từ người dùng đến bệnh viện; 0 nếu chưa biết.
  double _distanceTo(Map<String, dynamic> hospital) {
    final position = _currentUserPosition;
    if (position == null ||
        hospital['vi_do'] == null ||
        hospital['kinh_do'] == null) {
      return 0.0;
    }
    return _locationService.calculateDistanceInKm(
      position.latitude,
      position.longitude,
      (hospital['vi_do'] as num).toDouble(),
      (hospital['kinh_do'] as num).toDouble(),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// 11. SKELETON KHI ĐANG TẢI
// ═══════════════════════════════════════════════════════════════

/// _SkeletonCard: thẻ giả nhấp nháy nhẹ, thay cho vòng xoay khi tải danh sách.
class _SkeletonCard extends StatefulWidget {
  const _SkeletonCard();

  @override
  State<_SkeletonCard> createState() => _SkeletonCardState();
}

class _SkeletonCardState extends State<_SkeletonCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Widget _bar(double width, double height, {double radius = 8}) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: const Color(0xFFE6EDF5),
      borderRadius: BorderRadius.circular(radius),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.45, end: 1).animate(_ctrl),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFE3EAF2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _bar(56, 56, radius: 16),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _bar(double.infinity, 14),
                      const SizedBox(height: 10),
                      _bar(120, 12),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _bar(double.infinity, 12),
            const SizedBox(height: 8),
            _bar(180, 12),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [_bar(90, 14), _bar(110, 36, radius: 12)],
            ),
          ],
        ),
      ),
    );
  }
}
