import 'package:phone_shop_pos/core/database/base_repository.dart';
import 'package:phone_shop_pos/core/errors/result.dart';
import 'package:phone_shop_pos/modules/customers/domain/entities/customer_entity.dart';

abstract class CustomerRepository extends BaseRepository {
  Future<Result<CustomerEntity>> createCustomer(CustomerEntity customer);

  Future<Result<CustomerEntity?>> getCustomerById(String id);

  Future<Result<List<CustomerEntity>>> searchCustomers(
    String query, {
    bool? isActive,
    int limit = 100,
  });

  Future<Result<void>> updateCustomer(CustomerEntity customer);

  Future<Result<void>> setActive(String id, {required bool active});

  Future<Result<double>> getOutstandingBalance(String customerId);

  /// Permanently deletes a customer. Fails with a descriptive message if any
  /// sales/invoice record still references it — archive instead in that
  /// case. Never leaves orphan references.
  Future<Result<void>> deleteCustomer(String id);
}
