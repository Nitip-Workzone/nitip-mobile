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

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getStatusColor(order.status).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        order.status.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: _getStatusColor(order.status),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
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
                  ],
                ),
                Text(
                  order.formattedCreatedAt,
                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
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
                      Text(
                        order.itemDetails,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textMain,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Total: ${CurrencyFormatter.formatToIdr(order.totalPayment, withSymbol: true)}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMuted,
                        ),
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
              Row(
                children: [
                  _buildInfoItem(Icons.scale_outlined, '${order.weightKg}kg'),
                  const SizedBox(width: 16),
                  _buildInfoItem(Icons.inventory_2_outlined, _getVolumeLabel(order.volumeLiters)),
                  const Spacer(),
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

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return AppColors.warning;
      case 'accepted':
      case 'on_progress':
      case 'started':
        return AppColors.primary;
      case 'completed':
        return AppColors.success;
      case 'cancelled':
      case 'rejected':
        return AppColors.error;
      default:
        return AppColors.textMuted;
    }
  }

  String _getVolumeLabel(double liters) {
    if (liters <= 1) return 'Kecil';
    if (liters <= 5) return 'Sedang';
    return 'Besar';
  }
}
