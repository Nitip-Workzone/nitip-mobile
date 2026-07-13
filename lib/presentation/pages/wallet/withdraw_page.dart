import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/config/app_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../providers/biometric_provider.dart';
import '../../../domain/models/wallet_model.dart';
import '../../widgets/wallet/withdraw_inquiry_card.dart';
import '../../widgets/wallet/pin_input_sheet.dart';
import '../auth/pin_setup_page.dart';

class WithdrawPage extends ConsumerStatefulWidget {
  const WithdrawPage({super.key});

  @override
  ConsumerState<WithdrawPage> createState() => _WithdrawPageState();
}

class _WithdrawPageState extends ConsumerState<WithdrawPage> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _fmt = NumberFormat('#,##0', 'id_ID');
  
  bool _isLoading = false;
  String? _error;
  int? _selectedPreset;
  WithdrawalChannelModel? _selectedChannel;
  final _accountController = TextEditingController();
  String? _inquiryName;
  bool _isInquiring = false;

  final _presets = [50000, 100000, 200000, 500000, 1000000];

  final Map<String, String> _brandLogos = {
    'BCA': 'assets/images/providers/bca.png',
    'MANDIRI': 'assets/images/providers/mandiri.png',
    'BNI': 'assets/images/providers/bni.png',
    'BRI': 'assets/images/providers/bri.png',
    'GOPAY': 'assets/images/providers/gopay.png',
    'OVO': 'assets/images/providers/ovo.png',
    'DANA': 'assets/images/providers/dana.png',
    'SHOPEEPAY': 'assets/images/providers/shopeepay.png',
  };

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _accountController.dispose();
    super.dispose();
  }

  double? get _amount {
    final raw = _controller.text.replaceAll('.', '').replaceAll(',', '');
    return double.tryParse(raw);
  }

  void _selectPreset(int value) {
    setState(() {
      _selectedPreset = value;
      _error = null;
    });
    _controller.text = _fmt.format(value);
    _focusNode.unfocus();
  }

  void _onTyped(String value) {
    if (value.isEmpty) {
      setState(() {
        _selectedPreset = null;
        _error = null;
      });
      return;
    }
    final raw = value.replaceAll('.', '').replaceAll(',', '');
    final num = int.tryParse(raw);
    if (num != null) {
      final formatted = _fmt.format(num);
      if (_controller.text != formatted) {
        _controller.value = _controller.value.copyWith(
          text: formatted,
          selection: TextSelection.collapsed(offset: formatted.length),
        );
      }
    }
    setState(() {
      _selectedPreset = null;
      _error = null;
    });
  }

  Future<void> _doInquiry() async {
    final amount = _amount;
    final wallet = ref.read(walletProvider).wallet;

    if (_selectedChannel == null) {
      setState(() => _error = 'Pilih metode penarikan terlebih dahulu');
      return;
    }

    if (_accountController.text.isEmpty) {
      setState(() => _error = 'Nomor rekening/HP wajib diisi');
      return;
    }

    final authState = ref.read(authProvider);
    final isKyc = !AppConfig.isKycRequired || authState.kycStatus == 'approved';
    final dynamicMin = isKyc ? 10000.0 : 50000.0;
    final effectiveMin = _selectedChannel!.minAmount > dynamicMin ? _selectedChannel!.minAmount : dynamicMin;

    if (amount == null || amount < effectiveMin) {
      setState(() => _error = 'Min. penarikan Rp ${_fmt.format(effectiveMin)} ${isKyc ? "" : "(Belum e-KYC)"}');
      return;
    }

    final adminFee = _selectedChannel!.adminFeeFlat + (amount * _selectedChannel!.adminFeePercent / 100);
    final totalDeduction = amount + adminFee;

    if (wallet != null && totalDeduction > wallet.balance) {
      setState(() => _error = 'Saldo tidak mencukupi');
      return;
    }

    setState(() {
      _isInquiring = true;
      _error = null;
    });

    try {
      final name = await ref.read(walletProvider.notifier).inquiryAccount(
            channelCode: _selectedChannel!.code,
            accountNo: _accountController.text,
          );
      if (mounted) {
        if (name != null) {
          setState(() {
            _inquiryName = name;
            _isInquiring = false;
          });
        } else {
          setState(() {
            _isInquiring = false;
            _error = 'Rekening tidak ditemukan atau salah';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isInquiring = false;
          _error = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  Future<void> _handleWithdrawal() async {
    final authUser = ref.read(authProvider).user;
    if (authUser == null) return;

    if (!authUser.hasPin) {
      // Setup PIN first
      final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const PinSetupPage()),
      );
      if (result is String) {
        // After setup, directly submit using the new PIN
        _submit(result);
      }
      return;
    }

    // Try Biometric if enabled
    final bioState = ref.read(biometricProvider);
    if (bioState.isEnabled) {
      final authenticated = await ref.read(biometricProvider.notifier).authenticate(
            reason: 'Verifikasi biometrik untuk penarikan saldo',
          );
      if (authenticated) {
        final savedPin = await ref.read(biometricProvider.notifier).getSavedPin();
        if (savedPin != null) {
          _submit(savedPin);
          return;
        }
      }
    }

    // Fallback to PIN Sheet
    _showPinSheet();
  }

  void _showPinSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PinInputSheet(
        onConfirm: (pin) => _submit(pin),
      ),
    );
  }

  Future<void> _submit(String pin) async {
    final amount = _amount;
    if (amount == null || _selectedChannel == null) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final tx = await ref.read(walletProvider.notifier).withdraw(
            amount: amount,
            channelId: _selectedChannel!.id,
            pin: pin,
            metadata: {
              'type': _selectedChannel!.type,
              'code': _selectedChannel!.code,
              'account_no': _accountController.text,
              'account_name': _inquiryName,
            },
          );
      if (mounted) {
        if (tx != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Permintaan penarikan berhasil diajukan'),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
            ),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showChannelSelector(List<WithdrawalChannelModel> channels, Color primary) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Pilih Metode Pencairan',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF1E293B)),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(context),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 24),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: channels.length,
                separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                itemBuilder: (context, index) {
                  final ch = channels[index];
                  final isSelected = _selectedChannel?.id == ch.id;
                  final logoAsset = _brandLogos[ch.code.toUpperCase()];
                  final isActive = ch.isActive;

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    leading: Container(
                      width: 48,
                      height: 48,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFF1F5F9)),
                      ),
                      child: logoAsset != null
                          ? Image.asset(logoAsset, fit: BoxFit.contain)
                          : Icon(ch.type == 'BANK' ? Icons.account_balance : Icons.smartphone, color: primary),
                    ),
                    title: Text(
                      ch.name,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isActive ? const Color(0xFF1E293B) : const Color(0xFF94A3B8),
                      ),
                    ),
                    subtitle: Text(
                      isActive ? ch.estimatedTime : 'Sedang tidak tersedia',
                      style: TextStyle(
                        fontSize: 12,
                        color: isActive ? const Color(0xFF64748B) : Colors.red,
                        fontWeight: isActive ? FontWeight.w500 : FontWeight.w700,
                      ),
                    ),
                    trailing: isSelected
                        ? Icon(Icons.check_circle, color: primary, size: 20)
                        : (isActive ? const Icon(Icons.chevron_right, size: 16, color: Color(0xFFCBD5E1)) : null),
                    onTap: isActive
                        ? () {
                            setState(() {
                              _selectedChannel = ch;
                              _inquiryName = null;
                              _error = null;
                            });
                            Navigator.pop(context);
                          }
                        : null,
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final walletState = ref.watch(walletProvider);
    final isRunner = authState.user?.isRunner ?? false;
    final primary = isRunner ? AppColors.secondary : AppColors.primary;
    final secondary = isRunner ? AppColors.secondaryDark : AppColors.primaryDark;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, size: 24),
          onPressed: () => Navigator.pop(context),
          color: const Color(0xFF1E293B),
        ),
        title: const Text(
          'Tarik Saldo',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
        ),
        centerTitle: true,
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Current Balance Card ──────────────────────────────────────
            Container(
              width: double.infinity,
              height: 140,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [primary, secondary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: primary.withValues(alpha: 0.25),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: -20,
                    right: -20,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text(
                                  'Saldo Tersedia',
                                  style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Rp ${_fmt.format(walletState.wallet?.balance ?? 0)}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 32,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1),
                          ),
                          child: const Icon(Icons.account_balance_wallet, color: Colors.white, size: 28),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // ── Amount Input ─────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Nominal Penarikan',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
                GestureDetector(
                  onTap: () {
                    final bal = walletState.wallet?.balance ?? 0;
                    _controller.text = _fmt.format(bal);
                    setState(() {
                      _selectedPreset = null;
                      _error = null;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Tarik Semua',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: primary),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
              ),
              child: Row(
                children: [
                  Text('Rp', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: primary)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Color(0xFF0F172A), letterSpacing: -1),
                      decoration: const InputDecoration(
                        hintText: '0',
                        hintStyle: TextStyle(color: Color(0xFFCBD5E1)),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                      autocorrect: false,
                      enableSuggestions: false,
                      onChanged: _onTyped,
                    ),
                  ),
                  if (_controller.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.cancel, color: Color(0xFF94A3B8), size: 20),
                      onPressed: () {
                        _controller.clear();
                        setState(() {
                          _selectedPreset = null;
                        });
                      },
                    ),
                ],
              ),
            ),

            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _presets.map((p) {
                  final selected = _selectedPreset == p;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      label: Text(_fmt.format(p)),
                      onPressed: () => _selectPreset(p),
                      backgroundColor: selected ? primary : Colors.white,
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: selected ? Colors.white : const Color(0xFF64748B),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(100),
                        side: BorderSide(color: selected ? primary : const Color(0xFFE2E8F0)),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 32),

            // ── Method Selection Dropdown ────────────────────────────────
            const Text('Metode Pencairan',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
            const SizedBox(height: 16),
            ref.watch(withdrawalChannelsProvider).when(
              data: (channels) => InkWell(
                onTap: () => _showChannelSelector(channels, primary),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      if (_selectedChannel != null) ...[
                        Container(
                          width: 36,
                          height: 36,
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFF1F5F9)),
                          ),
                          child: _brandLogos[_selectedChannel!.code.toUpperCase()] != null
                              ? Image.asset(_brandLogos[_selectedChannel!.code.toUpperCase()]!, fit: BoxFit.contain)
                              : Icon(Icons.account_balance, color: primary, size: 18),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _selectedChannel!.name,
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                              ),
                              Text(
                                _selectedChannel!.estimatedTime,
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        const Icon(Icons.account_balance, color: Color(0xFF94A3B8), size: 24),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Text(
                            'Pilih Metode Pencairan',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF94A3B8)),
                          ),
                        ),
                      ],
                      const Icon(Icons.keyboard_arrow_down, color: Color(0xFF94A3B8), size: 20),
                    ],
                  ),
                ),
              ),
              loading: () => Container(
                height: 60,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
              ),
              error: (e, _) => Center(child: Text('Gagal memuat metode: $e')),
            ),

            if (_selectedChannel != null) ...[
              const SizedBox(height: 24),
              Text(
                _selectedChannel!.type == 'BANK' ? 'Nomor Rekening' : 'Nomor HP ${_selectedChannel!.name}',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: TextField(
                  controller: _accountController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                  onChanged: (_) {
                    if (_inquiryName != null) {
                      setState(() => _inquiryName = null);
                    }
                  },
                  decoration: const InputDecoration(
                    hintText: 'Masukkan nomor...',
                    hintStyle: TextStyle(color: Color(0xFF94A3B8)),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                  autocorrect: false,
                  enableSuggestions: false,
                ),
              ),
            ],

            if (_inquiryName != null) ...[
              const SizedBox(height: 24),
              WithdrawInquiryCard(
                accountName: _inquiryName!,
                accountNo: _accountController.text,
                bankName: _selectedChannel!.name,
                logoPath: _brandLogos[_selectedChannel!.code.toUpperCase()],
              ),
            ],

            const SizedBox(height: 32),

            // ── Summary Section ──────────────────────────────────────────
            if (_selectedChannel != null && _amount != null && _amount! > 0) ...[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  children: [
                    _DetailRow(label: 'Nominal Penarikan', value: 'Rp ${_fmt.format(_amount)}'),
                    const SizedBox(height: 12),
                    _DetailRow(
                      label: 'Biaya Admin',
                      value: 'Rp ${_fmt.format(_selectedChannel!.adminFeeFlat + (_amount! * _selectedChannel!.adminFeePercent / 100))}',
                      isNegative: true,
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Divider(color: Color(0xFF334155), height: 1),
                    ),
                    _DetailRow(
                      label: 'Total Pemotongan',
                      value: 'Rp ${_fmt.format(_amount! + _selectedChannel!.adminFeeFlat + (_amount! * _selectedChannel!.adminFeePercent / 100))}',
                      isBold: true,
                    ),
                  ],
                ),
              ),
            ],

            if (_error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 16),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w700))),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 40),

            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: (_isLoading || _isInquiring) ? null : (_inquiryName == null ? _doInquiry : _handleWithdrawal),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  elevation: 8,
                  shadowColor: primary.withValues(alpha: 0.4),
                ),
                child: (_isLoading || _isInquiring)
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(_inquiryName == null ? 'Lanjutkan' : 'Konfirmasi & Tarik', 
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isNegative;
  final bool isBold;

  const _DetailRow({
    required this.label,
    required this.value,
    this.isNegative = false,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 14, color: const Color(0xFF94A3B8), fontWeight: isBold ? FontWeight.w700 : FontWeight.w500)),
        Text(
          isNegative ? '- $value' : value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w700,
            color: isNegative ? Colors.redAccent : Colors.white,
          ),
        ),
      ],
    );
  }
}
