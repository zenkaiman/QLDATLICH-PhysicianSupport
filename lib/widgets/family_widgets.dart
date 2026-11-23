import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_routes.dart';
import '../../models/family_profile_model.dart';
import '../../providers/family_profile_provider.dart';

const Color _kPrimary = Color(0xFF2563EB);
const Color _kText = Color(0xFF0F172A);
const Color _kGrey = Color(0xFF64748B);
const Color _kBorder = Color(0xFFE6EBF2);

const List<Color> _palette = [
  Color(0xFF2563EB),
  Color(0xFF10B981),
  Color(0xFF8B5CF6),
  Color(0xFFF59E0B),
  Color(0xFFEC4899),
  Color(0xFF0EA5E9),
];

Color profileColor(FamilyProfileModel p) =>
    p.isSelf ? _kPrimary : _palette[p.id.hashCode.abs() % _palette.length];

/// Avatar tròn: ảnh (nếu có) hoặc chữ cái đầu.
class ProfileAvatar extends StatelessWidget {
  final FamilyProfileModel profile;
  final double size;
  final bool selected;

  const ProfileAvatar({
    super.key,
    required this.profile,
    this.size = 52,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = profileColor(profile);
    final hasPhoto = profile.anhDaiDien.isNotEmpty;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withOpacity(0.22), color.withOpacity(0.08)],
        ),
        border: Border.all(
          color: selected ? color : color.withOpacity(0.25),
          width: selected ? 3 : 1.5,
        ),
        image: hasPhoto
            ? DecorationImage(
                image: NetworkImage(profile.anhDaiDien),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: hasPhoto
          ? null
          : Center(
              child: Text(
                profile.initials,
                style: TextStyle(
                  fontSize: size * 0.36,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
            ),
    );
  }
}

/// Hàng avatar ngang "Khám cho ai?" dùng ở màn đặt lịch.
class ProfileChipsRow extends StatelessWidget {
  final String title;
  final List<FamilyProfileModel> profiles;
  final String? selectedId;
  final ValueChanged<String> onSelected;

  const ProfileChipsRow({
    super.key,
    this.title = 'Khám cho ai?',
    required this.profiles,
    required this.selectedId,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.groups_rounded, size: 20, color: _kPrimary),

              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                  color: _kText,
                ),
              ),

              const Spacer(),
              GestureDetector(
                onTap: () =>
                    Navigator.pushNamed(context, AppRoutes.familyProfiles),
                child: const Text(
                  'Quản lý',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _kPrimary,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          SizedBox(
            height: 104,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: profiles.length,
              separatorBuilder: (_, __) => const SizedBox(width: 14),
              itemBuilder: (_, i) {
                final p = profiles[i];
                final sel = p.id == selectedId;

                return GestureDetector(
                  onTap: () => onSelected(p.id),
                  child: SizedBox(
                    width: 66,
                    child: Column(
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            ProfileAvatar(profile: p, size: 56, selected: sel),
                            if (sel)
                              const Positioned(
                                right: -2,
                                bottom: -2,
                                child: CircleAvatar(
                                  radius: 9,
                                  backgroundColor: Colors.white,
                                  child: Icon(
                                    Icons.check_circle_rounded,
                                    size: 18,
                                    color: Color(0xFF10B981),
                                  ),
                                ),
                              ),
                          ],
                        ),

                        const SizedBox(height: 6),
                        Text(
                          p.shortName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: sel ? FontWeight.w800 : FontWeight.w600,
                            color: sel ? _kPrimary : _kText,
                          ),
                        ),
                        Text(
                          p.isSelf ? 'Chính chủ' : p.quanHe,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 10.5, color: _kGrey),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet đổi hồ sơ đang xem (gọi từ Home / bất kỳ đâu).
Future<void> showProfileSwitcherSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    clipBehavior: Clip.antiAlias,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (ctx) => Consumer<FamilyProfileProvider>(
      builder: (ctx, fp, _) {
        final maxH = MediaQuery.of(ctx).size.height * 0.88;

        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxH),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thanh kéo
              const SizedBox(height: 10),
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Tiêu đề
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF3B82F6), Color(0xFF1E40AF)],
                        ),
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: _kPrimary.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.swap_horiz_rounded,
                        color: Colors.white,
                        size: 25,
                      ),
                    ),

                    const SizedBox(width: 14),

                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Đổi hồ sơ đang xem',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: _kText,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Lịch khám, số thứ tự và mã QR sẽ theo hồ sơ bạn chọn',
                            style: TextStyle(
                              fontSize: 12.5,
                              height: 1.35,
                              color: _kGrey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => Navigator.pop(ctx),
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: const BoxDecoration(
                          color: Color(0xFFF1F5F9),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: _kGrey,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Danh sách hồ sơ
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: fp.profiles.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final p = fp.profiles[i];

                    return _SwitcherTile(
                      profile: p,
                      selected: p.id == fp.currentId,
                      onTap: () {
                        ctx.read<FamilyProfileProvider>().select(p.id);
                        Navigator.pop(ctx);
                      },
                    );
                  },
                ),
              ),

              const SizedBox(height: 14),

              // Hành động
              Container(
                padding: EdgeInsets.fromLTRB(
                  20,
                  12,
                  20,
                  12 + MediaQuery.of(ctx).padding.bottom * 0,
                ),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: _kBorder)),
                ),
                child: SafeArea(
                  top: false,
                  child: Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(ctx);
                              Navigator.pushNamed(
                                context,
                                AppRoutes.addEditFamilyProfile,
                              );
                            },
                            icon: const Icon(
                              Icons.person_add_alt_1_rounded,
                              size: 19,
                            ),
                            label: const Text(
                              'Thêm người thân',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _kPrimary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 10),
                      SizedBox(
                        height: 48,
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            Navigator.pushNamed(
                              context,
                              AppRoutes.familyProfiles,
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _kPrimary,
                            side: const BorderSide(
                              color: _kPrimary,
                              width: 1.3,
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            'Quản lý',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

class _SwitcherTile extends StatelessWidget {
  final FamilyProfileModel profile;
  final bool selected;
  final VoidCallback onTap;

  const _SwitcherTile({
    required this.profile,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = profile;
    final color = profileColor(p);

    final parts = <String>[p.isSelf ? 'Chính chủ' : p.quanHe];
    if (p.namSinh != null) parts.add('${p.namSinh}');
    final subtitle = parts.join(' · ');

    return Material(
      color: selected ? color.withOpacity(0.07) : Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? color : _kBorder,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              ProfileAvatar(profile: p, size: 48, selected: selected),

              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            p.hoTen.isEmpty ? 'Chưa có tên' : p.hoTen,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: _kText,
                            ),
                          ),
                        ),
                        if (p.isDefault) ...[
                          const SizedBox(width: 6),

                          const Icon(
                            Icons.star_rounded,
                            size: 16,
                            color: Color(0xFFF59E0B),
                          ),
                        ],
                      ],
                    ),

                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            subtitle,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: color,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? color : Colors.transparent,
                  border: Border.all(
                    color: selected ? color : const Color(0xFFCBD5E1),
                    width: 2,
                  ),
                ),
                child: selected
                    ? const Icon(
                        Icons.check_rounded,
                        size: 16,
                        color: Colors.white,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
