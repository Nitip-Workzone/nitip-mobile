import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../providers/auth_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../providers/activity_provider.dart';
import '../../providers/create_order_provider.dart';
import '../../providers/location_provider.dart';
import '../../widgets/common/location_picker_sheet.dart';
import '../wallet/top_up_sheet.dart';


class TitipBeliPage extends ConsumerWidget {
  const TitipBeliPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(createOrderProvider);
    final notifier = ref.read(createOrderProvider.notifier);
    final isRunner = ref.watch(authProvider).user?.isRunner ?? false;
    final primary = isRunner ? AppColors.secondary : AppColors.primary;

    return PopScope(
      canPop: !state.showSummary,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && state.showSummary) {
          notifier.toggleSummary(false);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(
            state.showSummary ? 'Ringkasan Pesanan' : 'Titip Beli', 
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)
          ),
          centerTitle: true,
          backgroundColor: Colors.white,
          elevation: 0,
          foregroundColor: Colors.black,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (state.showSummary) {
                notifier.toggleSummary(false);
              } else {
                context.pop();
              }
            },
          ),
        ),
        body: state.showSummary 
          ? _buildSummaryView(context, ref, state, notifier, primary)
          : _buildFormView(context, ref, state, notifier, primary),
        bottomNavigationBar: _buildBottomAction(context, ref, state, notifier, primary),
      ),
    );
  }

  Widget _buildFormView(BuildContext context, WidgetRef ref, CreateOrderState state, CreateOrderNotifier notifier, Color primary) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Detail Barang'),
          const SizedBox(height: 12),
          _buildCard(
            child: Column(
              children: [
                _buildInputField(
                  label: 'Apa yang mau dititip?',
                  hint: 'Contoh: Kopi Susu Gula Aren (2 pcs)',
                  icon: Icons.shopping_bag_rounded,
                  initialValue: state.itemDetails,
                  onChanged: notifier.updateItemDetails,
                ),
                const SizedBox(height: 16),
                _buildInputField(
                  label: 'Estimasi Harga Barang',
                  hint: 'Berapa perkiraan harga belanjanya?',
                  icon: Icons.payments_rounded,
                  prefixText: 'Rp ',
                  initialValue: state.estimatedCost > 0 ? CurrencyFormatter.formatToIdr(state.estimatedCost) : '',
                  keyboardType: TextInputType.number,
                  inputFormatters: [CurrencyInputFormatter()],
                  onChanged: (val) => notifier.updateEstimatedCost(CurrencyFormatter.parseIdr(val)),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          _buildSectionTitle('Lokasi'),
          const SizedBox(height: 12),
          _buildLocationCard(
            context,
            label: 'Lokasi Belanja',
            address: state.pickupAddress ?? 'Pilih lokasi toko/warung',
            icon: Icons.storefront_rounded,
            color: Colors.orange,
            onTap: () async {
              final result = await showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => LocationPickerSheet(
                  title: 'Pilih Lokasi Belanja',
                  initialLocation: state.pickupLocation ?? ref.watch(userLocationProvider),
                  primaryColor: primary,
                ),

              );
              if (result != null) {
                notifier.updatePickup(result['location'], result['address']);
              }
            },
          ),
          const SizedBox(height: 12),
          _buildLocationCard(
            context,
            label: 'Lokasi Pengantaran',
            address: state.deliveryAddress ?? 'Pilih lokasi tujuan',
            icon: Icons.location_on_rounded,
            color: primary,
            onTap: () async {
              final result = await showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => LocationPickerSheet(
                  title: 'Pilih Lokasi Pengantaran',
                  initialLocation: state.deliveryLocation ?? ref.watch(userLocationProvider),
                  primaryColor: primary,
                ),

              );
              if (result != null) {
                notifier.updateDelivery(result['location'], result['address']);
              }
            },
          ),

          const SizedBox(height: 24),
          _buildSectionTitle('Informasi Tambahan'),
          const SizedBox(height: 12),
          _buildCard(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildDropdown(
                        label: 'Berat (Estimasi)',
                        value: '${state.weightKg} kg',
                        items: ['0.5 kg', '1.0 kg', '2.0 kg', '5.0 kg'],
                        onChanged: (val) => notifier.updateWeight(double.parse(val!.split(' ')[0])),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildDropdown(
                        label: 'Ukuran',
                        value: state.volumeLiters == 1 ? 'Kecil (S)' : state.volumeLiters == 5 ? 'Sedang (M)' : 'Besar (L)',
                        items: ['Kecil (S)', 'Sedang (M)', 'Besar (L)'],
                        onChanged: (val) {
                          double liters = 1;
                          if (val == 'Sedang (M)') liters = 5;
                          if (val == 'Besar (L)') liters = 15;
                          notifier.updateVolume(liters);
                        },
                      ),
                    ),
                  ],
                ),
                const Divider(height: 32),
                  _buildSectionTitle('Metode Pembayaran', small: true),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildPaymentOption(
                          label: 'Saldo Dompet',
                          isSelected: state.paymentMethod == 'escrow',
                          onTap: () => notifier.updatePaymentMethod('escrow'),
                          primary: primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildPaymentOption(
                          label: 'Bayar di Tempat (COD)',
                          isSelected: state.paymentMethod == 'cod',
                          isEnabled: ref.watch(authProvider).user?.isVerified ?? false,
                          onTap: () => notifier.updatePaymentMethod('cod'),
                          primary: primary,
                        ),
                      ),
                    ],
                  ),
                  if (!(ref.watch(authProvider).user?.isVerified ?? false))
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline_rounded, size: 14, color: Colors.orange.shade700),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Verifikasi e-KYC untuk mengaktifkan fitur COD.',
                              style: TextStyle(fontSize: 11, color: Colors.orange.shade800, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),
              ],
            ),
          ),
          const SizedBox(height: 100), // Spacing for FAB
        ],
      ),
    );
  }

  Widget _buildSummaryView(BuildContext context, WidgetRef ref, CreateOrderState state, CreateOrderNotifier notifier, Color primary) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Konfirmasi Detail Pesanan'),
          const SizedBox(height: 12),
          _buildCard(
            child: Column(
              children: [
                _buildSummaryDetailRow('Barang', state.itemDetails),
                const Divider(height: 24),
                _buildSummaryDetailRow('Lokasi Belanja', state.pickupAddress ?? '-', isAddress: true),
                const SizedBox(height: 12),
                _buildSummaryDetailRow('Lokasi Tujuan', state.deliveryAddress ?? '-', isAddress: true),
                const Divider(height: 24),
                Row(
                  children: [
                    _buildTag('Berat: ${state.weightKg} kg'),
                    const SizedBox(width: 8),
                    _buildTag('Ukuran: ${state.volumeLiters == 1 ? 'S' : state.volumeLiters == 5 ? 'M' : 'L'}'),
                    const SizedBox(width: 8),
                    _buildTag(state.paymentMethod == 'escrow' ? 'SALDO DOMPET' : 'COD', isPrimary: true, primary: primary),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionTitle('Rincian Biaya'),
          const SizedBox(height: 12),
          _buildSummary(state, primary),
          const SizedBox(height: 24),
          
          if (state.paymentMethod == 'escrow') ...[
            _buildSectionTitle('Metode Saldo Dompet'),
            const SizedBox(height: 12),
            _buildBalanceCard(context, ref, state, primary),
          ],
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildBalanceCard(BuildContext context, WidgetRef ref, CreateOrderState state, Color primary) {
    final isSufficient = state.isBalanceSufficient;
    return _buildCard(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Saldo Dompet Anda', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  SizedBox(height: 4),
                  Text('Pembayaran Otomatis', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                ],
              ),
              Text(
                CurrencyFormatter.formatToIdr(state.userBalance, withSymbol: true),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          if (!isSufficient) ...[
            const Divider(height: 24),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.withValues(alpha: 0.1)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Saldo tidak mencukupi untuk membuat pesanan ini.',
                          style: TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () {
                        showTopUpSheet(context, ref, primary);
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Top Up Sekarang', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomAction(BuildContext context, WidgetRef ref, CreateOrderState state, CreateOrderNotifier notifier, Color primary) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -5))
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (state.error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(state.error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
            ),
          Row(
            children: [
              if (state.showSummary)
                Expanded(
                  flex: 1,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: OutlinedButton(
                      onPressed: state.isLoading ? null : () => notifier.toggleSummary(false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                      child: const Text('Ubah', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: state.isLoading ? null : (state.showSummary 
                    ? (state.isBalanceSufficient ? () async {
                        final error = await notifier.submitOrder();
                        if (!context.mounted) return;
                        if (error != null) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
                        } else {
                          // Refresh data di beranda sebelum kembali
                          ref.read(walletProvider.notifier).fetchBalance();
                          ref.read(activityProvider.notifier).fetchActivities();
                          
                          if (context.mounted) {
                            context.pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Pesanan berhasil dibuat! Silakan cek di tab Pesanan.'),
                                backgroundColor: AppColors.success,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        }
                      } : null)
                    : () => notifier.prepareSummary()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                    disabledBackgroundColor: Colors.grey.shade300,
                  ),
                  child: state.isLoading 
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(
                        state.showSummary ? 'Konfirmasi Pesanan' : 'Lanjutkan', 
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
                      ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryDetailRow(String label, String value, {bool isAddress = false}) {
    return Row(
      crossAxisAlignment: isAddress ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 90,
          child: Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  Widget _buildTag(String label, {bool isPrimary = false, Color? primary}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isPrimary ? primary?.withValues(alpha: 0.1) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10, 
          fontWeight: FontWeight.bold, 
          color: isPrimary ? primary : const Color(0xFF64748B)
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, {bool small = false}) {
    return Text(
      title,
      style: TextStyle(
        fontSize: small ? 12 : 14,
        fontWeight: FontWeight.w700,
        color: const Color(0xFF64748B),
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: child,
    );
  }

  Widget _buildInputField({
    required String label,
    required String hint,
    required IconData icon,
    String? initialValue,
    String? prefixText,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    required ValueChanged<String> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
          ),
          child: TextFormField(
            initialValue: initialValue,
            keyboardType: keyboardType,
            onChanged: onChanged,
            inputFormatters: inputFormatters,
            cursorColor: Colors.black,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14, fontWeight: FontWeight.normal),
              prefixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(width: 16),
                  if (prefixText == null) 
                    Icon(icon, size: 20, color: const Color(0xFF64748B))
                  else
                    Text(prefixText, style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(width: 8),
                ],
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 0),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentOption({
    required String label,
    required bool isSelected,
    bool isEnabled = true,
    required VoidCallback onTap,
    required Color primary,
  }) {
    return GestureDetector(
      onTap: isEnabled ? onTap : null,
      child: Opacity(
        opacity: isEnabled ? 1.0 : 0.5,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? primary.withValues(alpha: 0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? primary : const Color(0xFFE2E8F0),
              width: 1.5,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isSelected ? primary : const Color(0xFF64748B),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLocationCard(
    BuildContext context, {
    required String label,
    required String address,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: _buildCard(
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8))),
                  const SizedBox(height: 2),
                  Text(
                    address,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFFCBD5E1)),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8))),
        DropdownButton<String>(
          value: value,
          isExpanded: true,
          underline: const SizedBox(),
          icon: const Icon(Icons.expand_more, size: 20),
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 14)))).toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildSummary(CreateOrderState state, Color primary) {
    return _buildCard(
      child: Column(
        children: [
          _buildSummaryRow('Harga Barang', CurrencyFormatter.formatToIdr(state.estimatedCost, withSymbol: true)),
          const SizedBox(height: 8),
          _buildSummaryRow('Biaya Titip', CurrencyFormatter.formatToIdr(state.estimatedFee, withSymbol: true), color: primary),
          const Divider(height: 24),
          _buildSummaryRow('Total Pembayaran', CurrencyFormatter.formatToIdr(state.totalPayment, withSymbol: true), isBold: true),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {Color? color, bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 14, color: isBold ? Colors.black : const Color(0xFF64748B), fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color ?? Colors.black)),
      ],
    );
  }
}
