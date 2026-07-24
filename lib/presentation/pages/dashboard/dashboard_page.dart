import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';

import '../../providers/auth_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/activity_provider.dart';
import '../../providers/location_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../../domain/models/order_model.dart';
import '../orders/qr_scanner_page.dart';

import '../../widgets/common/connectivity_banner.dart';
import 'tabs/home_tab.dart';
import 'tabs/wallet_tab.dart';
import 'tabs/profile_tab.dart';
import 'tabs/trips_tab.dart';
import '../merchant/merchant_dashboard_page.dart';


class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      ref.read(userLocationProvider.notifier).updateLocation();
      ref.read(activityProvider.notifier).fetchActivities();
    });
  }


  @override
  Widget build(BuildContext context) {
    // Listen for auth state changes to trigger fetches when becoming authenticated
    ref.listen(authProvider, (previous, next) {
      if (next.isAuthenticated && (previous == null || !previous.isAuthenticated)) {
        ref.read(walletProvider.notifier).fetchBalance();
        ref.read(notificationProvider.notifier).fetchUnreadCount();
        ref.read(activityProvider.notifier).fetchActivities();
      }
    });

    final authState = ref.watch(authProvider);
    final user = authState.user;
    final isRunner = user?.isRunner ?? false;
    final isMerchant = user?.isMerchant ?? false;

    if (isMerchant) {
      return const MerchantDashboardPage();
    }

    const primary = AppColors.secondary;

    const navItems = [
      _NavItem(icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: 'Beranda'),
      _NavItem(icon: Icons.map_outlined, activeIcon: Icons.map_rounded, label: 'Trip'),
      _NavItem(icon: Icons.account_balance_wallet_outlined, activeIcon: Icons.account_balance_wallet_rounded, label: 'Dompet'),
      _NavItem(icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded, label: 'Profil'),
    ];

    final currentIndex = ref.watch(dashboardIndexProvider);
    final adjustedIndex = currentIndex >= navItems.length ? 0 : currentIndex;

    final activityState = ref.watch(activityProvider);
    final activeOrdersCount = activityState.activeOrders.length;

    const tabs = [HomeTab(), TripsTab(), WalletTab(), ProfileTab()];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: ConnectivityBanner(
        child: IndexedStack(index: adjustedIndex, children: tabs),
      ),
      
      floatingActionButton: isRunner
          ? _DynamicPulseHub(
              activeOrdersCount: activeOrdersCount,
              primary: primary,
              onQrTap: () async {
                final activeOrders = ref.read(activityProvider).activeOrders;
                if (activeOrders.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Anda tidak memiliki pesanan aktif untuk diselesaikan.'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  return;
                }

                OrderModel? selectedOrder;

                if (activeOrders.length == 1) {
                  selectedOrder = activeOrders.first;
                } else {
                  // Show selection sheet if there are multiple active orders
                  selectedOrder = await showModalBottomSheet<OrderModel>(
                    context: context,
                    backgroundColor: Colors.transparent,
                    builder: (context) => _OrderSelectionSheet(
                      orders: activeOrders,
                      primaryColor: primary,
                    ),
                  );
                }

                if (selectedOrder == null || !context.mounted) return;

                final expectedCode = selectedOrder.completionCode ?? '';

                final scannedCode = await Navigator.push<String>(
                  context,
                  MaterialPageRoute(
                    builder: (context) => QrScannerPage(expectedCode: expectedCode),
                  ),
                );

                if (scannedCode != null && context.mounted) {
                  // Complete the order
                  final success = await ref.read(activityProvider.notifier).completeOrder(
                    selectedOrder.id,
                    scannedCode,
                    '', // Empty delivery image URL for mock
                  );

                  if (success && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Pesanan #${selectedOrder.id.substring(0, 8)} berhasil diselesaikan!'),
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: Colors.green,
                      ),
                    );
                  } else if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Gagal menyelesaikan pesanan. Silakan coba lagi.'),
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              onOrdersTap: () {
                final activeOrders = ref.read(activityProvider).activeOrders;
                if (activeOrders.isNotEmpty) {
                  if (activeOrders.length == 1) {
                    context.push('/orders/detail/${activeOrders.first.id}');
                  } else {
                    context.push('/orders/active');
                  }
                }
              },
            )
          : null,
      floatingActionButtonLocation: isRunner ? FloatingActionButtonLocation.centerDocked : null,
      bottomNavigationBar: _CustomNavBar(
        currentIndex: adjustedIndex,
        onTap: (i) => ref.read(dashboardIndexProvider.notifier).state = i,
        items: navItems,
        activeColor: primary,
        isRunner: isRunner,
      ),
    );
  }
}

class _DynamicPulseHub extends StatefulWidget {
  final int activeOrdersCount;
  final Color primary;
  final VoidCallback onQrTap;
  final VoidCallback onOrdersTap;

  const _DynamicPulseHub({
    required this.activeOrdersCount,
    required this.primary,
    required this.onQrTap,
    required this.onOrdersTap,
  });

  @override
  State<_DynamicPulseHub> createState() => _DynamicPulseHubState();
}

