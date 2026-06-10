import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/theme/app_colors.dart';
import '../../providers/location_provider.dart';
import '../../providers/trip_provider.dart';
import '../../widgets/common/location_picker_sheet.dart';

class OpenTripSheet extends ConsumerStatefulWidget {
  const OpenTripSheet({super.key});

  @override
  ConsumerState<OpenTripSheet> createState() => _OpenTripSheetState();
}

class _OpenTripSheetState extends ConsumerState<OpenTripSheet> {
  final _formKey = GlobalKey<FormState>();

  // Popular Makassar locations for quick simulation
  final List<Map<String, dynamic>> _locations = [
    {
      'name': 'Bandara Hasanuddin Makassar',
      'lat': -5.068478,
      'lng': 119.553205,
    },
    {
      'name': 'Mall Panakkukang Makassar',
      'lat': -5.155490,
      'lng': 119.444315,
    },
    {
      'name': 'Kampus UNHAS Tamalanrea',
      'lat': -5.127810,
      'lng': 119.493210,
    },
    {
      'name': 'Rappocini / Balla Parang',
      'lat': -5.147598,
      'lng': 119.432698,
    },
    {
      'name': 'Pantai Losari',
      'lat': -5.144130,
      'lng': 119.408240,
    },
    {
      'name': 'Jl. Riburane / Makassar Kota',
      'lat': -5.111890,
      'lng': 119.508560,
    },
  ];

  LatLng? _originLocation;
  String? _originAddress;
  LatLng? _destinationLocation;
  String? _destinationAddress;
  DateTime _departureDateTime = DateTime.now().add(const Duration(hours: 2));
  String _vehicleType = 'motorcycle';
  final _weightController = TextEditingController(text: '15.0');
  final _volumeController = TextEditingController(text: '10.0');
  final _notesController = TextEditingController();
  bool _isRoundTrip = false;

  @override
  void initState() {
    super.initState();
    _originLocation = LatLng(_locations[0]['lat'], _locations[0]['lng']);
    _originAddress = _locations[0]['name'];
    _destinationLocation = LatLng(_locations[1]['lat'], _locations[1]['lng']);
    _destinationAddress = _locations[1]['name'];
  }

