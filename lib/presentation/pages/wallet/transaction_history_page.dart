import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../domain/models/wallet_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/wallet_provider.dart';
import '../wallet/top_up_receipt.dart';

final _currencyFmt = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
final _timeFmt = DateFormat('HH:mm', 'id_ID');
final _groupFmt = DateFormat('EEEE, dd MMM yyyy', 'id_ID');

class TransactionHistoryPage extends ConsumerStatefulWidget {
  const TransactionHistoryPage({super.key});

  @override
  ConsumerState<TransactionHistoryPage> createState() => _TransactionHistoryPageState();
}

class _TransactionHistoryPageState extends ConsumerState<TransactionHistoryPage> {
  String _selectedFilter = 'all'; // all, top_up, withdrawal, escrow
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(walletProvider.notifier).fetchTransactions();
    });
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 200) {
      // Only load more if filter is 'all' — cursor only applies to unfiltered list
      if (_selectedFilter == 'all') {
        ref.read(walletProvider.notifier).loadMoreTransactions();
      }
    }
  }

  List<WalletTransactionModel> _filterTx(List<WalletTransactionModel> txs) {
    if (_selectedFilter == 'all') return txs;
    return txs.where((t) => t.type.toLowerCase().contains(_selectedFilter)).toList();
  }

  // Group transaksi by tanggal
  Map<String, List<WalletTransactionModel>> _groupByDate(List<WalletTransactionModel> txs) {
    final Map<String, List<WalletTransactionModel>> groups = {};
    for (final tx in txs) {
      final local = tx.createdAt.toLocal();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      final txDate = DateTime(local.year, local.month, local.day);

      String label;
      if (txDate == today) {
        label = 'Hari Ini';
      } else if (txDate == yesterday) {
        label = 'Kemarin';
      } else {
        label = _groupFmt.format(local);
      }

      groups.putIfAbsent(label, () => []).add(tx);
    }
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final walletState = ref.watch(walletProvider);
    final isRunner = authState.user?.isRunner ?? false;
    final primary = isRunner ? AppColors.secondary : AppColors.primary;

    final filtered = _filterTx(walletState.transactions);
    final grouped = _groupByDate(filtered);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
          color: const Color(0xFF0F172A),
        ),
        title: const Text(
          'Riwayat Transaksi',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // ── Balance card ──────────────────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    primary,
                    AppColors.primaryMid,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: primary.withValues(alpha: 0.28),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.account_balance_wallet_rounded,
                                  color: Colors.white, size: 14),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Nitip Pay',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white70,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        walletState.isLoading
                            ? Container(
                                width: 130,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              )
                            : Text(
                                _currencyFmt.format(walletState.wallet?.balance ?? 0),
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: -0.5,
                                ),
                              ),
                        const SizedBox(height: 4),
                        const Text(
                          'Saldo Tersedia',
                          style: TextStyle(fontSize: 11, color: Colors.white60),
                        ),
                      ],
                    ),
                  ),
                  // Decorative circle
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.receipt_long_rounded,
                      color: Colors.white54,
                      size: 28,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Filter chips ──────────────────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _FilterChip(
                    label: 'Semua',
                    selected: _selectedFilter == 'all',
                    primary: primary,
                    onTap: () => setState(() => _selectedFilter = 'all'),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Top Up',
                    selected: _selectedFilter == 'top_up',
                    primary: primary,
                    onTap: () => setState(() => _selectedFilter = 'top_up'),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Penarikan',
                    selected: _selectedFilter == 'withdrawal',
                    primary: primary,
                    onTap: () => setState(() => _selectedFilter = 'withdrawal'),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Escrow',
                    selected: _selectedFilter == 'escrow',
                    primary: primary,
                    onTap: () => setState(() => _selectedFilter = 'escrow'),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Refund',
                    selected: _selectedFilter == 'refund',
                    primary: primary,
                    onTap: () => setState(() => _selectedFilter = 'refund'),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 8),

          // ── Transaction list ──────────────────────────────────────────
          Expanded(
            child: RefreshIndicator(
              color: primary,
              onRefresh: () async {
                await ref.read(walletProvider.notifier).fetchBalance();
                await ref.read(walletProvider.notifier).fetchTransactions();
              },
              child: walletState.isLoading && walletState.transactions.isEmpty
                  ? _TransactionSkeleton()
                  : filtered.isEmpty
                      ? _EmptyState(primary: primary)
                      : ListView(
                          controller: _scrollCtrl,
                          padding: const EdgeInsets.only(bottom: 32),
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            ...grouped.entries.map((entry) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Tanggal group header
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                                    child: Text(
                                      entry.key,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textMuted,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ),
                                  // Items dalam group
                                  Container(
                                    margin: const EdgeInsets.symmetric(horizontal: 16),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: AppColors.border),
                                    ),
                                    child: Column(
                                      children: entry.value.asMap().entries.map((e) {
                                        final isLast = e.key == entry.value.length - 1;
                                        return Column(
                                          children: [
                                            _TransactionItem(
                                              tx: e.value,
                                              primary: primary,
                                              onTap: () => showTopUpReceipt(context, e.value),
                                            ),
                                            if (!isLast)
                                              const Divider(
                                                height: 1,
                                                indent: 68,
                                                endIndent: 16,
                                                color: AppColors.border,
                                              ),
                                          ],
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ],
                              );
                            }),
                            // ── Load-more indicator ───────────────────────
                            if (walletState.isLoadingMore)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 20),
                                child: Center(
                                  child: SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: primary,
                                    ),
                                  ),
                                ),
                              )
                            else if (!walletState.hasMore && walletState.transactions.isNotEmpty && _selectedFilter == 'all')
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 20),
                                child: Center(
                                  child: Text(
                                    'Semua transaksi telah ditampilkan',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textMuted.withValues(alpha: 0.7),
                                    ),
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

// ── Subwidgets ────────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color primary;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.selected, required this.primary, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? primary : AppColors.surface,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: selected ? primary : AppColors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}

class _TransactionItem extends StatelessWidget {
  final WalletTransactionModel tx;
  final Color primary;
  final VoidCallback onTap;

  const _TransactionItem({required this.tx, required this.primary, required this.onTap});

  _TxMeta get _meta => _txMeta(tx.type);

  bool get _isCredit => tx.amount >= 0;

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(tx.status);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            // Icon container
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _meta.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(_meta.icon, color: _meta.color, size: 22),
            ),
            const SizedBox(width: 12),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _meta.label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      // Status badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _statusLabel(tx.status),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: statusColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _timeFmt.format(tx.createdAt.toLocal()),
                        style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Amount
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${_isCredit ? '+' : ''}${_currencyFmt.format(tx.amount)}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: _isCredit ? AppColors.success : AppColors.error,
                  ),
                ),
                const SizedBox(height: 2),
                const Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.textMuted),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'completed':
        return AppColors.success;
      case 'failed':
        return AppColors.error;
      default:
        return AppColors.warning;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'completed':
        return 'Selesai';
      case 'failed':
        return 'Gagal';
      default:
        return 'Pending';
    }
  }
}

