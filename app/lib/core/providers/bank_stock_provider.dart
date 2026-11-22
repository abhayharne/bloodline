import 'package:flutter/foundation.dart';
import '../models/blood_stock.dart';
import '../api_client.dart';

const List<String> kAllBloodGroups = [
  'O+',
  'O-',
  'A+',
  'A-',
  'B+',
  'B-',
  'AB+',
  'AB-',
];

class BankStockProvider extends ChangeNotifier {
  final ApiClient apiClient;
  List<BloodStockItem> _stock = [];
  bool _isLoading = false;
  bool _isSaving = false;
  String? _error;

  List<BloodStockItem> get stock => _stock;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get error => _error;

  BankStockProvider({required this.apiClient});

  Future<void> loadStock() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final fetched = await apiClient.getStock();
      _stock = _wholeBloodStock(fetched);

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
    }
  }

  void updateUnits(String bloodGroup, int delta) {
    final idx = _stock.indexWhere((s) => s.bloodGroup == bloodGroup);
    if (idx != -1) {
      final newUnits = (_stock[idx].units + delta).clamp(0, 9999);
      _stock[idx] = _stock[idx].copyWith(units: newUnits);
      notifyListeners();
    }
  }

  void setUnits(String bloodGroup, int units) {
    final idx = _stock.indexWhere((s) => s.bloodGroup == bloodGroup);
    if (idx != -1) {
      _stock[idx] = _stock[idx].copyWith(units: units.clamp(0, 9999));
      notifyListeners();
    }
  }

  Future<bool> saveStock() async {
    _isSaving = true;
    _error = null;
    notifyListeners();

    try {
      _stock = _wholeBloodStock(await apiClient.updateStock(_stock));
      _isSaving = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isSaving = false;
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  List<BloodStockItem> _wholeBloodStock(List<BloodStockItem> stock) {
    final byGroup = {
      for (final item in stock)
        if (item.component == 'whole_blood') item.bloodGroup: item,
    };
    return [
      for (final group in kAllBloodGroups)
        byGroup[group] ?? BloodStockItem(bloodGroup: group, units: 0),
    ];
  }
}
