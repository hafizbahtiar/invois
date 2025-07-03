import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

import 'objectbox.g.dart';

class ObjectBoxDatabase {
  static Store? _store;

  /// Initialize the ObjectBox database. Must be called before using `instance`.
  static Future<void> init() async {
    if (_store != null) return;

    try {
      final dir = await getApplicationDocumentsDirectory();
      // ObjectBox will automatically create the store
      _store = await openStore(directory: dir.path);
      debugPrint('✅ ObjectBox initialized at ${dir.path}');
    } catch (e, st) {
      debugPrint('❌ Failed to initialize ObjectBox: $e');
      debugPrint(st.toString());
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
