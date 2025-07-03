import 'package:invois/core/constants/tax_type.dart';
import 'package:invois/core/database/objectbox_response.dart';
import 'tax_local_source.dart';
import 'tax_model.dart';

class TaxFormRepository {
  final TaxLocalSource _localSource;

  // Singleton pattern
  static final TaxFormRepository _instance = TaxFormRepository._internal();
  factory TaxFormRepository() => _instance;

  TaxFormRepository._internal() : _localSource = TaxLocalSource();

  // Constructor for dependency injection (useful for testing)
  TaxFormRepository.withDependencies({required TaxLocalSource localService})
    : _localSource = localService;

  Future<List<Tax>> getTaxes() async {
    return await _localSource.getTaxes();
  }

  Future<Tax?> getTaxById(int id) async {
    return await _localSource.getTaxById(id);
  }

  Future<ObjectBoxResponse<Tax>> insertTax(Tax tax) async {
    // Set creation timestamp
    final taxWithTimestamp = tax.copyWith(
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    return await _localSource.insertTax(taxWithTimestamp);
  }

  Future<ObjectBoxResponse<Tax>> updateTax(Tax tax) async {
    // Set update timestamp
    final taxWithTimestamp = tax.copyWith(updatedAt: DateTime.now());
    return await _localSource.updateTax(taxWithTimestamp);
  }

  Future<bool> deleteTax(int id) async {
    return await _localSource.deleteTaxById(id);
  }

  Future<int> deleteTaxes(List<int> ids) async {
    int deletedCount = 0;
    for (int id in ids) {
      if (await deleteTax(id)) {
        deletedCount++;
      }
    }
    return deletedCount;
  }

  Future<List<Tax>> searchTaxesByName(String query) async {
    return await _localSource.searchTaxesByName(query);
  }

  Future<List<Tax>> getActiveTaxes() async {
    return await _localSource.getActiveTaxes();
  }

  Future<List<Tax>> getInactiveTaxes() async {
    return await _localSource.getInactiveTaxes();
  }

  Future<int> countTaxes() async {
    return await _localSource.countTaxes();
  }

  Future<bool> updateTaxFields(
    int id, {
    String? name,
    String? description,
    TaxType? taxType,
    double? rate,
    int? businessId,
    bool? isActive,
    bool? isDefault,
    DateTime? updatedAt,
  }) async {
    return await _localSource.updateTaxFields(
      id,
      name: name,
      description: description,
      taxType: taxType?.name,
      rate: rate,
      businessId: businessId,
      isActive: isActive,
      isDefault: isDefault,
      updatedAt: updatedAt,
    );
  }
}
