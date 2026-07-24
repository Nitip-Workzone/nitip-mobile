import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../providers/review_provider.dart';

class SubmitReviewPage extends ConsumerStatefulWidget {
  final String orderId;
  final String? runnerName;

  const SubmitReviewPage({super.key, required this.orderId, this.runnerName});

  @override
  ConsumerState<SubmitReviewPage> createState() => _SubmitReviewPageState();
}

class _SubmitReviewPageState extends ConsumerState<SubmitReviewPage> {
  int _rating = 0;
  final _commentController = TextEditingController();
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(reviewProvider(widget.orderId).notifier).fetchReview(widget.orderId);
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reviewState = ref.watch(reviewProvider(widget.orderId));

    if (reviewState.review != null && !_submitted) {
      return _buildAlreadyReviewed(context, reviewState);
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Beri Review', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.textMain)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: AppColors.textMain),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 16),
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(color: AppColors.secondaryLight, shape: BoxShape.circle),
              child: const Icon(Icons.person_rounded, size: 40, color: AppColors.secondary),
            ),
            const SizedBox(height: 16),
            Text(widget.runnerName ?? 'Runner', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textMain)),
            const SizedBox(height: 8),
            const Text('Bagaimana pengalaman Anda dengan Runner ini?', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: AppColors.textMuted)),
            const SizedBox(height: 32),
            _buildStarRating(),
            const SizedBox(height: 8),
            Text(_getRatingLabel(), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _rating > 0 ? AppColors.secondary : AppColors.textMuted)),
            const SizedBox(height: 32),
            Align(alignment: Alignment.centerLeft, child: const Text('Komentar (opsional)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textMain))),
            const SizedBox(height: 8),
            TextField(
              controller: _commentController,
              maxLines: 4,
              maxLength: 500,
              decoration: InputDecoration(
                hintText: 'Ceritakan pengalaman Anda...',
                hintStyle: const TextStyle(color: AppColors.textMuted),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.secondary, width: 2)),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _rating > 0 && !reviewState.isSubmitting ? () => _handleSubmit() : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.border,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: reviewState.isSubmitting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Kirim Review', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStarRating() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (index) {
        final starIndex = index + 1;
        return GestureDetector(
          onTap: () => setState(() => _rating = starIndex),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Icon(
              starIndex <= _rating ? Icons.star_rounded : Icons.star_border_rounded,
              size: 48,
              color: starIndex <= _rating ? const Color(0xFFFBBF24) : AppColors.border,
            ),
          ),
        );
      }),
    );
  }

  String _getRatingLabel() {
    switch (_rating) {
      case 1: return 'Sangat Buruk';
      case 2: return 'Buruk';
      case 3: return 'Cukup';
      case 4: return 'Bagus';
      case 5: return 'Sangat Bagus';
      default: return 'Pilih rating';
    }
  }

  Widget _buildAlreadyReviewed(BuildContext context, ReviewState reviewState) {
    final review = reviewState.review!;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Review Anda', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.textMain)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.close_rounded, color: AppColors.textMain), onPressed: () => Navigator.pop(context)),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle_rounded, size: 64, color: AppColors.success),
              const SizedBox(height: 16),
              const Text('Review Sudah Dikirim', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textMain)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return Icon(
                    index < (review.runnerRating ?? 0) ? Icons.star_rounded : Icons.star_border_rounded,
                    size: 32,
                    color: index < (review.runnerRating ?? 0) ? const Color(0xFFFBBF24) : AppColors.border,
                  );
                }),
              ),
              if (review.runnerComment != null && review.runnerComment!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                  child: Text(review.runnerComment!, style: const TextStyle(fontSize: 14, color: AppColors.textMain, height: 1.5)),
                ),
              ],
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.secondary, side: const BorderSide(color: AppColors.secondary), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: const Text('Kembali', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleSubmit() async {
    final comment = _commentController.text.trim();
    final success = await ref.read(reviewProvider(widget.orderId).notifier).submitRequesterReview(widget.orderId, _rating, comment.isEmpty ? null : comment);

    if (!mounted) return;

    if (success) {
      _submitted = true;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Review berhasil dikirim!'), backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating));
      context.pop(true);
    } else {
      final error = ref.read(reviewProvider(widget.orderId)).error ?? 'Gagal mengirim review';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), backgroundColor: AppColors.error, behavior: SnackBarBehavior.floating));
    }
  }
}
