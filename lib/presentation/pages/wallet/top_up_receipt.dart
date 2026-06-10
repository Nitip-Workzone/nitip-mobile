import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';

import '../../../core/theme/app_colors.dart';
import '../../../domain/models/wallet_model.dart';
import '../../providers/wallet_provider.dart';

final _currencyFmt = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
final _dateFmt = DateFormat('dd MMM yyyy, HH:mm', 'id_ID');

Future<void> showTopUpReceipt(BuildContext context, WalletTransactionModel tx) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    useRootNavigator: true,
    builder: (_) => _ReceiptSheet(initialTx: tx),
  );
}

class _ReceiptSheet extends ConsumerStatefulWidget {
  final WalletTransactionModel initialTx;
  const _ReceiptSheet({required this.initialTx});

  @override
  ConsumerState<_ReceiptSheet> createState() => _ReceiptSheetState();
}

class _ReceiptSheetState extends ConsumerState<_ReceiptSheet> {
  late WalletTransactionModel tx;
  final GlobalKey _qrKey = GlobalKey();
  bool _isChecking = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    tx = widget.initialTx;
  }

  Future<void> _checkStatus() async {
    if (tx.reference == null) return;
    setState(() => _isChecking = true);
    
    final updatedTx = await ref.read(walletProvider.notifier).checkTransactionStatus(tx.reference!);
    
    if (mounted) {
      setState(() {
        _isChecking = false;
        if (updatedTx != null) {
          tx = updatedTx;
        }
      });
      
      if (tx.status == 'completed') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pembayaran berhasil!'), backgroundColor: AppColors.success),
        );
      } else if (tx.status == 'failed') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pembayaran gagal.'), backgroundColor: AppColors.error),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pembayaran belum diterima.'), backgroundColor: AppColors.warning),
        );
      }
    }
  }

  Future<void> _downloadQr() async {
    try {
      setState(() => _isSaving = true);
      RenderRepaintBoundary boundary = _qrKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      
      if (byteData != null) {
        final result = await ImageGallerySaverPlus.saveImage(
          byteData.buffer.asUint8List(),
          quality: 100,
          name: "QRIS_${tx.reference ?? 'TOPUP'}",
        );
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['isSuccess'] ? 'QR Code berhasil disimpan ke galeri' : 'Gagal menyimpan QR Code'),
              backgroundColor: result['isSuccess'] ? AppColors.success : AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Color get _statusColor {
    switch (tx.status) {
      case 'completed': return AppColors.success;
      case 'failed': return AppColors.error;
      default: return AppColors.warning;
    }
  }

  IconData get _statusIcon {
    switch (tx.status) {
      case 'completed': return Icons.check_circle_rounded;
      case 'failed': return Icons.cancel_rounded;
      default: return Icons.schedule_rounded;
    }
  }

  String get _statusLabel {
    switch (tx.status) {
      case 'completed': return 'Berhasil';
      case 'failed': return 'Gagal';
      default: return 'Menunggu Konfirmasi';
    }
  }

  String get _statusDesc {
    if (tx.status == 'pending' && tx.qrisString != null) {
      return 'Silakan scan kode QRIS berikut untuk menyelesaikan pembayaran.';
    }
    switch (tx.status) {
      case 'completed': return 'Top up telah berhasil dan saldo kamu sudah bertambah.';
      case 'failed': return 'Top up gagal diproses. Silakan coba lagi.';
      default: return 'Top up sedang menunggu konfirmasi dari admin. Saldo akan masuk setelah disetujui.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor;
    final showQr = tx.status == 'pending' && tx.qrisString != null;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(24, 0, 24, MediaQuery.of(context).padding.bottom + 24),
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Handle bar ────────────────────────────────────────────────
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
            ),

            // ── Status icon ───────────────────────────────────────────────
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(_statusIcon, color: statusColor, size: 36),
            ),
            const SizedBox(height: 16),
            Text(
              _statusLabel,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: statusColor),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                _statusDesc,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: AppColors.textMuted, height: 1.5),
              ),
            ),

            const SizedBox(height: 24),

            // ── QR Code ───────────────────────────────────────────────────
            if (showQr) ...[
              RepaintBoundary(
                key: _qrKey,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      QrImageView(
                        data: tx.qrisString!,
                        version: QrVersions.auto,
                        size: 200.0,
                        backgroundColor: Colors.white,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.qr_code_scanner_rounded, size: 16, color: AppColors.textMuted),
                          const SizedBox(width: 8),
                          Text('QRIS Pembayaran', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isSaving ? null : _downloadQr,
                      icon: _isSaving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.download_rounded, size: 18),
                      label: const Text('Simpan QR'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isChecking ? null : _checkStatus,
                      icon: _isChecking ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Cek Status'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],

            // ── Amount besar ──────────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  const Text('Nominal Top Up',
                      style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                  const SizedBox(height: 6),
                  Text(
                    _currencyFmt.format(tx.amount),
                    style: const TextStyle(
                        fontSize: 30, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Detail rows ───────────────────────────────────────────────
            _DetailCard(
              rows: [
                _DetailRow(
                  label: 'Kode Referensi',
                  value: tx.reference ?? '-',
                  copyable: tx.reference != null,
                ),
                _DetailRow(label: 'Status', value: _statusLabel, valueColor: statusColor),
                _DetailRow(label: 'Tipe', value: _typeLabel(tx.type)),
                _DetailRow(label: 'Tanggal', value: _dateFmt.format(tx.createdAt.toLocal())),
              ],
            ),

            const SizedBox(height: 24),

            // ── CTA ───────────────────────────────────────────────────────
            if (!showQr)
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Selesai', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'TOP_UP': return 'Top Up';
      case 'WITHDRAWAL': return 'Penarikan';
      case 'ESCROW_HOLD': return 'Escrow Tahan';
      case 'ESCROW_RELEASE': return 'Escrow Lepas';
      case 'REFUND': return 'Pengembalian Dana';
      default: return type;
    }
  }
}

// ── Subwidgets ────────────────────────────────────────────────────────────────

class _DetailCard extends StatelessWidget {
  final List<_DetailRow> rows;
  const _DetailCard({required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: rows.asMap().entries.map((e) {
          final isLast = e.key == rows.length - 1;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(e.value.label,
                        style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              e.value.value,
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: e.value.valueColor ?? const Color(0xFF0F172A),
                                fontFamily: e.value.copyable ? 'monospace' : null,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (e.value.copyable) ...[
                            const SizedBox(width: 6),
                            GestureDetector(
                              onTap: () {
                                Clipboard.setData(ClipboardData(text: e.value.value));
                              },
                              child: const Icon(Icons.copy_rounded,
                                  size: 14, color: AppColors.textMuted),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (!isLast)
                const Divider(height: 1, indent: 16, endIndent: 16, color: AppColors.border),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _DetailRow {
  final String label;
  final String value;
  final Color? valueColor;
  final bool copyable;
  const _DetailRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.copyable = false,
  });
}
