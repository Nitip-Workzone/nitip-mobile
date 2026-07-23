import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../providers/activity_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../widgets/orders/order_card.dart';

class OrdersTab extends ConsumerStatefulWidget {
  const OrdersTab({super.key});

  @override
  ConsumerState<OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends ConsumerState<OrdersTab> {
  final _activeScrollCtrl = ScrollController();
  final _pastScrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(activityProvider.notifier).fetchActivities(force: true);
    });

    _activeScrollCtrl.addListener(_onActiveScroll);
    _pastScrollCtrl.addListener(_onPastScroll);
  }

  @override
  void dispose() {
    _activeScrollCtrl.dispose();
    _pastScrollCtrl.dispose();
    super.dispose();
  }

  void _onActiveScroll() {
    if (_activeScrollCtrl.position.pixels >= _activeScrollCtrl.position.maxScrollExtent - 150) {
      ref.read(activityProvider.notifier).loadMore();
    }
  }

  void _onPastScroll() {
    if (_pastScrollCtrl.position.pixels >= _pastScrollCtrl.position.maxScrollExtent - 150) {
      ref.read(activityProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final activityState = ref.watch(activityProvider);
    final user = ref.watch(authProvider).user;
    final isRunner = user?.isRunner ?? false;
    final primary = isRunner ? AppColors.secondary : AppColors.primary;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(
            isRunner ? 'Aktivitas Saya' : 'Pesanan Saya',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: AppColors.textMain),
          ),
          centerTitle: false,
          backgroundColor: Colors.white,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: AppColors.textMain),
              onPressed: () => ref.read(activityProvider.notifier).fetchActivities(force: true),
            ),
          ],
          bottom: TabBar(
            indicatorColor: primary,
            indicatorWeight: 3,
            labelColor: primary,
            unselectedLabelColor: AppColors.textMuted,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            tabs: [
              Tab(text: isRunner ? 'Tugas Aktif' : 'Aktif'),
              const Tab(text: 'Riwayat'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            RefreshIndicator(
              onRefresh: () => ref.read(activityProvider.notifier).fetchActivities(force: true),
              color: primary,
              child: _buildList(activityState.activeOrders, primary, activityState, true, _activeScrollCtrl),
            ),
            RefreshIndicator(
              onRefresh: () => ref.read(activityProvider.notifier).fetchActivities(force: true),
              color: primary,
              child: _buildList(activityState.pastOrders, primary, activityState, false, _pastScrollCtrl),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(List<dynamic> items, Color primary, ActivityState state, bool isActiveTab, ScrollController scrollCtrl) {
    if (state.isLoading && !state.hasFetched) {
      return const Center(child: CircularProgressIndicator());
    }

    if (items.isEmpty && !state.isLoadingMore) {
      return _buildEmptyState(isActiveTab);
    }

    return ListView.builder(
      controller: scrollCtrl,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      // +1 for loader indicator at the bottom
      itemCount: items.length + (state.isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        // Load-more spinner at the bottom
        if (index == items.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: primary),
              ),
            ),
          );
        }

        final item = items[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: OrderCard(
            order: item,
            primaryColor: primary,
            onTap: () => context.push('/orders/detail/${item.id}'),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(bool isActiveTab) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isActiveTab ? Icons.assignment_outlined : Icons.history_rounded,
            size: 64,
            color: AppColors.textMuted.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            isActiveTab ? 'Belum ada aktivitas aktif' : 'Belum ada riwayat pesanan',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textMain),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tarik layar ke bawah untuk memperbarui',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}
