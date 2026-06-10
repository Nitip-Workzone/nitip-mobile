import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:screen_protector/screen_protector.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../domain/models/user_model.dart';
import '../../../providers/auth_provider.dart';
import '../../auth/change_pin_page.dart';
import '../../auth/pin_setup_page.dart';
import '../../../providers/biometric_provider.dart';
import '../../../providers/location_provider.dart';
import '../../../providers/wallet_provider.dart';
import '../../../providers/trip_provider.dart';
import '../../../widgets/wallet/pin_input_sheet.dart';
import '../../../widgets/common/location_detail_sheet.dart';

class ProfileTab extends ConsumerStatefulWidget {
  const ProfileTab({super.key});

  @override
  ConsumerState<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends ConsumerState<ProfileTab> {
  @override
  void initState() {
    super.initState();
    ScreenProtector.preventScreenshotOn();
    ScreenProtector.protectDataLeakageOn();
  }

  @override
  void dispose() {
    ScreenProtector.preventScreenshotOff();
    ScreenProtector.protectDataLeakageOff();
    super.dispose();
  }

  String? _getAvatarUrl(String? path) {
    if (path == null || path.isEmpty) return null;
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    try {
      final baseUri = Uri.parse(AppConfig.baseUrl);
      final hostUrl = "${baseUri.scheme}://${baseUri.host}:${baseUri.port}";
      return "$hostUrl/uploads/$path";
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final isRunner = user?.isRunner ?? false;
    final isVerified = user?.isVerified ?? false;
    final primary = AppColors.secondary;
    final primaryDark = AppColors.secondaryDark;
    final primaryMid = AppColors.secondaryMid;

    final walletState = ref.watch(walletProvider);
    final tripState = ref.watch(tripProvider);

    final userLocation = ref.watch(userLocationProvider);
    final userAddressAsync = ref.watch(userAddressProvider);

    String formatCompact(double value) {
      if (value >= 1000000) {
        return 'Rp ${(value / 1000000).toStringAsFixed(1)}jt';
      } else if (value >= 1000) {
        return 'Rp ${(value / 1000).toStringAsFixed(0)}rb';
      }
      return 'Rp ${value.toStringAsFixed(0)}';
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [primaryDark, primaryMid],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 30),
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 48,
                            backgroundColor: Colors.white.withValues(alpha: 0.2),
                            backgroundImage: _getAvatarUrl(user?.avatarUrl) != null
                                ? CachedNetworkImageProvider(_getAvatarUrl(user!.avatarUrl)!)
                                : null,
                            child: _getAvatarUrl(user?.avatarUrl) == null
                                ? const Icon(Icons.person_rounded, size: 52, color: Colors.white)
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: () => _showEditProfileSheet(context, ref, user, primary),
                              child: Container(
                                width: 28,
                                height: 28,
                                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                child: Icon(Icons.camera_alt_rounded, size: 16, color: primary),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            user?.name ?? 'Nama Pengguna',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white),
                          ),
                          if (isVerified) ...[
                            const SizedBox(width: 6),
                            GestureDetector(
                              onTap: AppConfig.isKycRequired
                                  ? () => context.push('/kyc-benefits')
                                  : null,
                              child: const Icon(Icons.verified_rounded, color: Colors.white, size: 18),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user?.email ?? 'email@example.com',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13),
                      ),
                      if (user?.whatsappNumber != null && user!.whatsappNumber.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.phone_android_rounded, color: Colors.white.withValues(alpha: 0.8), size: 13),
                            const SizedBox(width: 4),
                            Text(
                              user.whatsappNumber,
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          isRunner ? '🏃 Runner' : '📦 Penitip',
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (userLocation != null) ...[
                        GestureDetector(
                          onTap: () {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (context) => LocationDetailSheet(
                                location: userLocation,
                                address: userAddressAsync.value ?? '',
                                primaryColor: primary,
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            margin: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.location_on_rounded, color: Colors.white, size: 14),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${userLocation.latitude.toStringAsFixed(6)}, ${userLocation.longitude.toStringAsFixed(6)}',
                                      style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(width: 8),
                                    GestureDetector(
                                      onTap: () => ref.read(userLocationProvider.notifier).updateLocation(),
                                      child: const Icon(Icons.refresh_rounded, color: Colors.white, size: 14),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                userAddressAsync.when(
                                  data: (address) => Text(
                                    address ?? 'Mencari detail lokasi...',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                                  ),
                                  error: (_, __) => const Text(
                                    'Gagal memuat detail lokasi',
                                    style: TextStyle(color: Colors.white70, fontSize: 12),
                                  ),
                                  loading: () => const SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ] else ...[
                        GestureDetector(
                          onTap: () => ref.read(userLocationProvider.notifier).updateLocation(),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 1),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.my_location_rounded, color: Colors.white, size: 14),
                                SizedBox(width: 6),
                                Text(
                                  'Dapatkan Lokasi Saya',
                                  style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.07), blurRadius: 20, offset: const Offset(0, 4))],
              ),
              child: Row(
                children: [
                  _StatItem(value: tripState.myTrips.length.toString(), label: 'Total Trip', color: primary),
                  _StatDivider(),
                  _StatItem(value: '${user?.trustScore ?? 100}%', label: 'Skor Kepercayaan', color: primary),
                  _StatDivider(),
                  _StatItem(value: formatCompact(walletState.wallet?.balance ?? 0), label: 'Dompet', color: primary),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionLabel('Akun'),
                  _MenuItem(
                    icon: Icons.person_outline_rounded,
                    label: 'Ubah Profil',
                    color: primary,
                    onTap: () => _showEditProfileSheet(context, ref, user, primary),
                  ),
                  _MenuItem(
                    icon: Icons.notifications_none_rounded,
                    label: 'Notifikasi',
                    color: primary,
                    onTap: () => context.push('/notifications'),
                  ),
                  _MenuItem(
                    icon: Icons.fingerprint_rounded, 
                    label: 'Biometrik (FaceID/Fingerprint)', 
                    color: primary, 
                    onTap: () {},
                    trailing: Switch(
                      value: ref.watch(biometricProvider).isEnabled,
                      onChanged: (val) async {
                        if (val) {
                          final authenticated = await ref.read(biometricProvider.notifier).authenticate(
                            reason: 'Verifikasi biometrik untuk mengaktifkan fitur ini',
                          );
                          if (authenticated) {
                            if (context.mounted) {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (context) => PinInputSheet(
                                  title: 'Konfirmasi PIN untuk Biometrik',
                                  onConfirm: (pin) async {
                                    await ref.read(biometricProvider.notifier).toggleEnabled(true, pin: pin);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Biometrik berhasil diaktifkan')),
                                      );
                                    }
                                  },
                                ),
                              );
                            }
                          }
                        } else {
                          await ref.read(biometricProvider.notifier).toggleEnabled(false);
                        }
                      },
                      activeThumbColor: primary,
                    ),
                  ),
                  _MenuItem(
                    icon: Icons.lock_outline_rounded,
                    label: 'Keamanan (PIN)',
                    color: primary,
                    onTap: () => _showSecuritySheet(context, primary, user),
                  ),
                  _MenuItem(
                    icon: Icons.info_outline_rounded,
                    label: 'Tentang Nitip',
                    color: primary,
                    onTap: () => _showAboutDialog(context, primary),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await ref.read(authProvider.notifier).logout();
                        if (context.mounted) context.go('/');
                      },
                      icon: const Icon(Icons.logout_rounded, size: 18),
                      label: const Text('Keluar dari Aplikasi', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditProfileSheet(BuildContext context, WidgetRef ref, User? user, Color primary) {
    final nameController = TextEditingController(text: user?.name);
    final whatsappController = TextEditingController(text: user?.whatsappNumber);
    final addressController = TextEditingController(text: user?.homeAddress);
    String? localAvatarPath;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, sheetSetState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 30),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Ubah Profil',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      // Avatar Pick Area
                      Center(
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 48,
                              backgroundColor: Colors.grey.shade100,
                              backgroundImage: localAvatarPath != null
                                  ? FileImage(File(localAvatarPath!))
                                  : (_getAvatarUrl(user?.avatarUrl) != null
                                      ? CachedNetworkImageProvider(_getAvatarUrl(user!.avatarUrl)!) as ImageProvider
                                      : null),
                              child: localAvatarPath == null && _getAvatarUrl(user?.avatarUrl) == null
                                  ? Icon(Icons.person_rounded, size: 52, color: Colors.grey.shade400)
                                  : null,
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: GestureDetector(
                                onTap: () async {
                                  final picker = ImagePicker();
                                  final pickedFile = await picker.pickImage(
                                    source: ImageSource.gallery,
                                    imageQuality: 80,
                                  );
                                  if (pickedFile != null) {
                                    sheetSetState(() {
                                      localAvatarPath = pickedFile.path;
                                    });
                                  }
                                },
                                child: Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: primary,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                  child: const Icon(Icons.camera_alt_rounded, size: 14, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      const Text(
                        'Nama Lengkap',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textMuted),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: nameController,
                        decoration: InputDecoration(
                          hintText: 'Nama lengkap Anda',
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: primary, width: 2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      const Text(
                        'Nomor WhatsApp',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textMuted),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: whatsappController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          hintText: 'Contoh: 08123456789',
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: primary, width: 2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      const Text(
                        'Alamat Rumah',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textMuted),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: addressController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText: 'Alamat rumah utama Anda',
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: primary, width: 2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () async {
                            final name = nameController.text.trim();
                            final wa = whatsappController.text.trim();
                            final addr = addressController.text.trim();

                            if (name.isEmpty || wa.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Nama dan Nomor WhatsApp wajib diisi'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              return;
                            }

                            Navigator.pop(context); // Close sheet
                            
                            // Show loading indicator overlay
                            showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (_) => const Center(
                                child: CircularProgressIndicator(),
                              ),
                            );

                            try {
                              await ref.read(authProvider.notifier).updateProfile(
                                name: name,
                                whatsappNumber: wa,
                                homeAddress: addr,
                                avatarPath: localAvatarPath,
                              );
                              if (context.mounted) {
                                Navigator.pop(context); // Pop loading dialog
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    backgroundColor: primary,
                                    content: const Text('Profil Anda berhasil diperbarui'),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                Navigator.pop(context); // Pop loading dialog
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    backgroundColor: Colors.red,
                                    content: Text('Gagal memperbarui profil: $e'),
                                  ),
                                );
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Simpan Perubahan', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showSecuritySheet(BuildContext context, Color primary, User? user) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Keamanan & Privasi',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Icon(Icons.pin_rounded, color: primary),
                title: Text(
                  (user?.hasPin ?? false) ? 'Ubah PIN Transaksi' : 'Atur PIN Transaksi',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  (user?.hasPin ?? false)
                      ? 'Ubah PIN 6-digit keamanan dompet Anda'
                      : 'Buat PIN 6-digit untuk mengamankan transaksi',
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.pop(context);
                  if (user?.hasPin ?? false) {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const ChangePinPage()));
                  } else {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const PinSetupPage()));
                  }
                },
              ),
              const Divider(),
              ListTile(
                leading: Icon(Icons.phonelink_lock_rounded, color: primary),
                title: const Text('Perangkat Terhubung', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Info perangkat & sesi login saat ini'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.pop(context);
                  _showDeviceInfoSheet(context, primary);
                },
              ),
              const Divider(),
              ListTile(
                leading: Icon(Icons.privacy_tip_rounded, color: primary),
                title: const Text('Kebijakan Privasi', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Lihat data apa saja yang kami amankan'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.pop(context);
                  _showPrivacyPolicySheet(context, primary);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showDeviceInfoSheet(BuildContext context, Color primary) async {
    String platformName = 'Tidak diketahui';
    String deviceModel = '-';
    String deviceId = '-';

    try {
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final info = await deviceInfo.androidInfo;
        platformName = 'Android';
        deviceModel = '${info.brand} ${info.model}';
        deviceId = info.id;
      } else if (Platform.isIOS) {
        final info = await deviceInfo.iosInfo;
        platformName = 'iOS';
        deviceModel = '${info.name} ${info.model}';
        deviceId = info.identifierForVendor ?? '-';
      }
    } catch (_) {}

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Perangkat Terhubung',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: primary.withValues(alpha: 0.15)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Platform.isAndroid ? Icons.android_rounded : Icons.phone_iphone_rounded,
                        color: primary,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            deviceModel,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$platformName • Perangkat ini',
                            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text('Aktif', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.success)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _InfoRow(label: 'Platform', value: platformName),
                    const SizedBox(height: 8),
                    _InfoRow(label: 'Model', value: deviceModel),
                    const SizedBox(height: 8),
                    _InfoRow(label: 'Device ID', value: deviceId.length > 20 ? '${deviceId.substring(0, 20)}...' : deviceId),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Saat ini hanya satu perangkat yang aktif. Login dari perangkat baru akan menggantikan sesi ini.',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted.withValues(alpha: 0.7), height: 1.4),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: primary,
                    side: BorderSide(color: primary.withValues(alpha: 0.3)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Tutup', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showPrivacyPolicySheet(BuildContext context, Color primary) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  // Handle bar
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Kebijakan Privasi',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  const Divider(),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                      children: [
                        _PolicySection(
                          title: '1. Data yang Kami Kumpulkan',
                          content: 'Kami mengumpulkan data berikut untuk menyediakan layanan Nitip:\n'
                              '• Informasi profil (nama, email, nomor WhatsApp)\n'
                              '• Lokasi saat Anda aktif sebagai Runner\n'
                              '• Data transaksi dan pesanan\n'
                              '• Foto bukti pengiriman dan KYC',
                          icon: Icons.data_usage_rounded,
                          color: primary,
                        ),
                        _PolicySection(
                          title: '2. Penggunaan Data',
                          content: 'Data Anda digunakan untuk:\n'
                              '• Menghubungkan Penitip dengan Runner terdekat\n'
                              '• Memproses pembayaran dan dompet digital\n'
                              '• Verifikasi identitas (KYC) untuk keamanan\n'
                              '• Meningkatkan kualitas layanan',
                          icon: Icons.analytics_rounded,
                          color: primary,
                        ),
                        _PolicySection(
                          title: '3. Perlindungan Data',
                          content: 'Kami melindungi data Anda dengan:\n'
                              '• Enkripsi end-to-end untuk PIN dan password\n'
                              '• Autentikasi JWT dengan token rotation\n'
                              '• Proteksi screenshot pada halaman sensitif\n'
                              '• Rate limiting untuk mencegah brute force',
                          icon: Icons.shield_rounded,
                          color: primary,
                        ),
                        _PolicySection(
                          title: '4. Berbagi Data',
                          content: 'Kami TIDAK menjual data Anda kepada pihak ketiga. Data hanya dibagikan:\n'
                              '• Antar pengguna yang terlibat transaksi (nama, kontak)\n'
                              '• Kepada admin untuk penyelesaian sengketa',
                          icon: Icons.share_rounded,
                          color: primary,
                        ),
                        _PolicySection(
                          title: '5. Hak Anda',
                          content: 'Anda memiliki hak untuk:\n'
                              '• Mengakses dan memperbarui data profil\n'
                              '• Menghapus akun (hubungi admin)\n'
                              '• Menonaktifkan lokasi kapan saja',
                          icon: Icons.gavel_rounded,
                          color: primary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Terakhir diperbarui: 10 Juni 2026',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11, color: AppColors.textMuted.withValues(alpha: 0.6)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showAboutDialog(BuildContext context, Color primary) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.rocket_launch_rounded, color: primary, size: 40),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Nitip Mobile',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
                const Text(
                  'Versi 2.0.0 (MVP v2)',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Aplikasi khusus Runner yang dioptimalkan untuk performa tinggi, efisiensi memori, dan kemudahan pengiriman barang secara instan.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.black87, height: 1.4),
                ),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 8),
                const Text(
                  'Powered by Google DeepMind\nAdvanced Agentic Coding',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w600, height: 1.4),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: const Text('Tutup', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StatItem extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  const _StatItem({required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
          ],
        ),
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 32, color: AppColors.border);
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Text(label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 0.8)),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final Widget? trailing;
  const _MenuItem({required this.icon, required this.label, required this.color, required this.onTap, this.trailing});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A))),
      trailing: trailing ?? const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted, size: 20),
      onTap: onTap,
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w500)),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
          ),
        ),
      ],
    );
  }
}

class _PolicySection extends StatelessWidget {
  final String title;
  final String content;
  final IconData icon;
  final Color color;

  const _PolicySection({
    required this.title,
    required this.content,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              content,
              style: const TextStyle(fontSize: 13, color: Color(0xFF475569), height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
