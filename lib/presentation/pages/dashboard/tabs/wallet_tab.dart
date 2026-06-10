import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../domain/models/wallet_model.dart';
import '../../../providers/wallet_provider.dart';
import '../../wallet/top_up_sheet.dart';
import '../../wallet/top_up_receipt.dart';

final _currencyFmt = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
final _timeFmt = DateFormat('HH:mm', 'id_ID');

class WalletTab extends ConsumerStatefulWidget {
  const WalletTab({super.key});

  @override
  ConsumerState<WalletTab> createState() => _WalletTabState();
}

class _WalletTabState extends ConsumerState<WalletTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(walletProvider.notifier).fetchBalance(force: true);
      ref.read(walletProvider.notifier).fetchTransactions();
    });
  }

  @override
  Widget build(BuildContext context) {
    final walletState = ref.watch(walletProvider);
    final isObscured = !ref.watch(balanceVisibilityProvider);
    final primary = AppColors.secondary; // Runner primary color

    // Limit to latest 5 transactions for preview
    final recentTransactions = walletState.transactions.take(5).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Dompet Runner',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: Color(0xFF0F172A),
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF0F172A)),
            onPressed: () {
              ref.read(walletProvider.notifier).fetchBalance(force: true);
              ref.read(walletProvider.notifier).fetchTransactions();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        color: primary,
        onRefresh: () async {
          await ref.read(walletProvider.notifier).fetchBalance(force: true);
          await ref.read(walletProvider.notifier).fetchTransactions();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Top Balance Card ──────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        primary,
                        primary.withBlue(160).withGreen(140),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: primary.withValues(alpha: 0.24),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
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
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.account_balance_wallet_rounded,
                                  color: Colors.white,
                                  size: 14,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Saldo Aktif',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: Icon(
                              isObscured ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                              color: Colors.white70,
                              size: 20,
                            ),
                            onPressed: () {
                              ref.read(balanceVisibilityProvider.notifier).state = !isObscured;
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      walletState.isLoading && walletState.wallet == null
                          ? Container(
                              width: 140,
                              height: 32,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                            )
                          : Text(
                              isObscured
                                  ? '••••••'
                                  : _currencyFmt.format(walletState.wallet?.balance ?? 0),
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: -0.5,
                              ),
                            ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => context.push('/wallet/withdraw'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: primary,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              icon: const Icon(Icons.arrow_upward_rounded, size: 18),
                              label: const Text(
                                'Tarik Saldo',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => showTopUpSheet(context, ref, primary),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white.withValues(alpha: 0.18),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                side: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.25),
                                  width: 1,
                                ),
                              ),
                              icon: const Icon(Icons.add_rounded, size: 18),
                              label: const Text(
                                'Top Up',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // ── Quick Info Stats ──────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey.shade100),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Total Pendapatan',
                              style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isObscured ? '••••••' : _currencyFmt.format(_calculateTotalEarnings(walletState.transactions)),
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(width: 1, height: 32, color: Colors.grey.shade100),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Total Penarikan',
                              style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isObscured ? '••••••' : _currencyFmt.format(_calculateTotalWithdrawals(walletState.transactions)),
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // ── Transactions Section Header ────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Transaksi Terakhir',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.3,
                      ),
                    ),
                    if (walletState.transactions.isNotEmpty)
                      TextButton(
                        onPressed: () => context.push('/wallet/history'),
                        child: Text(
                          'Lihat Semua',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: primary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // ── Transactions List ──────────────────────────────────────────
              const SizedBox(height: 8),
              if (walletState.isLoading && walletState.transactions.isEmpty)
                const _TabSkeletonList()
              else if (recentTransactions.isEmpty)
                const _TabEmptyState()
              else
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey.shade100),
                  ),
                  child: Column(
                    children: recentTransactions.asMap().entries.map((e) {
                      final isLast = e.key == recentTransactions.length - 1;
                      return Column(
                        children: [
                          _TransactionTile(
                            tx: e.value,
                            primary: primary,
                            onTap: () => showTopUpReceipt(context, e.value),
                          ),
                          if (!isLast)
                            Divider(
                              height: 1,
                              indent: 68,
                              endIndent: 16,
                              color: Colors.grey.shade100,
                            ),
                        ],
                      );
                    }).toList(),
                  ),
                ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  double _calculateTotalEarnings(List<WalletTransactionModel> txs) {
    double total = 0;
    for (final tx in txs) {
      if (tx.status == 'completed' && (tx.type == 'ESCROW_RELEASE' || tx.type == 'REFUND')) {
        total += tx.amount;
      }
    }
    return total;
  }

  double _calculateTotalWithdrawals(List<WalletTransactionModel> txs) {
    double total = 0;
    for (final tx in txs) {
      if (tx.status == 'completed' && tx.type == 'WITHDRAWAL') {
        total += tx.amount.abs();
      }
    }
    return total;
  }
}

class _TransactionTile extends StatelessWidget {
  final WalletTransactionModel tx;
  final Color primary;
  final VoidCallback onTap;

  const _TransactionTile({
    required this.tx,
    required this.primary,
    required this.onTap,
  });

  _TileMeta get _meta => _tileMeta(tx.type);

  bool get _isCredit => tx.amount >= 0;

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(tx.status);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            // Icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _meta.color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_meta.icon, color: _meta.color, size: 20),
            ),
            const SizedBox(width: 12),

            // Text info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _meta.label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _statusLabel(tx.status),
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            color: statusColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
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
                    fontWeight: FontWeight.w900,
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

class _TileMeta {
  final String label;
  final IconData icon;
  final Color color;
  const _TileMeta(this.label, this.icon, this.color);
}

_TileMeta _tileMeta(String type) {
  switch (type) {
    case 'TOP_UP':
      return const _TileMeta('Top Up', Icons.add_circle_rounded, Color(0xFF2563EB));
    case 'WITHDRAWAL':
      return const _TileMeta('Penarikan', Icons.arrow_circle_up_rounded, Color(0xFFDC2626));
    case 'ESCROW_HOLD':
      return const _TileMeta('Dana Tahan (Escrow)', Icons.lock_rounded, Color(0xFFF59E0B));
    case 'ESCROW_RELEASE':
      return const _TileMeta('Dana Cair (Escrow)', Icons.lock_open_rounded, Color(0xFF059669));
    case 'PLATFORM_FEE':
      return const _TileMeta('Biaya Platform', Icons.percent_rounded, Color(0xFF6B7280));
    case 'REFUND':
      return const _TileMeta('Pengembalian Dana', Icons.replay_rounded, Color(0xFF7C3AED));
    default:
      return const _TileMeta('Transaksi', Icons.swap_horiz_rounded, AppColors.textMuted);
  }
}

class _TabEmptyState extends StatelessWidget {
  const _TabEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey.shade100),
              ),
              child: const Icon(Icons.receipt_long_outlined, size: 36, color: AppColors.textMuted),
            ),
            const SizedBox(height: 16),
            const Text(
              'Belum Ada Transaksi',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 6),
            const Text(
              'Mutasi pendapatan dan penarikan saldo Anda akan ditampilkan di sini.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: AppColors.textMuted, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabSkeletonList extends StatelessWidget {
  const _TabSkeletonList();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: List.generate(
          3,
          (index) => Container(
            margin: const EdgeInsets.only(bottom: 12),
            height: 68,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade100),
            ),
          ),
        ),
      ),
    );
  }
}
