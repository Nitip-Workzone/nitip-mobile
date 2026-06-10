import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../domain/models/order_model.dart';
import '../../providers/explore_orders_provider.dart';
import '../../providers/activity_provider.dart';
import '../../widgets/orders/order_card.dart';

class ExploreOrdersPage extends ConsumerStatefulWidget {
  const ExploreOrdersPage({super.key});

  @override
  ConsumerState<ExploreOrdersPage> createState() => _ExploreOrdersPageState();
}

class _ExploreOrdersPageState extends ConsumerState<ExploreOrdersPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    Future.microtask(() {
      ref.read(exploreOrdersProvider.notifier).fetchAvailableOrders();
      ref.read(activityProvider.notifier).fetchActivities();
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
    
    final activeOrders = activityState.activeOrders;
    final availableOrders = state.availableOrders;

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
        bottom: TabBar(
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
