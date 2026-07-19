import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/dashboard_provider.dart';
import '../../../providers/location_provider.dart';
import '../../../providers/notification_provider.dart';
import '../../../providers/wallet_provider.dart';
import '../../../providers/activity_provider.dart';
import '../../wallet/top_up_sheet.dart';
import '../../../widgets/common/location_detail_sheet.dart';

class HomeTab extends ConsumerWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final walletState = ref.watch(walletProvider);
    final activityState = ref.watch(activityProvider);
    final isVisible = ref.watch(balanceVisibilityProvider);
    
    final user = authState.user;
    final isLoading = user == null;
    final userName = user?.name ?? 'Runner';
    final isVerified = user?.isVerified ?? false;
    final notifState = ref.watch(notificationProvider);
    final activeOrdersCount = activityState.activeOrders.length;

    final userLocation = ref.watch(userLocationProvider);
    final userAddressAsync = ref.watch(userAddressProvider);

    // Runner-only app: always use green theme
    const primary = AppColors.secondary;
    const primaryDark = AppColors.secondaryDark;
    const primaryMid = AppColors.secondaryMid;
    const primaryLight = AppColors.secondaryLight;

    final currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    if (authState.isAuthenticated) {
      if (!activityState.isLoading && !activityState.hasFetched) {
        Future.microtask(() => ref.read(activityProvider.notifier).fetchActivities());
      }
      if (!walletState.isLoading && !walletState.hasFetched) {
        Future.microtask(() => ref.read(walletProvider.notifier).fetchBalance());
      }
      if (!notifState.isLoading && !notifState.hasFetchedCount) {
        Future.microtask(() => ref.read(notificationProvider.notifier).fetchUnreadCount());
      }
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Positioned(
            top: -120,
            left: -80,
            child: _GlowCircle(color: primaryMid.withValues(alpha: 0.18), size: 360),
          ),
          SafeArea(
            child: RefreshIndicator(
              onRefresh: () async {
                await Future.wait([
                  ref.read(authProvider.notifier).refreshProfile(),
                  ref.read(walletProvider.notifier).fetchBalance(),
                  ref.read(notificationProvider.notifier).fetchUnreadCount(),
                  ref.read(activityProvider.notifier).fetchActivities(),
                ]);
              },
              color: primary,
              child: isLoading
                  ? _HomeSkeleton(primary: primary)
                  : CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                          sliver: SliverToBoxAdapter(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // ── Header Optimized ────────────────────
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Halo, $userName! 👋',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w900,
                                              fontSize: 22,
                                              color: Color(0xFF0F172A),
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Row(
                                            children: [
                                              const Text(
                                                'Mode Runner',
                                                style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600),
                                              ),
                                              if (isVerified) ...[
                                                const SizedBox(width: 4),
                                                Icon(Icons.verified_rounded, color: primary, size: 14),
                                              ],
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          userLocation != null && userAddressAsync.isLoading
                                              ? _BlinkingLocationLoading(color: primary)
                                              : GestureDetector(
                                                  onTap: userLocation == null
                                                      ? null
                                                      : () {
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
                                                  child: Row(
                                                    children: [
                                                      Icon(Icons.location_on_rounded, color: primary, size: 12),
                                                      const SizedBox(width: 4),
                                                      Expanded(
                                                        child: userLocation != null
                                                            ? userAddressAsync.when(
                                                                data: (address) => Text(
                                                                  address ?? '${userLocation.latitude.toStringAsFixed(6)}, ${userLocation.longitude.toStringAsFixed(6)}',
                                                                  maxLines: 1,
                                                                  overflow: TextOverflow.ellipsis,
                                                                  style: TextStyle(color: primary, fontSize: 11, fontWeight: FontWeight.bold),
                                                                ),
                                                                error: (_, __) => Text(
                                                                  '${userLocation.latitude.toStringAsFixed(6)}, ${userLocation.longitude.toStringAsFixed(6)}',
                                                                  maxLines: 1,
                                                                  overflow: TextOverflow.ellipsis,
                                                                  style: const TextStyle(color: AppColors.textMuted, fontSize: 11, fontFamily: 'monospace'),
                                                                ),
                                                                loading: () => const SizedBox.shrink(),
                                                              )
                                                            : const Text(
                                                                'Lokasi belum terdeteksi',
                                                                style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w500),
                                                              ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    _NotificationButton(notifCount: notifState.unreadCount, primary: primary),
                                  ],
                                ),

                                const SizedBox(height: 12), // Reduced from 20 for tighter layout

                                // ── Status Carousel (Online Toggle, KYC) ───────────────
                                _StatusCarousel(
                                  isOnline: user.isAcceptingOrders,
                                  onOnlineChanged: (val) => ref.read(authProvider.notifier).toggleAcceptingOrders(val),
                                  activeOrdersCount: activeOrdersCount,
                                  primary: primary,
                                  onOrdersTap: () => context.push('/orders/active'),
                                ),


                                const SizedBox(height: 16),

                                // ── Nitip Pay Card ──────────────────────
                                _PayCard(
                                  primaryDark: primaryDark,
                                  primaryMid: primaryMid,
                                  balance: walletState.wallet?.balance ?? 0,
                                  isVisible: isVisible,
                                  onToggleVisibility: () => ref.read(balanceVisibilityProvider.notifier).state = !isVisible,
                                  isLoading: walletState.isLoading,
                                  currencyFormat: currencyFormat,
                                  onTopUp: () => showTopUpSheet(context, ref, primary),
                                  onWithdraw: () => context.push('/wallet/withdraw'),
                                  onHistory: () => context.push('/wallet/history'),
                                ),

                                const SizedBox(height: 32),

                                // ── Quick Actions ────────────────────────
                                const Text(
                                  'Aksi Cepat',
                                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: Color(0xFF0F172A)),
                                ),
                                const SizedBox(height: 16),
                                _QuickActionsGrid(
                                  primary: primary,
                                  primaryLight: primaryLight,
                                  context: context,
                                  ref: ref,
                                ),

                                const SizedBox(height: 32),

                                // ── Today's Activity ──
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Aktivitas Hari Ini',
                                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: Color(0xFF0F172A)),
                                    ),
                                    GestureDetector(
                                      onTap: () => context.push('/orders/active'),
                                      child: Row(
                                        children: [
                                          Text(
                                            'Lihat Semua',
                                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: primary),
                                          ),
                                          const SizedBox(width: 4),
                                          Icon(Icons.arrow_forward_ios_rounded, size: 11, color: primary),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                _TodayOrderList(
                                  activityState: activityState,
                                  primary: primary,
                                  onTapOrder: (orderId) => context.push('/orders/detail/$orderId'),
                                ),
                                
                                const SizedBox(height: 40),
                              ],
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
  }
}

// ── COMPACT UI COMPONENTS ─────────────────────────────────────────────────────

class _StatusCarousel extends StatelessWidget {
  final bool isOnline;
  final ValueChanged<bool> onOnlineChanged;
  final int activeOrdersCount;
  final Color primary;
  final VoidCallback onOrdersTap;

  const _StatusCarousel({
    required this.isOnline,
    required this.onOnlineChanged,
    required this.activeOrdersCount,
    required this.primary,
    required this.onOrdersTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        children: [
          _StatusPill(
            icon: isOnline ? Icons.power_settings_new_rounded : Icons.power_off_rounded,
            label: isOnline ? 'Online' : 'Offline',
            color: isOnline ? primary : Colors.grey,
            onTap: () => onOnlineChanged(!isOnline),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _StatusPill({required this.icon, required this.label, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white, // Clean white background
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }
}

class _NotificationButton extends StatelessWidget {
  final int notifCount;
  final Color primary;

  const _NotificationButton({required this.notifCount, required this.primary});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/notifications'),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: Colors.grey.shade100)),
            child: Icon(Icons.notifications_none_rounded, color: primary, size: 24),
          ),
          if (notifCount > 0)
            Positioned(
              top: 2,
              right: 2,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                child: Text(
                  '${notifCount > 9 ? '9+' : notifCount}',
                  style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _GlowCircle extends StatelessWidget {
  final Color color;
  final double size;
  const _GlowCircle({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, Colors.transparent]),
      ),
    );
  }
}

class _PayCard extends StatelessWidget {
  final Color primaryDark;
  final Color primaryMid;
  final double balance;
  final bool isVisible;
  final VoidCallback onToggleVisibility;
  final bool isLoading;
  final NumberFormat currencyFormat;
  final VoidCallback onTopUp;
  final VoidCallback onWithdraw;
  final VoidCallback onHistory;

  const _PayCard({
    required this.primaryDark,
    required this.primaryMid,
    required this.balance,
    required this.isVisible,
    required this.onToggleVisibility,
    required this.isLoading,
    required this.currencyFormat,
    required this.onTopUp,
    required this.onWithdraw,
    required this.onHistory,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [primaryDark, primaryMid], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: primaryDark.withValues(alpha: 0.3), blurRadius: 24, offset: const Offset(0, 12))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Runner Wallet', style: TextStyle(color: Colors.white70, fontSize: 13)),
              GestureDetector(
                onTap: onToggleVisibility,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
                  child: Row(
                    children: [
                      Icon(isVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: Colors.white70, size: 13),
                      const SizedBox(width: 4),
                      Text(isVisible ? 'Sembunyikan' : 'Tampilkan', style: const TextStyle(color: Colors.white70, fontSize: 10)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (isLoading)
            const SizedBox(height: 36, child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))))
          else
            Text(isVisible ? currencyFormat.format(balance) : '••••••••', style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          Row(
            children: [
              _CardAction(icon: Icons.add_rounded, label: 'Top Up', onTap: onTopUp),
              const SizedBox(width: 12),
              _CardAction(icon: Icons.payments_rounded, label: 'Tarik', onTap: onWithdraw),
              const SizedBox(width: 12),
              _CardAction(icon: Icons.history_rounded, label: 'Riwayat', onTap: onHistory),
            ],
          ),
        ],
      ),
    );
  }
}

class _CardAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _CardAction({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _QuickActionsGrid extends StatelessWidget {
  final Color primary;
  final Color primaryLight;
  final BuildContext context;
  final WidgetRef ref;

  const _QuickActionsGrid({required this.primary, required this.primaryLight, required this.context, required this.ref});

  @override
  Widget build(BuildContext outerContext) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCategoryGroup(outerContext, 'Tugas & Pendapatan', [
          _ActionData(Icons.search_rounded, 'Cari Order', () => outerContext.push('/orders/explore')),
          _ActionData(Icons.history_rounded, 'Riwayat Saldo', () => outerContext.push('/wallet/history')),
          _ActionData(Icons.payments_rounded, 'Tarik Saldo', () => outerContext.push('/wallet/withdraw')),
        ]),
        const SizedBox(height: 24),
        _buildCategoryGroup(outerContext, 'Akun & Saldo', [
          _ActionData(Icons.account_balance_wallet_rounded, 'Dompet', () => ref.read(dashboardIndexProvider.notifier).state = 2),
          _ActionData(Icons.support_agent_rounded, 'Pusat Bantuan', () => outerContext.push('/faq')),
        ]),
      ],
    );
  }

  Widget _buildCategoryGroup(BuildContext context, String title, List<_ActionData> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(padding: const EdgeInsets.only(left: 4, bottom: 12), child: Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF64748B), letterSpacing: 0.5))),
        _buildGrid(context, items),
      ],
    );
  }

  Widget _buildGrid(BuildContext outerContext, List<_ActionData> items) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 4,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 0.8,
      children: items.map((item) {
        return GestureDetector(
          onTap: item.onTap ?? () {
            
          },
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(color: primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14)),
                child: Icon(item.icon, color: primary, size: 22),
              ),
              const SizedBox(height: 8),
              Text(item.label, textAlign: TextAlign.center, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: const Color(0xFF334155))),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _ActionData {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  _ActionData(this.icon, this.label, this.onTap);
}

class _TodayOrderList extends StatelessWidget {
  final ActivityState activityState;
  final Color primary;
  final Function(String) onTapOrder;

  const _TodayOrderList({
    required this.activityState,
    required this.primary,
    required this.onTapOrder,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final allOrders = [...activityState.activeOrders, ...activityState.pastOrders];
    // Show orders created OR updated today (so completed-today orders also appear)
    final todayOrders = allOrders.where((o) {
      final createdToday = o.createdAt.day == now.day && o.createdAt.month == now.month && o.createdAt.year == now.year;
      final updatedToday = o.updatedAt.day == now.day && o.updatedAt.month == now.month && o.updatedAt.year == now.year;
      return createdToday || updatedToday;
    }).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    if (todayOrders.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            Icon(Icons.inbox_outlined, size: 40, color: AppColors.textMuted.withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            const Text(
              'Belum ada aktivitas hari ini',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textMuted),
            ),
            const SizedBox(height: 4),
            const Text(
              'Mulai cari order untuk mendapatkan penghasilan',
              style: TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ],
        ),
      );
    }

    // Compact summary stats
    final completedCount = todayOrders.where((o) => o.isCompleted).length;
    final activeCount = todayOrders.where((o) => !o.isCompleted && o.status != 'cancelled').length;

    return Column(
      children: [
        // ── Mini Stats Row ──
        Row(
          children: [
            _MiniStatChip(
              icon: Icons.local_shipping_rounded,
              label: '$activeCount aktif',
              color: primary,
            ),
            const SizedBox(width: 8),
            _MiniStatChip(
              icon: Icons.check_circle_outline_rounded,
              label: '$completedCount selesai',
              color: AppColors.success,
            ),
            const Spacer(),
            Text(
              '${todayOrders.length} order',
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // ── Order List (max 5 shown) ──
        ...todayOrders.take(5).map((order) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _buildOrderTile(context, order),
        )),

        if (todayOrders.length > 5)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '+ ${todayOrders.length - 5} order lainnya',
              style: TextStyle(fontSize: 11, color: primary, fontWeight: FontWeight.w600),
            ),
          ),
      ],
    );
  }

  Widget _buildOrderTile(BuildContext context, dynamic order) {
    final isActive = !order.isCompleted && order.status != 'cancelled';
    final statusColor = _getStatusColor(order.status);
    final statusLabel = _getStatusLabel(order.status);
    final icon = _getStatusIcon(order.status);
    final timeStr = DateFormat('HH:mm').format(order.createdAt);

    return GestureDetector(
      onTap: () => onTapOrder(order.id),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isActive ? primary.withValues(alpha: 0.04) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive ? primary.withValues(alpha: 0.15) : Colors.grey.shade100,
          ),
        ),
        child: Row(
          children: [
            // Status icon
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: statusColor, size: 18),
            ),
            const SizedBox(width: 12),
            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    order.itemDetails,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${order.serviceCategory.toUpperCase()} • $timeStr',
                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Status badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                statusLabel,
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending': return const Color(0xFFF59E0B);
      case 'accepted': return const Color(0xFF3B82F6);
      case 'purchasing': return const Color(0xFF8B5CF6);
      case 'delivering':
      case 'on_progress': return const Color(0xFF2563EB);
      case 'completed': return AppColors.success;
      case 'cancelled': return AppColors.textMuted;
      default: return AppColors.textMuted;
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'pending': return 'Menunggu';
      case 'accepted': return 'Diterima';
      case 'purchasing': return 'Belanja';
      case 'delivering': return 'Antar';
      case 'on_progress': return 'Proses';
      case 'completed': return 'Selesai';
      case 'cancelled': return 'Batal';
      default: return status;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'pending': return Icons.hourglass_top_rounded;
      case 'accepted': return Icons.check_circle_outline_rounded;
      case 'purchasing': return Icons.shopping_cart_rounded;
      case 'delivering':
      case 'on_progress': return Icons.electric_moped_rounded;
      case 'completed': return Icons.check_circle_rounded;
      case 'cancelled': return Icons.cancel_outlined;
      default: return Icons.receipt_long_rounded;
    }
  }
}

class _MiniStatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _MiniStatChip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }
}

class _HomeSkeleton extends StatelessWidget {
  final Color primary;
  const _HomeSkeleton({required this.primary});

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

class _BlinkingLocationLoading extends StatefulWidget {
  final Color color;
  const _BlinkingLocationLoading({required this.color});

  @override
  State<_BlinkingLocationLoading> createState() => _BlinkingLocationLoadingState();
}

class _BlinkingLocationLoadingState extends State<_BlinkingLocationLoading> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.3, end: 1.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.water_drop_rounded, color: widget.color, size: 12),
          const SizedBox(width: 4),
          Text(
            'Memuat lokasi...',
            style: TextStyle(
              color: widget.color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
