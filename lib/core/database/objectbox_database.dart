import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'objectbox.g.dart';

class ObjectBoxDatabase {
  static Store? _store;

  // SECURITY RISK (data-at-rest): The store below persists sensitive PII —
  // business/client details, addresses, invoices, tax data and signatures — to
  // the application documents directory WITHOUT encryption. On a rooted/
  // jailbroken device or via a device backup, this data is readable in plaintext.
  //
  // TODO(security): Encrypt the store at rest. ObjectBox data-at-rest encryption
  // is a commercial-edition feature that ships a different native library; the
  // bundled `objectbox_flutter_libs` (open-source) exposes no cipher-key option
  // on `Store`/`openStore`, so this cannot be enabled by code alone.
  // Implementation plan when the edition is available:
  //   1. Generate a 256-bit random key once per install, stored in the platform
  //      keychain/keystore via `flutter_secure_storage`.
  //   2. Pass the key to the store on open (encrypted-edition API).
  //   3. Provide a one-time migration for the existing unencrypted store
  //      (export -> wipe -> re-import); this is destructive and must be designed
  //      deliberately.
  // Tracked in doc/fix-lib-diagnosis-plan.md (§2 Encryption feasibility).

  /// Initialize the ObjectBox database. Must be called before using `instance`.
  static Future<void> init() async {
    if (_store != null) return;

    try {
      final dir = await getApplicationDocumentsDirectory();
      // ObjectBox will automatically create the store
      _store = await openStore(directory: dir.path);
      debugPrint('✅ ObjectBox initialized');
    } catch (e, st) {
      // Log the raw error/stack only in debug mode; never expose to users.
      debugPrint('❌ Failed to initialize ObjectBox');
      if (kDebugMode) {
        debugPrint('$e\n$st');
      }
      rethrow;
    }
  }

  /// Safe access to the current ObjectBox Store instance.
  static Store get instance {
    if (_store == null) {
      throw Exception(
        '❗ ObjectBoxDatabase not initialized. Call ObjectBoxDatabase.init() first.',
      );
    }
    return _store!;
  }

  /// Async getter for lazy initialization use (optional).
  static Future<Store> getInstance() async {
    if (_store != null) {
      return _store!;
    }
    await init();
    return _store!;
  }

  /// Closes the ObjectBox Store instance cleanly.
  static Future<void> close() async {
    if (_store != null) {
      _store!.close();
      debugPrint('✅ ObjectBox closed');
      _store = null;
    }
  }
}
