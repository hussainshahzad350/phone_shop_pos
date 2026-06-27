import 'dart:typed_data';

import 'package:phone_shop_pos/core/errors/result.dart';

/// A stored backup object as listed from cloud storage.
class CloudStorageObject {
  const CloudStorageObject({
    required this.name,
    required this.sizeBytes,
    this.createdAt,
  });

  final String name;
  final int sizeBytes;
  final DateTime? createdAt;
}

/// Transport-agnostic object storage for backups. Implemented over Supabase
/// Storage's REST API in production and faked in tests.
abstract class CloudStorageClient {
  Future<Result<void>> upload({
    required String path,
    required Uint8List bytes,
    required String accessToken,
    String contentType = 'application/octet-stream',
  });

  Future<Result<List<CloudStorageObject>>> list({
    required String prefix,
    required String accessToken,
  });

  Future<Result<Uint8List>> download({
    required String path,
    required String accessToken,
  });

  Future<Result<void>> delete({
    required String path,
    required String accessToken,
  });
}
