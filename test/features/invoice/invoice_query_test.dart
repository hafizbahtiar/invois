import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:invois/features/invoice/data/invoice_model.dart';
import 'package:invois/features/invoice/data/invoice_query.dart';

void main() {
  group('InvoiceQuery value semantics', () {
    test('equal queries are ==', () {
      expect(
        const InvoiceQuery(search: 'a', status: InvoiceStatus.paid),
        const InvoiceQuery(search: 'a', status: InvoiceStatus.paid),
      );
    });

    test('copyWith overrides only the given field', () {
      const q = InvoiceQuery(search: 'a', status: InvoiceStatus.draft);
      expect(q.copyWith(search: 'b'),
          const InvoiceQuery(search: 'b', status: InvoiceStatus.draft));
    });
  });

  group('InvoiceQueryNotifier', () {
    late ProviderContainer container;
    setUp(() => container = ProviderContainer());
    tearDown(() => container.dispose());

    InvoiceQuery read() => container.read(invoiceQueryProvider);
    InvoiceQueryNotifier notifier() =>
        container.read(invoiceQueryProvider.notifier);

    test('starts empty', () {
      expect(read(), const InvoiceQuery());
    });

    test('setSearch trims and nulls out blanks', () {
      notifier().setSearch('  hello  ');
      expect(read().search, 'hello');
      notifier().setSearch('   ');
      expect(read().search, isNull);
    });

    test('setStatus preserves the active search term', () {
      notifier().setSearch('inv-1');
      notifier().setStatus(InvoiceStatus.overdue);
      expect(read().search, 'inv-1');
      expect(read().status, InvoiceStatus.overdue);
    });

    test('reset clears everything', () {
      notifier().setSearch('x');
      notifier().setStatus(InvoiceStatus.sent);
      notifier().reset();
      expect(read(), const InvoiceQuery());
    });
  });
}
