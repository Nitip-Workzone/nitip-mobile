import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/wallet_model.dart';
import '../../domain/repositories/wallet_repository.dart';
import '../../data/repositories/wallet_repository_impl.dart';
import 'auth_provider.dart';

// Provider untuk WalletRepository
final walletRepositoryProvider = Provider<WalletRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return WalletRepositoryImpl(apiClient);
});

// State untuk Wallet
class WalletState {
  final bool isLoading;
  final String? error;
  final WalletModel? wallet;
  final List<WalletTransactionModel> transactions;
  final bool hasFetched;
  final bool isLoadingMore;
  final bool hasMore;
  final int currentPage;

  WalletState({
    this.isLoading = false,
    this.error,
    this.wallet,
    this.transactions = const [],
    this.hasFetched = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.currentPage = 1,
  });

  WalletState copyWith({
    bool? isLoading,
    String? error,
    WalletModel? wallet,
    List<WalletTransactionModel>? transactions,
    bool? hasFetched,
    bool? isLoadingMore,
    bool? hasMore,
    int? currentPage,
  }) {
    return WalletState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      wallet: wallet ?? this.wallet,
      transactions: transactions ?? this.transactions,
      hasFetched: hasFetched ?? this.hasFetched,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      currentPage: currentPage ?? this.currentPage,
    );
  }
}

// Notifier untuk Wallet
class WalletNotifier extends StateNotifier<WalletState> {
  final WalletRepository _repository;
  static const int _limit = 20;

  WalletNotifier(this._repository) : super(WalletState()) {
    // Otomatis fetch balance saat diinisialisasi
    fetchBalance();
  }

  Future<void>? _balanceFuture;

  Future<void> fetchBalance({bool force = false}) async {
    if (state.hasFetched && !force) return;
    if (_balanceFuture != null) return _balanceFuture;

    _balanceFuture = _performFetchBalance();
    try {
      await _balanceFuture;
    } finally {
      _balanceFuture = null;
    }
  }

  Future<void> _performFetchBalance() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final wallet = await _repository.getBalance();
      state = state.copyWith(isLoading: false, wallet: wallet, hasFetched: true);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> fetchTransactions() async {
    state = state.copyWith(isLoading: true, error: null, currentPage: 1, transactions: []);
    try {
      final transactions = await _repository.getTransactions(page: 1, limit: _limit);
      state = state.copyWith(
        isLoading: false,
        transactions: transactions,
        currentPage: 1,
        hasMore: transactions.length == _limit,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadMoreTransactions() async {
    if (state.isLoadingMore || !state.hasMore || state.isLoading) return;

    state = state.copyWith(isLoadingMore: true, error: null);
    try {
      final nextPage = state.currentPage + 1;
      final more = await _repository.getTransactions(page: nextPage, limit: _limit);
      state = state.copyWith(
        isLoadingMore: false,
        transactions: [...state.transactions, ...more],
        currentPage: nextPage,
        hasMore: more.length == _limit,
      );
    } catch (e) {
      state = state.copyWith(isLoadingMore: false, error: e.toString());
    }
  }

  Future<WalletTransactionModel?> topUp(double amount) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final tx = await _repository.initiateTopUp(amount);
      // Refresh balance (walaupun mungkin masih PENDING, agar sinkron dengan BE)
      await fetchBalance(force: true);
      return tx;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return null;
    }
  }

  Future<WalletTransactionModel?> checkTransactionStatus(String reference) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final tx = await _repository.getTransactionStatus(reference);
      // Sinkronkan balance jika status sudah berubah
      await fetchBalance(force: true);
      await fetchTransactions(); // Refresh list if we are on the transaction page
      state = state.copyWith(isLoading: false);
      return tx;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return null;
    }
  }

  Future<void> refreshAfterTransaction() async {
    await fetchBalance(force: true);
    await fetchTransactions();
  }

  Future<String?> inquiryAccount({
    required String channelCode,
    required String accountNo,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final name = await _repository.inquiryAccount(
        channelCode: channelCode,
        accountNo: accountNo,
      );
      state = state.copyWith(isLoading: false);
      return name;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return null;
    }
  }

  Future<WalletTransactionModel?> withdraw({
    required double amount,
    required String channelId,
    required String pin,
    required Map<String, dynamic> metadata,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final tx = await _repository.requestWithdrawal(
        amount: amount,
        channelId: channelId,
        pin: pin,
        metadata: metadata,
      );
      await fetchBalance(force: true);
      await fetchTransactions();
      return tx;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return null;
    }
  }
}

// Provider untuk WalletNotifier
final walletProvider = StateNotifierProvider<WalletNotifier, WalletState>((ref) {
  final repository = ref.watch(walletRepositoryProvider);
  return WalletNotifier(repository);
});

// Provider untuk visibilitas saldo (lokal)
final balanceVisibilityProvider = StateProvider<bool>((ref) => true);

// Provider untuk mengambil daftar channel penarikan
final withdrawalChannelsProvider = FutureProvider<List<WithdrawalChannelModel>>((ref) async {
  final repository = ref.watch(walletRepositoryProvider);
  return repository.getWithdrawalChannels();
});
