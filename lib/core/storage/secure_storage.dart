import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The single Android/iOS secure-storage configuration used by auth and all
/// feature API clients. Every repository must read session tokens from the
/// same encrypted preferences namespace.
const appSecureStorage = FlutterSecureStorage(
  aOptions: AndroidOptions(encryptedSharedPreferences: true),
  iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
);
