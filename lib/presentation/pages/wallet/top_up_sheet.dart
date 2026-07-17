import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../providers/wallet_provider.dart';
import 'top_up_receipt.dart';

// ── Preset amounts ───────────────────────────────────────────────────────────
const _presets = [10000, 25000, 50000, 100000, 200000, 500000];

/// Tampilkan TopUpSheet sebagai modal bottom sheet.
Future<void> showTopUpSheet(BuildContext context, WidgetRef ref, Color primary) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    useRootNavigator: true,
    builder: (_) => _TopUpSheet(primary: primary, ref: ref),
  );
}

// ── Sheet Widget ─────────────────────────────────────────────────────────────
class _TopUpSheet extends StatefulWidget {
  final Color primary;
  final WidgetRef ref;
  const _TopUpSheet({required this.primary, required this.ref});

  @override
  State<_TopUpSheet> createState() => _TopUpSheetState();
}

class _TopUpSheetState extends State<_TopUpSheet>
    with SingleTickerProviderStateMixin {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  late AnimationController _animCtrl;
  late Animation<double> _fadeIn;

  int? _selectedPreset;
  bool _isLoading = false;
  String? _error;

  final _fmt = NumberFormat('#,##0', 'id_ID');

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _fadeIn = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _animCtrl.dispose();
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
    // Strip non-digit dan reformat
    final raw = value.replaceAll('.', '').replaceAll(',', '');
    final num = int.tryParse(raw);
    if (num != null) {
      final formatted = _fmt.format(num);
      _controller.value = _controller.value.copyWith(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }
    setState(() {
      _selectedPreset = null;
      _error = null;
    });
  }

  Future<void> _submit() async {
    final amount = _amount;
    if (amount == null || amount < 10000) {
      setState(() => _error = 'Minimum top up adalah Rp 10.000');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final tx = await widget.ref.read(walletProvider.notifier).topUp(amount);
      if (mounted) {
        if (tx != null) {
          Navigator.pop(context); // tutup sheet input
          // Tampilkan receipt jika ada data transaksi
          await showTopUpReceipt(context, tx);
          // Setelah receipt ditutup (user sudah bayar QRIS atau close), refresh saldo
          if (mounted) {
            widget.ref.read(walletProvider.notifier).refreshAfterTransaction();
          }
        } else {
          // Jika tx null, ambil error dari state notifier
          final walletState = widget.ref.read(walletProvider);
          setState(() {
            _isLoading = false;
            _error = walletState.error?.replaceAll('Exception: ', '') ?? 'Gagal melakukan top up';
          });
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final primary = widget.primary;
    final secondary = AppColors.primaryMid;

    return FadeTransition(
      opacity: _fadeIn,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Handle bar ────────────────────────────────────────────────
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
            ),

            // ── Header ────────────────────────────────────────────────────
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [primary, secondary]),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.add_rounded, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Top Up Saldo',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                    Text('Tambah saldo Nitip Pay kamu',
                        style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 28),

            // ── Nominal label ─────────────────────────────────────────────
            const Text('Nominal Top Up',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF374151))),
            const SizedBox(height: 12),

            // ── Custom input ──────────────────────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _focusNode.hasFocus ? primary : AppColors.border,
                  width: _focusNode.hasFocus ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text('Rp',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: primary,
                        )),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                      decoration: InputDecoration(
                        hintText: '0',
                        hintStyle: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w700, color: Colors.grey[300]),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 18),
                      ),
                      onChanged: _onTyped,
                      onTap: () => setState(() {}),
                    ),
                  ),
                  if (_controller.text.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        _controller.clear();
                        setState(() {
                          _selectedPreset = null;
                          _error = null;
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: AppColors.border,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close, size: 14, color: AppColors.textMuted),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // ── Error ─────────────────────────────────────────────────────
            if (_error != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.info_outline_rounded, size: 14, color: AppColors.error),
                  const SizedBox(width: 6),
                  Text(_error!,
                      style: const TextStyle(fontSize: 12, color: AppColors.error, fontWeight: FontWeight.w500)),
                ],
              ),
            ],

            const SizedBox(height: 20),

            // ── Preset chips ──────────────────────────────────────────────
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _presets.map((p) {
                final selected = _selectedPreset == p;
                return GestureDetector(
                  onTap: () => _selectPreset(p),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: selected ? primary.withValues(alpha: 0.1) : AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected ? primary : AppColors.border,
                        width: selected ? 1.5 : 1,
                      ),
                    ),
                    child: Text(
                      'Rp ${_fmt.format(p)}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: selected ? primary : AppColors.textMuted,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 28),

            // ── Info banner ───────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFED7AA)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFFEA580C)),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Saldo akan aktif setelah dikonfirmasi oleh admin.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF9A3412), fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── CTA Button ────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 54,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: primary.withValues(alpha: 0.5),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.add_rounded, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              _amount != null && _amount! > 0
                                  ? 'Top Up Rp ${_fmt.format(_amount!)}'
                                  : 'Masukkan Nominal',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
