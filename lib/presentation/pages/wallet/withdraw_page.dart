import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/config/app_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../providers/biometric_provider.dart';
import '../../providers/notification_provider.dart';
import '../../../domain/models/wallet_model.dart';
import '../../widgets/wallet/withdraw_inquiry_card.dart';
import '../../widgets/wallet/pin_input_sheet.dart';
import '../auth/pin_setup_page.dart';
import 'top_up_receipt.dart';

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
  String _selectedType = 'TRANSFER'; // 'TRANSFER' or 'CASH'

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
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(walletProvider.notifier).fetchTransactions();
    });
  }

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

    final bankAccount = ref.read(userBankAccountProvider).value;
    final accountNo = bankAccount?.accountNo ?? _accountController.text;
    final accountName = bankAccount?.accountName ?? _inquiryName;

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
              'account_no': accountNo,
              'account_name': accountName,
            },
          );
      if (mounted) {
        if (tx != null) {
          ref.read(notificationProvider.notifier).fetchNotifications(playSound: true);
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



  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final walletState = ref.watch(walletProvider);
    final isRunner = authState.user?.isRunner ?? false;
    final primary = isRunner ? AppColors.secondary : AppColors.primary;
    final secondary = isRunner ? AppColors.secondaryDark : AppColors.primaryDark;

    final pendingWithdrawals = walletState.transactions.where(
      (tx) => tx.type == 'WITHDRAWAL' && tx.status == 'pending',
    ).toList();

    final bankAccountAsync = ref.watch(userBankAccountProvider);
    final channelsAsync = ref.watch(withdrawalChannelsProvider);

    // Auto-select channel based on _selectedType and bank account
    bankAccountAsync.whenData((bankAccount) {
      channelsAsync.whenData((channels) {
        if (channels.isNotEmpty) {
          if (_selectedType == 'TRANSFER') {
            if (bankAccount != null) {
              final matched = channels.firstWhere(
                (ch) => ch.code.toLowerCase() == bankAccount.bankName.toLowerCase(),
                orElse: () => channels.first,
              );
              if (_selectedChannel?.id != matched.id) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  setState(() => _selectedChannel = matched);
                });
              }
            }
          } else if (_selectedType == 'CASH') {
            final matched = channels.firstWhere(
              (ch) => ch.code.toLowerCase() == 'manual',
              orElse: () => channels.first,
            );
            if (_selectedChannel?.id != matched.id) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                setState(() => _selectedChannel = matched);
              });
            }
          }
        }
      });
    });

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
      body: bankAccountAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Gagal memuat rekening terdaftar: $err')),
        data: (bankAccount) {
          if (bankAccount == null) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 48),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Rekening Belum Terdaftar',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Pendaftaran rekening tujuan pencairan dana hanya dapat dilakukan oleh admin demi alasan keamanan. Silakan hubungi admin atau CS untuk mendaftarkan rekening Anda.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Color(0xFF64748B), height: 1.5, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text('Kembali', style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ),
                ],
              ),
            );
          }

          // Pre-populate read-only account credentials so submit handles them correctly!
          _accountController.text = bankAccount.accountNo;
          _inquiryName = bankAccount.accountName;

          return GestureDetector(
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

                  // ── Pending Withdrawal Progress Card ────────────────────────
                  if (pendingWithdrawals.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(
                                    color: AppColors.warning,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.schedule_rounded, color: Colors.white, size: 14),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    pendingWithdrawals.length > 1
                                        ? 'Pencairan Sedang Diproses (${pendingWithdrawals.length})'
                                        : 'Penarikan Sedang Diproses',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: pendingWithdrawals.length,
                              separatorBuilder: (context, index) => const Padding(
                                padding: EdgeInsets.symmetric(vertical: 10),
                                child: Divider(height: 1, color: Color(0xFFE2E8F0)),
                              ),
                              itemBuilder: (context, index) {
                                final tx = pendingWithdrawals[index];
                                final isManual = tx.destinationMetadata?['code']?.toString().toLowerCase() == 'manual' || tx.destinationMetadata?['account_name'] == null;
                                return InkWell(
                                  onTap: () => showTopUpReceipt(context, tx),
                                  borderRadius: BorderRadius.circular(12),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Rp ${_fmt.format(tx.amount.abs())}',
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w900,
                                                  color: Color(0xFF1E293B),
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                isManual
                                                    ? 'Tarik Tunai / Cash'
                                                    : '${tx.destinationMetadata?['bank_name'] ?? 'Transfer'} (${tx.destinationMetadata?['account_no']})',
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: Color(0xFF64748B),
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8), size: 18),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 12),
                            const Divider(height: 1, color: Color(0xFFE2E8F0)),
                            const SizedBox(height: 10),
                            const Text(
                              'Ketuk salah satu baris untuk melihat struk / detail tiket progress pencairan.',
                              style: TextStyle(
                                fontSize: 10.5,
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w600,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7), // bg-amber-100
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFFDE68A)), // border-amber-200
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded, color: Color(0xFFD97706), size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Pencairan dana menggunakan transfer manual ke rekening Anda dengan estimasi waktu maksimal 1x12 jam.\nJadwal pencairan: ${AppConfig.withdrawalSchedule}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFB45309), // text-amber-700
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

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

                  // ── Segmented Selector for Transfer vs Cash ────────────────
                  const Text('Metode Pencairan',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9), // slate-100
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _selectedType = 'TRANSFER';
                              });
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: _selectedType == 'TRANSFER' ? Colors.white : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: _selectedType == 'TRANSFER'
                                    ? [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.05),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                'Transfer Rekening',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: _selectedType == 'TRANSFER' ? const Color(0xFF1E293B) : const Color(0xFF64748B),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _selectedType = 'CASH';
                              });
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: _selectedType == 'CASH' ? Colors.white : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: _selectedType == 'CASH'
                                    ? [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.05),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                'Tarik Tunai (Cash)',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: _selectedType == 'CASH' ? const Color(0xFF1E293B) : const Color(0xFF64748B),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (_selectedType == 'CASH') ...[
                    channelsAsync.when(
                      data: (channels) {
                        return Container(
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
                                  child: Icon(
                                    _selectedChannel!.code.toLowerCase() == 'manual'
                                        ? Icons.payments_outlined
                                        : Icons.account_balance,
                                    color: primary,
                                    size: 18,
                                  ),
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
                              ],
                              const Icon(Icons.lock_outline, color: Color(0xFF94A3B8), size: 18),
                            ],
                          ),
                        );
                      },
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (e, _) => Center(child: Text('Gagal memuat metode: $e')),
                    ),
                    const SizedBox(height: 24),
                  ],

                  if (_selectedChannel != null && _selectedType == 'TRANSFER') ...[
                    const SizedBox(height: 24),
                    const Text(
                      'Rekening Tujuan Terdaftar',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                    ),
                    const SizedBox(height: 12),
                    WithdrawInquiryCard(
                      accountName: bankAccount.accountName,
                      accountNo: bankAccount.accountNo,
                      bankName: bankAccount.bankName,
                      logoPath: _brandLogos[bankAccount.bankName.toUpperCase()],
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
                      onPressed: _isLoading ? null : _handleWithdrawal,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        elevation: 8,
                        shadowColor: primary.withValues(alpha: 0.4),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Tarik Saldo', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