class _DynamicPulseHubState extends State<_DynamicPulseHub> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasOrders = widget.activeOrdersCount > 0;

    return Stack(
      alignment: Alignment.bottomCenter, // Align to bottom so it grows upwards
      children: [
        // Pulse Effect (Stays at the bottom QR position)
        if (hasOrders)
          Positioned(
            bottom: 0,
            child: FadeTransition(
              opacity: Tween(begin: 0.5, end: 0.0).animate(_pulseController),
              child: ScaleTransition(
                scale: Tween(begin: 1.0, end: 1.6).animate(_pulseController),
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: widget.primary.withValues(alpha: 0.4),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
        
        // Main Hub Container (Dynamic Width to prevent clipping)
        AnimatedContainer(
          duration: const Duration(milliseconds: 600),
          curve: Curves.elasticOut,
          height: hasOrders ? 120 : 64,
          width: hasOrders ? 180 : 64, // Expand width when has orders
          child: Stack(
            alignment: Alignment.bottomCenter,
            clipBehavior: Clip.none, // Allow glow and shadow to spread
            children: [
              // ── Top Part (The Wide Horizontal Capsule) ──
              if (hasOrders)
                Positioned(
                  bottom: 58, // Reverted to safe distance
                  child: GestureDetector(
                    onTap: widget.onOrdersTap,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 700),
                      curve: Curves.elasticOut,
                      builder: (context, value, child) => Transform.scale(
                        scale: value,
                        child: child,
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: widget.primary, // Reverted to solid primary for visibility on FAB
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: widget.primary.withValues(alpha: 0.3),
                              blurRadius: 15,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.bolt_rounded, color: Colors.white, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              '${widget.activeOrdersCount} PESANAN AKTIF',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 11,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

              // ── Bottom Part (The QR Circle) ──
              GestureDetector(
                onTap: widget.onQrTap,
                child: Container(
                  height: 64,
                  width: 64,
                  decoration: BoxDecoration(
                    color: widget.primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: widget.primary.withValues(alpha: 0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 2),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 28),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _NavItem({required this.icon, required this.activeIcon, required this.label});
}

class _CustomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<_NavItem> items;
  final Color activeColor;
  final bool isRunner;

  const _CustomNavBar({
    required this.currentIndex,
    required this.onTap,
    required this.items,
    required this.activeColor,
    required this.isRunner,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9), // Glassmorphism effect
        boxShadow: [
          BoxShadow(
            color: activeColor.withValues(alpha: 0.10), // Stronger shadow
            blurRadius: 30,
            offset: const Offset(0, -8),
          )
        ],
        border: Border(top: BorderSide(color: activeColor.withValues(alpha: 0.08), width: 1)),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, bottomPadding > 0 ? bottomPadding : 16),
          child: Row(
            mainAxisAlignment: isRunner ? MainAxisAlignment.spaceBetween : MainAxisAlignment.spaceAround,
            children: [
              if (isRunner) ..._buildRunnerNavItems()
              else ...List.generate(items.length, (i) => _buildNavItem(i)),
            ],
          ),
        ),
      ),
    );
  }

  /// Runner-specific layout: 4 items with FAB spacer in the middle
  List<Widget> _buildRunnerNavItems() {
    return [
      _buildNavItem(0),
      _buildNavItem(1),
      const SizedBox(width: 48), // Spacer for FAB
      _buildNavItem(2),
      _buildNavItem(3),
    ];
  }

  Widget _buildNavItem(int index) {
    if (index >= items.length) return const SizedBox.shrink();
    final item = items[index];
    final isActive = index == currentIndex;

    return Builder(
      builder: (context) => GestureDetector(
        onTap: () => onTap(index),
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: isRunner
              ? (MediaQuery.of(context).size.width - 100) / 4
              : MediaQuery.of(context).size.width / (items.length + 1.5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isActive ? activeColor.withValues(alpha: 0.13) : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  border: isActive ? Border.all(color: activeColor.withValues(alpha: 0.25), width: 1) : Border.all(color: Colors.transparent, width: 1),
                ),
                child: Icon(
                  isActive ? item.activeIcon : item.icon,
                  color: isActive ? activeColor : AppColors.textMuted,
                  size: 24,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isActive ? activeColor : AppColors.textMuted,
                  fontSize: 10,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              // Dot indicator
              AnimatedOpacity(
                duration: const Duration(milliseconds: 250),
                opacity: isActive ? 1.0 : 0.0,
                child: Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: activeColor,
                    shape: BoxShape.circle,
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

class _OrderSelectionSheet extends StatelessWidget {
  final List<OrderModel> orders;
  final Color primaryColor;

  const _OrderSelectionSheet({
    required this.orders,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Pilih Pesanan untuk Diselesaikan',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: orders.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final order = orders[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: primaryColor.withValues(alpha: 0.1),
                    child: Icon(Icons.shopping_bag_rounded, color: primaryColor, size: 20),
                  ),
                  title: Text(
                    order.itemDetails,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  subtitle: Text(
                    'Penerima: ${order.receiverName ?? "-"}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.pop(context, order),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