  @override
  void dispose() {
    _weightController.dispose();
    _volumeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectDateTime() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _departureDateTime,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.secondary,
              onPrimary: Colors.white,
              onSurface: AppColors.textMain,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null) {
      if (!mounted) return;
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_departureDateTime),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.light(
                primary: AppColors.secondary,
                onPrimary: Colors.white,
                onSurface: AppColors.textMain,
              ),
            ),
            child: child!,
          );
        },
      );

      if (pickedTime != null) {
        setState(() {
          _departureDateTime = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      }
    }
  }

  void _submit() async {
    if (_formKey.currentState!.validate()) {
      if (_originAddress == _destinationAddress || 
          (_originLocation != null && _destinationLocation != null &&
           _originLocation!.latitude == _destinationLocation!.latitude && 
           _originLocation!.longitude == _destinationLocation!.longitude)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lokasi asal dan tujuan tidak boleh sama!'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      final payload = {
        'origin_name': _originAddress,
        'origin_lat': _originLocation?.latitude,
        'origin_lng': _originLocation?.longitude,
        'destination_name': _destinationAddress,
        'destination_lat': _destinationLocation?.latitude,
        'destination_lng': _destinationLocation?.longitude,
        'departure_time': _departureDateTime.toUtc().toIso8601String(),
        'vehicle_type': _vehicleType,
        'max_weight_kg': double.tryParse(_weightController.text) ?? 15.0,
        'max_volume_liters': double.tryParse(_volumeController.text) ?? 10.0,
        'is_round_trip': _isRoundTrip,
        'notes': _notesController.text,
      };

      final success = await ref.read(tripProvider.notifier).createTrip(payload);
      if (success) {
        if (!mounted) return;
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 Berhasil membuka Trip baru!'),
            backgroundColor: AppColors.secondary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        if (!mounted) return;
        final error = ref.read(tripProvider).error;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal membuka trip: ${error ?? "Terjadi kesalahan"}'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tripState = ref.watch(tripProvider);

    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Pull Bar
              Center(
                child: Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              // Title
              const Text(
                'Buka Trip Baru',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textMain,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Deklarasikan rute perjalanan Anda untuk mencocokkan pesanan searah.',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
              const SizedBox(height: 24),

              // Origin Location Card
              _buildLocationCard(
                label: 'Titik Keberangkatan (Origin)',
                address: _originAddress ?? 'Pilih titik asal...',
                icon: Icons.location_on_rounded,
                color: Colors.green,
                onTap: () async {
                  final result = await showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => LocationPickerSheet(
                      title: 'Pilih Titik Keberangkatan',
                      initialLocation: _originLocation ?? ref.read(userLocationProvider),
                      primaryColor: AppColors.secondary,
                    ),
                  );
                  if (result != null && mounted) {
                    setState(() {
                      _originLocation = result['location'];
                      _originAddress = result['address'];
                    });
                  }
                },
              ),
              const SizedBox(height: 16),

              // Destination Location Card
              _buildLocationCard(
                label: 'Titik Tujuan (Destination)',
                address: _destinationAddress ?? 'Pilih titik tujuan...',
                icon: Icons.flag_rounded,
                color: Colors.red,
                onTap: () async {
                  final result = await showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => LocationPickerSheet(
                      title: 'Pilih Titik Tujuan',
                      initialLocation: _destinationLocation ?? ref.read(userLocationProvider),
                      primaryColor: AppColors.secondary,
                    ),
                  );
                  if (result != null && mounted) {
                    setState(() {
                      _destinationLocation = result['location'];
                      _destinationAddress = result['address'];
                    });
                  }
                },
              ),
              const SizedBox(height: 16),

              // Departure Date & Time
              const Text(
                'Waktu Keberangkatan',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textMain),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _selectDateTime,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey[20] ?? Colors.grey.shade200),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        DateFormat('EEEE, d MMMM yyyy - HH:mm', 'id_ID').format(_departureDateTime),
                        style: const TextStyle(fontSize: 14, color: AppColors.textMain, fontWeight: FontWeight.w600),
                      ),
                      const Icon(Icons.calendar_today_rounded, color: AppColors.secondary, size: 20),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Vehicle Type Card selector
              const Text(
                'Jenis Kendaraan',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textMain),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _vehicleType = 'motorcycle'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: _vehicleType == 'motorcycle'
                              ? AppColors.secondary.withValues(alpha: 0.08)
                              : Colors.grey[50],
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _vehicleType == 'motorcycle'
                                ? AppColors.secondary
                                : Colors.grey[20] ?? Colors.grey.shade200,
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.motorcycle_rounded,
                              color: _vehicleType == 'motorcycle' ? AppColors.secondary : AppColors.textMuted,
                              size: 28,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Motor',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: _vehicleType == 'motorcycle' ? AppColors.secondary : AppColors.textMain,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _vehicleType = 'car'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: _vehicleType == 'car'
                              ? AppColors.secondary.withValues(alpha: 0.08)
                              : Colors.grey[50],
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _vehicleType == 'car'
                                ? AppColors.secondary
                                : Colors.grey[20] ?? Colors.grey.shade200,
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.directions_car_rounded,
                              color: _vehicleType == 'car' ? AppColors.secondary : AppColors.textMuted,
                              size: 28,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Mobil',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: _vehicleType == 'car' ? AppColors.secondary : AppColors.textMain,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Capacity fields (Weight & Volume)
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Berat Maksimal (Kg)',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textMain),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _weightController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            hintText: '15.0',
                            filled: true,
                            fillColor: Colors.grey[50],
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: Colors.grey[20] ?? Colors.grey.shade200),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: Colors.grey[20] ?? Colors.grey.shade200),
                            ),
                          ),
                          validator: (val) {
                            if (val == null || val.isEmpty) return 'Isi berat';
                            if (double.tryParse(val) == null) return 'Angka saja';
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Volume Maksimal (Liter)',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textMain),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _volumeController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            hintText: '10.0',
                            filled: true,
                            fillColor: Colors.grey[50],
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: Colors.grey[20] ?? Colors.grey.shade200),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: Colors.grey[20] ?? Colors.grey.shade200),
                            ),
                          ),
                          validator: (val) {
                            if (val == null || val.isEmpty) return 'Isi volume';
                            if (double.tryParse(val) == null) return 'Angka saja';
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Round Trip Toggle
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey[20] ?? Colors.grey.shade200),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Perjalanan Pulang-Pergi',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textMain),
                        ),
                        Text(
                          'Mengaktifkan pencocokan dua arah',
                          style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                    Switch.adaptive(
                      value: _isRoundTrip,
                      activeThumbColor: AppColors.secondary,
                      onChanged: (val) => setState(() => _isRoundTrip = val),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Keterangan / Notes (Optional)
              const Text(
                'Keterangan Perjalanan (Opsional)',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textMain),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _notesController,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'Contoh: Lewat tol, bisa singgah beli makan...',
                  hintStyle: const TextStyle(fontSize: 13),
                  filled: true,
                  fillColor: Colors.grey[50],
                  contentPadding: const EdgeInsets.all(16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.grey[20] ?? Colors.grey.shade200),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.grey[20] ?? Colors.grey.shade200),
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // Submit Button
              ElevatedButton(
                onPressed: tripState.isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                ),
                child: tripState.isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text(
                        'Buka Trip Sekarang',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 0.2),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocationCard({
    required String label,
    required String address,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[200] ?? Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    address,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textMain,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}
