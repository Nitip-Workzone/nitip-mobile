import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:screen_protector/screen_protector.dart';
import '../../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/app_snackbar.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isObscured = true;

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
    _nameController.dispose();
    _emailController.dispose();
    _whatsappController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _validateName(String? value) {
    if (value == null || value.isEmpty) return 'Nama tidak boleh kosong';
    if (value.length < 2) return 'Nama minimal 2 karakter';
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) return 'Email tidak boleh kosong';
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) return 'Format email tidak valid';
    return null;
  }

  String? _validateWhatsapp(String? value) {
    if (value == null || value.isEmpty) return 'Nomor WhatsApp tidak boleh kosong';
    final numericRegex = RegExp(r'^[0-9]+$');
    if (!numericRegex.hasMatch(value)) return 'Nomor WhatsApp harus berupa angka';
    if (value.length < 9 || value.length > 15) return 'Nomor WhatsApp harus berukuran 9-15 digit';
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Kata sandi tidak boleh kosong';
    if (value.length < 8) return 'Kata sandi minimal 8 karakter';
    return null;
  }

  void _handleRegister() async {
    if (_formKey.currentState!.validate()) {
      await ref.read(authProvider.notifier).register(
            name: _nameController.text,
            email: _emailController.text,
            password: _passwordController.text,
            role: 'runner',
            whatsappNumber: _whatsappController.text,
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    // Listen for error or success
    ref.listen(authProvider, (previous, next) {
      if (next.error != null) {
        AppSnackBar.showError(context, next.error!);
      } else if (next.isAuthenticated) {
        context.go('/dashboard');
      }
    });

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: SingleChildScrollView(
          child: Stack(
            children: [
              // Inverse Slanted Blue Background
              ClipPath(
                clipper: _InverseHeaderClipper(),
                child: Container(
                  height: MediaQuery.of(context).size.height * 0.55,
                  color: AppColors.primary,
                ),
              ),
              
              SafeArea(
                child: Column(
                  children: [
                    const SizedBox(height: 32),
                    // Header Text
                    const Text('Daftar', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 8),
                    const Text('Silakan daftar untuk melanjutkan', style: TextStyle(color: Colors.white70, fontSize: 14)),
                    const SizedBox(height: 32),
                    
                    // Floating Card
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 24),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Name
                            const Text('Nama Lengkap', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 13)),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _nameController,
                              validator: _validateName,
                              decoration: InputDecoration(
                                hintText: 'Budi Santoso',
                                hintStyle: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.5)),
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              ),
                            ),
                            const SizedBox(height: 16),
                            
                            // Email
                            const Text('Alamat Email', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 13)),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _emailController,
                              validator: _validateEmail,
                              decoration: InputDecoration(
                                hintText: 'email@gmail.com',
                                hintStyle: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.5)),
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              ),
                              keyboardType: TextInputType.emailAddress,
                            ),
                            const SizedBox(height: 16),

                            // WhatsApp Number
                            const Text('Nomor WhatsApp', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 13)),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _whatsappController,
                              validator: _validateWhatsapp,
                              decoration: InputDecoration(
                                hintText: '081234567890',
                                hintStyle: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.5)),
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              ),
                              keyboardType: TextInputType.phone,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            ),
                            const SizedBox(height: 16),
                            
                            // Password
                            const Text('Kata Sandi', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 13)),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _passwordController,
                              validator: _validatePassword,
                              obscureText: _isObscured,
                              decoration: InputDecoration(
                                hintText: '••••••••••••',
                                hintStyle: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.5)),
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                suffixIcon: IconButton(
                                  icon: Icon(_isObscured ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20, color: AppColors.textMuted),
                                  onPressed: () => setState(() => _isObscured = !_isObscured),
                                ),
                              ),
                            ),
                            
                            const SizedBox(height: 40),
                            
                            // Register Button
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: ElevatedButton(
                                onPressed: authState.isLoading ? null : _handleRegister,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  elevation: 0,
                                ),
                                child: authState.isLoading
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                      )
                                    : const Text('Daftar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              ),
                            ),
                            
                            const SizedBox(height: 24),
                            
                            // Or Divider
                            Row(
                              children: [
                                Expanded(child: Divider(color: AppColors.border)),
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 16),
                                  child: Text('Atau', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                                ),
                                Expanded(child: Divider(color: AppColors.border)),
                              ],
                            ),
                            const SizedBox(height: 24),
                            
                            // Social Buttons
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _SocialButton(iconData: Icons.g_mobiledata, color: Colors.red, enabled: false, onTap: () {}),
                                const SizedBox(width: 16),
                                _SocialButton(iconData: Icons.facebook, color: Colors.blue, enabled: false, onTap: () {}),
                                const SizedBox(width: 16),
                                _SocialButton(iconData: Icons.apple, color: Colors.black, enabled: false, onTap: () {}),
                              ],
                            ),
                            
                            const SizedBox(height: 32),
                            
                            // Login
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text("Sudah punya akun? ", style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                                GestureDetector(
                                  onTap: () => context.pushReplacement('/login'),
                                  child: const Text('Masuk', style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
              
              // Back Button Overlay
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.only(left: 8.0, top: 8.0),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                    onPressed: () => context.pop(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InverseHeaderClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height * 0.55); // Left side higher
    path.lineTo(size.width, size.height * 0.75); // Right side lower
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _SocialButton extends StatelessWidget {
  final IconData iconData;
  final Color color;
  final VoidCallback onTap;
  final bool enabled;

  const _SocialButton({
    required this.iconData,
    required this.color,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: enabled ? Colors.white : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(12),
          boxShadow: enabled ? [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ] : null,
        ),
        child: Icon(
          iconData,
          color: enabled ? color : Colors.grey.shade400,
          size: 28,
        ),
      ),
    );
  }
}
