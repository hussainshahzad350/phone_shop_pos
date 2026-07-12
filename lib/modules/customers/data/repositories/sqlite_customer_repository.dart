import 'package:phone_shop_pos/core/database/app_database.dart';
import 'package:phone_shop_pos/core/database/base_repository.dart';
import 'package:phone_shop_pos/core/database/query_diagnostics.dart';
import 'package:phone_shop_pos/core/database/table_names.dart';
import 'package:phone_shop_pos/core/errors/result.dart';
import 'package:phone_shop_pos/core/services/audit_logger.dart';
import 'package:phone_shop_pos/core/utils/date_time_helpers.dart';
import 'package:phone_shop_pos/core/utils/id_helpers.dart';
import 'package:phone_shop_pos/modules/customers/data/models/customer_model.dart';
import 'package:phone_shop_pos/modules/customers/domain/entities/customer_entity.dart';
import 'package:phone_shop_pos/modules/customers/domain/repositories/customer_repository.dart';

class SqliteCustomerRepository
    with BaseRepositoryGuard
    implements CustomerRepository {
  SqliteCustomerRepository({required AppDatabase appDatabase})
      : _appDatabase = appDatabase;

  final AppDatabase _appDatabase;

  @override
  Future<Result<CustomerEntity>> createCustomer(CustomerEntity customer) {
    return guard<CustomerEntity>(() async {
      final now = DateTimeHelpers.nowUtc();
      final model = CustomerModel(
        id: customer.id.isNotEmpty
            ? customer.id
            : IdHelpers.newId(prefix: 'cus'),
        name: customer.name,
        phone: customer.phone,
        email: customer.email,
        address: customer.address,
        notes: customer.notes,
        isActive: customer.isActive,
        createdAt: now,
        updatedAt: now,
      );
      await _appDatabase.insert(TableNames.customers, model.toMap());
      return model.toEntity();
    }, operation: 'create_customer');
  }

  @override
  Future<Result<CustomerEntity?>> getCustomerById(String id) {
    return guard<CustomerEntity?>(() async {
      final rows = await _appDatabase.queryTable(
        TableNames.customers,
        where: 'id = ?',
        whereArgs: <Object?>[id],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return CustomerModel.fromMap(rows.first).toEntity();
    }, operation: 'get_customer_by_id');
  }

  @override
  Future<Result<List<CustomerEntity>>> searchCustomers(
    String query, {
    bool? isActive,
    int limit = 100,
  }) {
    return guard<List<CustomerEntity>>(() async {
      final trimmed = query.trim();
      final args = <Object?>[];
      final where = StringBuffer();
      if (isActive != null) {
        where.write('is_active = ?');
        args.add(isActive ? 1 : 0);
      }
      if (trimmed.isNotEmpty) {
        if (where.isNotEmpty) where.write(' AND ');
        where.write('(name LIKE ? OR phone LIKE ?)');
        final lq = '%$trimmed%';
        args
          ..add(lq)
          ..add(lq);
      }
      final rows = await QueryDiagnostics.trace(
        label: 'customers.search',
        action: () => _appDatabase.queryTable(
          TableNames.customers,
          where: where.isEmpty ? null : where.toString(),
          whereArgs: args.isEmpty ? null : args,
          orderBy: 'name COLLATE NOCASE ASC',
          limit: limit,
        ),
      );
      return rows
          .map(CustomerModel.fromMap)
          .map((m) => m.toEntity())
          .toList(growable: false);
    }, operation: 'search_customers');
  }

  @override
  Future<Result<void>> updateCustomer(CustomerEntity customer) {
    return guard<void>(() async {
      final now = DateTimeHelpers.nowUtc();
      await _appDatabase.update(
        TableNames.customers,
        <String, Object?>{
          'name': customer.name,
          'phone': customer.phone,
          'email': customer.email,
          'address': customer.address,
          'notes': customer.notes,
          'is_active': customer.isActive ? 1 : 0,
          'updated_at': DateTimeHelpers.toSql(now),
        },
        where: 'id = ?',
        whereArgs: <Object?>[customer.id],
      );
    }, operation: 'update_customer');
  }

  @override
  Future<Result<void>> setActive(String id, {required bool active}) {
    return guard<void>(() async {
      final now = DateTimeHelpers.nowUtc();
      await _appDatabase.update(
        TableNames.customers,
        <String, Object?>{
          'is_active': active ? 1 : 0,
          'updated_at': DateTimeHelpers.toSql(now)
        },
        where: 'id = ?',
        whereArgs: <Object?>[id],
      );
    }, operation: 'set_customer_active');
  }

  @override
  Future<Result<double>> getOutstandingBalance(String customerId) {
    return guard<double>(() async {
      final rows = await _appDatabase.database.rawQuery(
        'SELECT COALESCE(SUM(total - paid_amount), 0.0) AS balance FROM ${TableNames.sales} WHERE customer_id = ?',
        <Object?>[customerId],
      );
      return (rows.first['balance'] as num?)?.toDouble() ?? 0.0;
    }, operation: 'get_outstanding_balance');
  }

  @override
  Future<Result<void>> deleteCustomer(String id) {
    return guard<void>(() async {
      await _appDatabase.runInTransaction<void>((transaction) async {
        final salesRows = await transaction.rawQuery(
          'SELECT COUNT(*) AS cnt FROM ${TableNames.sales} WHERE customer_id = ?',
          <Object?>[id],
        );
        final salesCount = (salesRows.first['cnt'] as num?)?.toInt() ?? 0;
        final paymentRows = await transaction.rawQuery(
          'SELECT COUNT(*) AS cnt FROM ${TableNames.customerPaymentTransactions} WHERE customer_id = ?',
          <Object?>[id],
        );
        final paymentCount = (paymentRows.first['cnt'] as num?)?.toInt() ?? 0;
        final linked = salesCount + paymentCount;
        if (linked > 0) {
          throw StateError(
            'Cannot delete customer: $linked linked record(s) '
            '($salesCount sale(s)/invoice(s), $paymentCount payment '
            'transaction(s)). Archive it instead.',
          );
        }
        await transaction.delete(
          TableNames.customers,
          where: 'id = ?',
          whereArgs: <Object?>[id],
        );
        await AuditLogger.record(
          transaction,
          action: 'delete_customer',
          entityId: id,
          details: 'Hard-deleted customer with no linked records.',
        );
      });
    }, operation: 'delete_customer');
  }
}
