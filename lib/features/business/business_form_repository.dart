import 'package:invois/core/database/objectbox_response.dart';
import 'package:invois/features/client/client_module.dart';
import 'package:invois/features/signature/signature_module.dart';
import 'package:invois/features/tax/tax_module.dart';
import 'package:invois/features/term/term_module.dart';

import 'business_local_source.dart';
import 'business_model.dart';

class BusinessFormRepository {
  final BusinessLocalSource _localSource;
  final ClientLocalSource _clientLocalSource;
  final TaxLocalSource _taxLocalSource;
  final TermLocalSource _termLocalSource;
  final SignatureLocalSource _signatureLocalSource;

  // Singleton pattern
  static final BusinessFormRepository _instance =
      BusinessFormRepository._internal();
  factory BusinessFormRepository() => _instance;

  BusinessFormRepository._internal()
    : _localSource = BusinessLocalSource(),
      _clientLocalSource = ClientLocalSource(),
      _taxLocalSource = TaxLocalSource(),
      _termLocalSource = TermLocalSource(),
      _signatureLocalSource = SignatureLocalSource();

  // Constructor for dependency injection (useful for testing)
  BusinessFormRepository.withDependencies({
    required BusinessLocalSource localService,
    required ClientLocalSource clientLocalSource,
    required TaxLocalSource taxLocalSource,
    required TermLocalSource termLocalSource,
    required SignatureLocalSource signatureLocalSource,
  }) : _localSource = localService,
       _clientLocalSource = clientLocalSource,
       _taxLocalSource = taxLocalSource,
       _termLocalSource = termLocalSource,
       _signatureLocalSource = signatureLocalSource;

  Future<List<Business>> getAllBusinesses() async {
    return await _localSource.getAllBusinesses();
  }

  Future<Business?> getBusinessById(int id) async {
    return await _localSource.getBusinessById(id);
  }

  Future<ObjectBoxResponse<Business>> insertBusiness(Business business) async {
    // Set creation timestamp
    final businessWithTimestamp = business.copyWith(
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    return await _localSource.insertBusiness(businessWithTimestamp);
  }

  Future<ObjectBoxResponse<Business>> updateBusiness(Business business) async {
    // Set update timestamp
    final businessWithTimestamp = business.copyWith(updatedAt: DateTime.now());
    return await _localSource.updateBusiness(businessWithTimestamp);
  }

  Future<ObjectBoxResponse<bool>> deleteBusiness(int id) async {
    // Delete related data first
    await _clientLocalSource.deleteClientByBusinessId(id);
    await _taxLocalSource.deleteTaxByBusinessId(id);
    await _termLocalSource.deleteTermByBusinessId(id);
    await _signatureLocalSource.deleteSignatureByBusinessId(id);

    // Now delete the business (addresses will be handled in local source)
    final result = await _localSource.deleteBusinessById(id);
    if (result) {
      return ObjectBoxResponse.success(true);
    } else {
      return ObjectBoxResponse.failure(message: 'Failed to delete business');
    }
  }

  Future<int> deleteBusinesses(List<int> ids) async {
    int deletedCount = 0;
    for (int id in ids) {
      final result = await deleteBusiness(id);
      if (result.success) {
        deletedCount++;
      }
    }
    return deletedCount;
  }

  Future<List<Business>> searchBusinessesByName(String query) async {
    return await _localSource.searchBusinessesByName(query);
  }

  Future<List<Business>> getActiveBusinesses() async {
    return await _localSource.getActiveBusinesses();
  }

  Future<List<Business>> getInactiveBusinesses() async {
    return await _localSource.getInactiveBusinesses();
  }

  Future<int> countBusinesses() async {
    return await _localSource.countBusinesses();
  }

  Future<bool> updateBusinessFields(
    int id, {
    String? name,
    String? description,
    String? logo,
    String? website,
    String? email,
    String? phone,
    String? taxNumber,
    String? registrationNumber,
    String? currencyCode,
    String? currencySymbol,
    bool? isActive,
    bool? isDefault,
    DateTime? updatedAt,
  }) async {
    return await _localSource.updateBusinessFields(
      id,
      name: name,
      website: website,
      email: email,
      phone: phone,
      isActive: isActive,
      isDefault: isDefault,
      updatedAt: updatedAt,
    );
  }
}
