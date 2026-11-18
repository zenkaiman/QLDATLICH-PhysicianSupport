import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_routes.dart';
import '../../models/family_profile_model.dart';
import '../../providers/family_profile_provider.dart';
import '../../utils/app_snackbar.dart';
import '../../widgets/family_widgets.dart';

const Color _kPrimary = Color(0xFF2563EB);
const Color _kPrimaryDark = Color(0xFF1E40AF);
const Color _kBg = Color(0xFFF4F7FB);
const Color _kText = Color(0xFF0F172A);
const Color _kGrey = Color(0xFF64748B);
const Color _kHint = Color(0xFF94A3B8);
const Color _kBorder = Color(0xFFE6EBF2);
const Color _kGreen = Color(0xFF10B981);
const Color _kDanger = Color(0xFFDC2626);

int _ageOf(DateTime d) {
  final now = DateTime.now();
  var age = now.year - d.year;
  if (now.month < d.month || (now.month == d.month && now.day < d.day)) age--;
  return age < 0 ? 0 : age;
}

class FamilyProfilesScreen extends StatelessWidget {
  const FamilyProfilesScreen({super.key});

  void _openForm(BuildContext context, [FamilyProfileModel? p]) {
    if (p != null && p.isSelf) {
      // Hồ sơ chính chủ chỉnh ở màn Cập nhật thông tin cá nhân (1 nguồn dữ liệu duy nhất)
      Navigator.pushNamed(context, AppRoutes.editProfile);
      return;
    }
    Navigator.pushNamed(context, AppRoutes.addEditFamilyProfile, arguments: p);
  }

