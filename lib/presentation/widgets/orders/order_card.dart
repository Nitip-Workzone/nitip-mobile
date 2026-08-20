import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../domain/models/order_model.dart';

class OrderCard extends StatelessWidget {
  final OrderModel order;
  final VoidCallback onTap;
  final Color primaryColor;

  const OrderCard({
    super.key,
    required this.order,
    required this.onTap,
    this.primaryColor = AppColors.primary,
  });

  bool get isFood => (order.merchantId != null && order.merchantId!.isNotEmpty) || order.itemDetails.toLowerCase().contains('nitip food');

  @override
  Widget build(BuildContext context) {
    final bool food = isFood;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          // Clean white — tidak pakai warna background, hanya accent dot untuk food agar estetik & cepat beda
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border.withValues(alpha: 0.6), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row — clean white, no PENDING for runner (hanya BELI/KIRIM/FOOD badge + date) + fix overflow
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Hanya kategori BELI/KIRIM/FOOD, tidak tampil PENDING untuk runner (sesuai request)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: (order.serviceCategory == 'kirim' ? Colors.blue : Colors.orange).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    order.serviceCategory.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: order.serviceCategory == 'kirim' ? Colors.blue : Colors.orange.shade800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Flexible(
                  child: Text(
                    order.formattedCreatedAt,
                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                // Accent left bar untuk food — pembeda cepat tanpa background warna jelek
                if (food)
                  Container(width: 3, height: 48, decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(2))),
                if (food) const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    order.serviceCategory == 'kirim' ? Icons.local_shipping_outlined : Icons.shopping_bag_outlined, 
                    color: order.serviceCategory == 'kirim' ? Colors.blue : primaryColor, 
                    size: 24
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (food)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppColors.border, width: 1),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(Icons.restaurant_outlined, size: 10, color: AppColors.textMuted),
                                  SizedBox(width: 3),
                                  Text('FOOD', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 0.5)),
                                ],
                              ),
                            ),
                          if (food) const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              order.itemDetails,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textMain),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Price row — show payment method tag inline with price
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          food
                              ? Text(
                                  CurrencyFormatter.formatToIdr(order.deliveryFee - order.serviceFee - order.checkingFee, withSymbol: true),
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textMain),
                                )
                              : Text(
                                  'Total: ${CurrencyFormatter.formatToIdr(order.totalPayment, withSymbol: true)}',
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textMuted),
                                ),
                          if (!order.isCompleted && !order.isCancelled)
                            Text(
                              order.paymentMethod == 'escrow' ? 'Saldo Dompet' : 'COD',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: order.paymentMethod == 'escrow' ? AppColors.primary : Colors.orange.shade800,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Color(0xFFCBD5E1)),
              ],
            ),
            const Divider(height: 24, color: AppColors.border),
            if (order.isCompleted) ...[
              Row(
                children: [
                  const Icon(Icons.check_circle_outline, size: 14, color: AppColors.success),
                  const SizedBox(width: 6),
                  Text(
                    'Selesai • ${order.formattedCreatedAt}',
                    style: const TextStyle(fontSize: 12, color: AppColors.success, fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  if (order.paymentStatus == 'paid')
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'LUNAS',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.success),
                      ),
                    ),
                ],
              ),
            ] else if (order.isCancelled) ...[
              Row(
                children: [
                  const Icon(Icons.cancel_outlined, size: 14, color: AppColors.error),
                  const SizedBox(width: 6),
                  Text(
                    'Dibatalkan • ${order.formattedCreatedAt}',
                    style: const TextStyle(fontSize: 12, color: AppColors.error, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ] else ...[
              // Active: show weight + volume only (payment already shown inline above)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildInfoItem(Icons.scale_outlined, '${order.weightKg}kg'),
                  const SizedBox(width: 12),
                  _buildInfoItem(Icons.inventory_2_outlined, _getVolumeLabel(order.volumeLiters)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.textMuted),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }



  String _getVolumeLabel(double liters) {
    if (liters <= 1) return 'Kecil';
    if (liters <= 5) return 'Sedang';
    return 'Besar';
  }
}