class _TxMeta {
  final String label;
  final IconData icon;
  final Color color;
  const _TxMeta(this.label, this.icon, this.color);
}

_TxMeta _txMeta(String type) {
  switch (type) {
    case 'TOP_UP':
      return const _TxMeta('Top Up', Icons.add_circle_rounded, Color(0xFF2563EB));
    case 'WITHDRAWAL':
      return const _TxMeta('Penarikan', Icons.arrow_circle_up_rounded, Color(0xFFDC2626));
    case 'ESCROW_HOLD':
      return const _TxMeta('Dana Tahan (Escrow)', Icons.lock_rounded, Color(0xFFF59E0B));
    case 'ESCROW_RELEASE':
      return const _TxMeta('Dana Cair (Escrow)', Icons.lock_open_rounded, Color(0xFF059669));
    case 'PLATFORM_FEE':
      return const _TxMeta('Biaya Platform', Icons.percent_rounded, Color(0xFF6B7280));
    case 'REFUND':
      return const _TxMeta('Pengembalian Dana', Icons.replay_rounded, Color(0xFF7C3AED));
    default:
      return const _TxMeta('Transaksi', Icons.swap_horiz_rounded, AppColors.textMuted);
  }
}

// ── Empty State ───────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final Color primary;
  const _EmptyState({required this.primary});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Icon(Icons.receipt_long_outlined, size: 40, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 20),
                  const Text('Belum Ada Transaksi',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                  const SizedBox(height: 8),
                  const Text(
                    'Riwayat top up, pembayaran, dan escrow akan tampil di sini.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: AppColors.textMuted, height: 1.5),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Skeleton ──────────────────────────────────────────────────────────────────
class _TransactionSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      itemCount: 6,
      itemBuilder: (_, i) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        height: 68,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const SizedBox(width: 16),
            _SkeletonBox(width: 44, height: 44, radius: 14),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _SkeletonBox(width: 100, height: 14),
                  const SizedBox(height: 8),
                  _SkeletonBox(width: 70, height: 10),
                ],
              ),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _SkeletonBox(width: 80, height: 14),
              ],
            ),
            const SizedBox(width: 16),
          ],
        ),
      ),
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  final double width, height, radius;
  const _SkeletonBox({required this.width, required this.height, this.radius = 8});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.border,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