  Future<void> _confirmDelete(BuildContext context, FamilyProfileModel p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 26, 22, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: _kDanger.withOpacity(0.10),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.delete_outline_rounded,
                    color: _kDanger, size: 30),
              ),
              const SizedBox(height: 16),
              const Text(
                'Xóa hồ sơ người thân?',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w800, color: _kText),
              ),
              const SizedBox(height: 8),
              Text(
                'Hồ sơ "${p.hoTen}" sẽ bị xóa. Các lịch hẹn đã đặt trước đó vẫn được giữ lại.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 13.5, height: 1.45, color: _kGrey),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _kText,
                          side: const BorderSide(color: _kBorder, width: 1.4),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text('Hủy',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _kDanger,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text('Xóa',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await context.read<FamilyProfileProvider>().remove(p.id);
      if (!context.mounted) return;
      context.showAppSnackBar(
          message: 'Đã xóa hồ sơ', type: SnackBarType.success);
    } catch (e) {
      if (!context.mounted) return;
      context.showAppSnackBar(
        message: e.toString().replaceFirst('Exception: ', ''),
        type: SnackBarType.error,
      );
    }
  }

  Future<void> _setDefault(BuildContext context, FamilyProfileModel p) async {
    try {
      await context.read<FamilyProfileProvider>().setDefault(p.id);
      if (!context.mounted) return;
      context.showAppSnackBar(
        message: 'Đã đặt "${p.hoTen}" làm hồ sơ mặc định',
        type: SnackBarType.success,
      );
    } catch (_) {
      if (!context.mounted) return;
      context.showAppSnackBar(
        message: 'Không thể đặt mặc định, vui lòng thử lại',
        type: SnackBarType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final fp = context.watch<FamilyProfileProvider>();
    final hasRelatives = fp.profiles.any((p) => !p.isSelf);

    return Scaffold(
      backgroundColor: _kBg,
      body: Column(
        children: [
          _Header(count: fp.profiles.length, current: fp.current),
          Expanded(
            child: RefreshIndicator(
              color: _kPrimary,
              onRefresh: () => fp.load(null, force: true),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                children: [
                  const _TipCard(),
                  const SizedBox(height: 16),
                  if (fp.isLoading && fp.profiles.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (fp.error != null && fp.profiles.isEmpty)
                    _MessageBox(
                      icon: Icons.cloud_off_rounded,
                      title: 'Không tải được hồ sơ',
                      text: fp.error!,
                    )
                  else ...[
                    ...fp.profiles.map(
                      (p) => Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _ProfileCard(
                          profile: p,
                          selected: p.id == fp.currentId,
                          onSelect: () => fp.select(p.id),
                          onEdit: () => _openForm(context, p),
                          onDelete:
                              p.isSelf ? null : () => _confirmDelete(context, p),
                          onSetDefault: p.isDefault
                              ? null
                              : () => _setDefault(context, p),
                        ),
                      ),
                    ),
                    if (!hasRelatives)
                      _MessageBox(
                        icon: Icons.family_restroom_rounded,
                        title: 'Chưa có người thân nào',
                        text:
                            'Thêm bố mẹ, con nhỏ... để đặt lịch và theo dõi số thứ tự giúp họ ngay trên điện thoại của bạn.',
                      ),
                  ],
                ],
              ),
            ),
          ),
          _BottomBar(onAdd: () => _openForm(context)),
        ],
      ),
    );
  }
}

// ───────────────────────── ĐẦU TRANG ─────────────────────────

class _Header extends StatelessWidget {
  final int count;
  final FamilyProfileModel? current;
  const _Header({required this.count, required this.current});

  Widget _bubble(double size, double opacity) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(opacity),
        ),
      );

  Widget _stat(IconData icon, String value, String label) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, size: 18, color: Colors.white),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0D47A1), _kPrimaryDark, Color(0xFF3B82F6)],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
        child: Stack(
          children: [
            Positioned(top: -50, right: -40, child: _bubble(180, 0.09)),
            Positioned(bottom: -30, left: -50, child: _bubble(140, 0.06)),
            Positioned(
              top: 60,
              right: 60,
              child: Icon(Icons.add_rounded,
                  size: 28, color: Colors.white.withOpacity(0.12)),
            ),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Material(
                          color: Colors.white.withOpacity(0.18),
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () => Navigator.maybePop(context),
                            child: const SizedBox(
                              width: 40,
                              height: 40,
                              child: Icon(Icons.arrow_back_ios_new_rounded,
                                  size: 18, color: Colors.white),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Quản lý người thân',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Một tài khoản, nhiều hồ sơ bệnh nhân',
                                style: TextStyle(
                                    fontSize: 12.5, color: Color(0xD9FFFFFF)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        _stat(Icons.groups_rounded, '$count', 'Hồ sơ'),
                        const SizedBox(width: 10),
                        _stat(
                          Icons.visibility_rounded,
                          current == null
                              ? '—'
                              : (current!.isSelf ? 'Tôi' : current!.shortName),
                          'Đang xem',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TipCard extends StatelessWidget {
  const _TipCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEFF6FF), Color(0xFFE6FBF3)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _kPrimary.withOpacity(0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _kPrimary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(Icons.tips_and_updates_rounded,
                size: 19, color: _kPrimary),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Chọn một hồ sơ để xem lịch khám, số thứ tự và mã QR của người đó. '
              'Khi đặt lịch, bạn có thể chọn khám cho ai.',
              style: TextStyle(
                  fontSize: 13, height: 1.5, color: _kText, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── THẺ HỒ SƠ ─────────────────────────

class _ProfileCard extends StatelessWidget {
  final FamilyProfileModel profile;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onSetDefault;

  const _ProfileCard({
    required this.profile,
    required this.selected,
    required this.onSelect,
    required this.onEdit,
    this.onDelete,
    this.onSetDefault,
  });

  Widget _tag(String text, Color c, {IconData? icon}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: c.withOpacity(0.12),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 12, color: c),
              const SizedBox(width: 4),
            ],
            Text(text,
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w800, color: c)),
          ],
        ),
      );

  Widget _info(IconData icon, String text, {bool muted = false}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: muted ? _kHint : _kGrey),
            const SizedBox(width: 6),
            Text(
              text,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                fontStyle: muted ? FontStyle.italic : FontStyle.normal,
                color: muted ? _kHint : _kText,
              ),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final p = profile;
    final color = profileColor(p);
    final dob = p.ngaySinh;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: (selected ? color : Colors.black)
                .withOpacity(selected ? 0.16 : 0.04),
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
          side: BorderSide(
            color: selected ? color : _kBorder,
            width: selected ? 1.8 : 1,
          ),
        ),
        child: InkWell(
          onTap: onSelect,
          child: Column(
            children: [
              Container(
                height: 4,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                      colors: [color, color.withOpacity(0.15)]),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 6, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ProfileAvatar(profile: p, size: 56, selected: selected),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  p.hoTen.isEmpty ? 'Chưa có tên' : p.hoTen,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 16.5,
                                    fontWeight: FontWeight.w900,
                                    color: _kText,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: [
                                    _tag(
                                      p.isSelf ? 'Chính chủ' : p.quanHe,
                                      color,
                                      icon: p.isSelf
                                          ? Icons.verified_user_rounded
                                          : Icons.favorite_rounded,
                                    ),
                                    if (p.isDefault)
                                      _tag('Mặc định', _kGreen,
                                          icon: Icons.star_rounded),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert_rounded,
                              color: _kGrey),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          onSelected: (v) {
                            if (v == 'edit') onEdit();
                            if (v == 'default') onSetDefault?.call();
                            if (v == 'delete') onDelete?.call();
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Row(children: [
                                Icon(Icons.edit_rounded,
                                    size: 18, color: _kGrey),
                                SizedBox(width: 10),
                                Text('Sửa thông tin'),
                              ]),
                            ),
                            if (onSetDefault != null)
                              const PopupMenuItem(
                                value: 'default',
                                child: Row(children: [
                                  Icon(Icons.star_outline_rounded,
                                      size: 18, color: _kGrey),
                                  SizedBox(width: 10),
                                  Text('Đặt làm mặc định'),
                                ]),
                              ),
                            if (onDelete != null)
                              const PopupMenuItem(
                                value: 'delete',
                                child: Row(children: [
                                  Icon(Icons.delete_outline_rounded,
                                      size: 18, color: _kDanger),
                                  SizedBox(width: 10),
                                  Text('Xóa hồ sơ',
                                      style: TextStyle(color: _kDanger)),
                                ]),
                              ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (dob != null)
                            _info(Icons.cake_rounded,
                                '${dob.year} · ${_ageOf(dob)} tuổi')
                          else
                            _info(Icons.cake_rounded, 'Chưa có ngày sinh',
                                muted: true),
                          if (p.gioiTinh.isNotEmpty)
                            _info(Icons.wc_rounded, p.gioiTinh),
                          if (p.soDienThoai.isNotEmpty)
                            _info(Icons.phone_rounded, p.soDienThoai),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: Row(
                        children: [
                          if (selected)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 7),
                              decoration: BoxDecoration(
                                color: _kGreen.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_circle_rounded,
                                      size: 15, color: _kGreen),
                                  SizedBox(width: 6),
                                  Text('Đang xem hồ sơ này',
                                      style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF047857))),
                                ],
                              ),
                            )
                          else
                            OutlinedButton(
                              onPressed: onSelect,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: color,
                                side: BorderSide(
                                    color: color.withOpacity(0.5), width: 1.3),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 6),
                                minimumSize: const Size(0, 34),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20)),
                              ),
                              child: const Text('Xem hồ sơ này',
                                  style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w800)),
                            ),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: onEdit,
                            icon: const Icon(Icons.edit_rounded, size: 16),
                            label: const Text('Sửa',
                                style: TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w800)),
                            style: TextButton.styleFrom(
                              foregroundColor: _kPrimary,
                              minimumSize: const Size(0, 34),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 10),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageBox extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;
  const _MessageBox(
      {required this.icon, required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 26, 22, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                    shape: BoxShape.circle, color: _kPrimary.withOpacity(0.07)),
              ),
              Container(
                width: 66,
                height: 66,
                decoration: BoxDecoration(
                    shape: BoxShape.circle, color: _kPrimary.withOpacity(0.13)),
                child: Icon(icon, size: 34, color: _kPrimary),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(title,
              style: const TextStyle(
                  fontSize: 16.5, fontWeight: FontWeight.w900, color: _kText)),
          const SizedBox(height: 6),
          Text(text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 13.5, height: 1.5, color: _kGrey)),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  final VoidCallback onAdd;
  const _BottomBar({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: _kBorder)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.person_add_alt_1_rounded, size: 22),
            label: const Text('Thêm người thân',
                style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800)),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kPrimary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
      ),
    );
  }
}