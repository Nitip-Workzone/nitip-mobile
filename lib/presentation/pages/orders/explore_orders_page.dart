import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../domain/models/order_model.dart';
import '../../providers/explore_orders_provider.dart';
import '../../providers/activity_provider.dart';
import '../../providers/pool_realtime_provider.dart';
import '../../widgets/orders/order_card.dart';

class ExploreOrdersPage extends ConsumerStatefulWidget {
  const ExploreOrdersPage({super.key});

  @override
  ConsumerState<ExploreOrdersPage> createState() => _ExploreOrdersPageState();
}

class _ExploreOrdersPageState extends ConsumerState<ExploreOrdersPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  bool _didInitPool = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    Future.microtask(() {
      if (!mounted) return;
      ref.read(exploreOrdersProvider.notifier).fetchAvailableOrders(syncLocation: true, force: true);
      ref.read(activityProvider.notifier).fetchActivities();
      if (!_didInitPool) {
        _didInitPool = true;
        ref.read(poolRealtimeProvider);
      }
      _tabController.addListener(() {
        if (!mounted) return;
        if (_tabController.index == 0 && !_tabController.indexIsChanging) {
          ref.read(exploreOrdersProvider.notifier).fetchAvailableOrders(syncLocation: false, force: true);
        }
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Re-fetch when returning from background/detail – ensures cancelled orders removed without pull
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(exploreOrdersProvider.notifier).fetchAvailableOrders(syncLocation: false, force: true);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(exploreOrdersProvider);
    final activityState = ref.watch(activityProvider);
    final poolState = ref.watch(poolRealtimeProvider);
    
    final activeOrders = activityState.activeOrders;
    final availableOrders = state.availableOrders;

    // Pool status colors & labels – distinct, not truncated
    Color dotColor;
    Color bgColor;
    Color borderColor;
    Color textColor;
    IconData statusIcon;
    if (poolState.isLive) {
      dotColor = const Color(0xFF22C55E);
      bgColor = const Color(0xFF22C55E).withValues(alpha: 0.12);
      borderColor = const Color(0xFF22C55E).withValues(alpha: 0.3);
      textColor = const Color(0xFF15803D);
      statusIcon = Icons.bolt_rounded;
    } else if (poolState.isConnecting) {
      dotColor = const Color(0xFFF59E0B);
      bgColor = const Color(0xFFF59E0B).withValues(alpha: 0.15);
      borderColor = const Color(0xFFF59E0B).withValues(alpha: 0.35);
      textColor = const Color(0xFF9A5A00);
      statusIcon = Icons.sync_rounded;
    } else {
      dotColor = const Color(0xFF64748B);
      bgColor = const Color(0xFF64748B).withValues(alpha: 0.12);
      borderColor = const Color(0xFF64748B).withValues(alpha: 0.25);
      textColor = const Color(0xFF475569);
      statusIcon = Icons.cloud_sync_rounded;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Kelola Tugas & Order',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.textMain),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(46),
          child: Column(
            children: [
              TabBar(
                controller: _tabController,
                indicatorColor: AppColors.secondary,
                indicatorWeight: 3,
                labelColor: AppColors.secondary,
                unselectedLabelColor: AppColors.textMuted,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 13),
                tabs: [
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.explore_outlined, size: 18),
                        const SizedBox(width: 8),
                        const Text('Cari Orderan'),
                        if (availableOrders.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.secondary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${availableOrders.length}',
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.secondary),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.assignment_turned_in_outlined, size: 18),
                        const SizedBox(width: 8),
                        const Text('Tugas Saya'),
                        if (activeOrders.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: const BoxDecoration(
                              color: AppColors.success,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '${activeOrders.length}',
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              // Pool status banner – full width, distinct colors, not truncated
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: bgColor,
                  border: Border(top: BorderSide(color: borderColor), bottom: BorderSide(color: borderColor.withValues(alpha: 0.5))),
                ),
                child: Row(
                  children: [
                    Icon(statusIcon, size: 14, color: dotColor),
                    const SizedBox(width: 6),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        poolState.isLive
                            ? 'Realtime Live • Update otomatis tanpa pull'
                            : (poolState.isConnecting ? 'Menghubungkan realtime pool...' : 'Mode Polling • Tarik untuk refresh'),
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: textColor),
                      ),
                    ),
                    if (poolState.isLive)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: dotColor, borderRadius: BorderRadius.circular(10)),
                        child: const Text('LIVE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white))),
                    if (poolState.lastUpdate != null && !poolState.isConnecting) ...[
                      const SizedBox(width: 8),
                      Text(poolState.lastUpdate!,
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: textColor.withValues(alpha: 0.7))),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ── Tab 1: Cari Orderan (Available Orders) ──
          RefreshIndicator(
            onRefresh: () async {
              await ref.read(exploreOrdersProvider.notifier).fetchAvailableOrders();
            },
            color: AppColors.secondary,
            child: state.isLoading && availableOrders.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : availableOrders.isEmpty
                    ? _buildNoAvailableOrdersWithScroll()
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: availableOrders.length,
                        itemBuilder: (context, index) {
                          final order = availableOrders[index];
                          return _buildAvailableOrderItem(order, state.isLoading);
                        },
                      ),
          ),

          // ── Tab 2: Tugas Saya (Accepted/Active Tasks) ──
          RefreshIndicator(
            onRefresh: () async {
              await ref.read(activityProvider.notifier).fetchActivities();
            },
            color: AppColors.secondary,
            child: activityState.isLoading && activeOrders.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : activeOrders.isEmpty
                    ? _buildNoActiveOrdersWithScroll()
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: activeOrders.length,
                        itemBuilder: (context, index) {
                          final order = activeOrders[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: OrderCard(
                              order: order,
                              onTap: () => context.push('/orders/detail/${order.id}'),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvailableOrderItem(OrderModel order, bool isLoading) {
    // Extra safety: never render completed/cancelled/expired in pool
    const blocked = {'completed', 'cancelled', 'expired', 'disputed'};
    if (blocked.contains(order.status.toLowerCase())) {
      return const SizedBox.shrink();
    }
    return Column(
      children: [
        OrderCard(
          order: order,
          onTap: () => context.push('/orders/detail/${order.id}'),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: isLoading 
              ? null 
              : () => _handleAccept(order.id),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.secondary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: const Text('Ambil Pesanan', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildNoAvailableOrdersWithScroll() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.25),
        Center(
          child: Column(
            children: [
              Icon(Icons.near_me_disabled_rounded, size: 64, color: AppColors.textMuted.withValues(alpha: 0.3)),
              const SizedBox(height: 16),
              const Text(
                'Tidak ada pesanan lain di sekitar Anda.',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textMain),
              ),
              const SizedBox(height: 8),
              const Text(
                'Tarik ke bawah untuk memuat ulang halaman.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNoActiveOrdersWithScroll() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.25),
        Center(
          child: Column(
            children: [
              Icon(Icons.assignment_late_outlined, size: 64, color: AppColors.textMuted.withValues(alpha: 0.3)),
              const SizedBox(height: 16),
              const Text(
                'Belum ada tugas aktif yang diambil.',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textMain),
              ),
              const SizedBox(height: 8),
              const Text(
                'Geser ke tab "Cari Orderan" untuk mulai mengambil tugas.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _handleAccept(String orderId) async {
    final success = await ref.read(exploreOrdersProvider.notifier).acceptOrder(orderId);
    if (!mounted) return;
    if (success) {
      // Fetch both active tasks and available orders to sync the state immediately
      await Future.wait([
        ref.read(exploreOrdersProvider.notifier).fetchAvailableOrders(),
        ref.read(activityProvider.notifier).fetchActivities(force: true),
      ]);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pesanan berhasil diambil!'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
      // Direct opening order detail upon accepting the order
      context.push('/orders/detail/$orderId');
    } else {
      final error = ref.read(exploreOrdersProvider).error ?? 'Gagal mengambil pesanan';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
