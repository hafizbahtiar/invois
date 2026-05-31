import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:objectbox/objectbox.dart';

import '../database/objectbox_database.dart';

/// App-wide ObjectBox [Store].
///
/// Repositories and local sources depend on this instead of reaching for the
/// `ObjectBoxDatabase` singleton directly, so tests can override it with an
/// in-memory store: `storeProvider.overrideWithValue(testStore)`.
final storeProvider = Provider<Store>((ref) => ObjectBoxDatabase.instance);
