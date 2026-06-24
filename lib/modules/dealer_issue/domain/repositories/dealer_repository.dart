import 'package:phone_shop_pos/core/errors/result.dart';
import 'package:phone_shop_pos/modules/dealer_issue/domain/entities/dealer_entity.dart';

abstract class DealerRepository {
  Future<Result<List<DealerEntity>>> getAllDealers();
  Future<Result<DealerEntity>> createDealer(DealerEntity dealer);
  Future<Result<bool>> updateDealer(DealerEntity dealer);
  Future<Result<bool>> deleteDealer(String dealerId);
}
