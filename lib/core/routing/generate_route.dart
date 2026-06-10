import 'package:flutter/material.dart';
import 'package:invois/core/constants/form_type.dart';
import 'package:invois/core/constants/list_type.dart';
import 'package:invois/features/business/business.dart';
import 'package:invois/features/client/client.dart';
import 'package:invois/features/invoice/presentation/pages/invoice_detail_page.dart';
import 'package:invois/features/invoice/presentation/pages/invoice_form_page.dart';
import 'package:invois/features/invoice/presentation/pages/invoice_preview_page.dart';
import 'package:invois/features/signature/signature.dart';

import 'package:invois/core/routing/no_route_page.dart';
import 'package:invois/features/home/presentation/pages/home_page.dart';
import 'package:invois/features/settings/presentation/pages/settings_page.dart';
import 'package:invois/features/splash/presentation/pages/splash_page.dart';
import 'package:invois/features/tax/tax.dart';
import 'package:invois/features/term/term.dart';
import '../../../core/utils/safe_parse.dart';
import 'routes_name.dart';

class _RouteArgsParser {
  final dynamic rawArgs;
  late final Map<String, dynamic> _mapArgs;

  _RouteArgsParser(this.rawArgs) : _mapArgs = SafeParse.map(rawArgs);

  String? getString(String key) => SafeParse.string(_mapArgs[key]);
  int? getInt(String key) => SafeParse.integer(_mapArgs[key]);
  double? getDouble(String key) => SafeParse.decimal(_mapArgs[key]);
  bool? getBool(String key) => SafeParse.boolean(_mapArgs[key]);
  Map<String, dynamic>? getMap(String key) => SafeParse.map(_mapArgs[key]);
  List<T>? getList<T>(String key, {T Function(dynamic)? itemParser}) {
    if (itemParser == null) {
      // For common types, provide default parsers
      if (T == int) {
        return SafeParse.list<T>(
          _mapArgs[key],
          (item) => SafeParse.integer(item) as T,
        );
      } else if (T == String) {
        return SafeParse.list<T>(
          _mapArgs[key],
          (item) => SafeParse.string(item) as T,
        );
      } else if (T == double) {
        return SafeParse.list<T>(
          _mapArgs[key],
          (item) => SafeParse.decimal(item) as T,
        );
      } else if (T == bool) {
        return SafeParse.list<T>(
          _mapArgs[key],
          (item) => SafeParse.boolean(item) as T,
        );
      }
      return [];
    }
    return SafeParse.list<T>(_mapArgs[key], itemParser);
  }
}

Route<dynamic> generateRoute(RouteSettings settings) {
  // ignore: unused_local_variable
  final argsParser = _RouteArgsParser(settings.arguments);
  final name = settings.name;

  // Simple static routes
  switch (name) {
    case RoutesName.splash:
      return MaterialPageRoute(
        builder: (_) => const SplashPage(),
        settings: const RouteSettings(name: RoutesName.splash),
      );

    case RoutesName.home:
      return MaterialPageRoute(
        builder: (_) => const HomePage(),
        settings: const RouteSettings(name: RoutesName.home),
      );

    case RoutesName.settings:
      return MaterialPageRoute(
        builder: (_) => const SettingsPage(),
        settings: const RouteSettings(name: RoutesName.settings),
      );

    // ============================================
    // MARK: - Business
    // ============================================

    case RoutesName.businessList:
      return MaterialPageRoute(
        builder: (_) => BusinessListPage(),
        settings: const RouteSettings(name: RoutesName.businessList),
      );

    case RoutesName.businessForm:
      final type = argsParser.getString('type');
      final businessId = argsParser.getInt('businessId');

      return MaterialPageRoute(
        builder: (_) => BusinessFormPage(
          type: (type != null && type.isNotEmpty)
              ? FormType.values.byName(type)
              : FormType.add,
          businessId: businessId,
        ),
        settings: const RouteSettings(name: RoutesName.businessForm),
      );

    // ============================================
    // MARK: - Signature
    // ============================================

    case RoutesName.signatureList:
      final type = argsParser.getString('type');

      return MaterialPageRoute(
        builder: (_) => SignatureListPage(
          listType: (type != null && type.isNotEmpty)
              ? ListType.values.byName(type)
              : ListType.list,
        ),
        settings: const RouteSettings(name: RoutesName.signatureList),
      );

    case RoutesName.signatureForm:
      final type = argsParser.getString('type');
      final signatureId = argsParser.getInt('signatureId');

      return MaterialPageRoute(
        builder: (_) => SignatureFormPage(
          type: (type != null && type.isNotEmpty)
              ? FormType.values.byName(type)
              : FormType.add,
          signatureId: signatureId,
        ),
        settings: const RouteSettings(name: RoutesName.signatureForm),
      );

    // ============================================
    // MARK: - Tax
    // ============================================

    case RoutesName.taxList:
      final type = argsParser.getString('type');

      return MaterialPageRoute(
        builder: (_) => TaxListPage(
          listType: (type != null && type.isNotEmpty)
              ? ListType.values.byName(type)
              : ListType.list,
        ),
        settings: const RouteSettings(name: RoutesName.taxList),
      );

    case RoutesName.taxForm:
      final type = argsParser.getString('type');
      final taxId = argsParser.getInt('taxId');

      return MaterialPageRoute(
        builder: (_) => TaxFormPage(
          type: (type != null && type.isNotEmpty)
              ? FormType.values.byName(type)
              : FormType.add,
          taxId: taxId,
        ),
        settings: const RouteSettings(name: RoutesName.taxForm),
      );

    // ============================================
    // MARK: - Term
    // ============================================

    case RoutesName.termList:
      final type = argsParser.getString('type');

      return MaterialPageRoute(
        builder: (_) => TermListPage(
          listType: (type != null && type.isNotEmpty)
              ? ListType.values.byName(type)
              : ListType.list,
        ),
        settings: const RouteSettings(name: RoutesName.termList),
      );

    case RoutesName.termForm:
      final type = argsParser.getString('type');
      final termId = argsParser.getInt('termId');

      return MaterialPageRoute(
        builder: (_) => TermFormPage(
          type: (type != null && type.isNotEmpty)
              ? FormType.values.byName(type)
              : FormType.add,
          termId: termId,
        ),
        settings: const RouteSettings(name: RoutesName.termForm),
      );

    // ============================================
    // MARK: - Client
    // ============================================

    case RoutesName.clientList:
      return MaterialPageRoute(
        builder: (_) => const ClientListPage(),
        settings: const RouteSettings(name: RoutesName.clientList),
      );

    case RoutesName.clientForm:
      final type = argsParser.getString('type');
      final clientId = argsParser.getInt('clientId');

      return MaterialPageRoute(
        builder: (_) => ClientFormPage(
          type: (type != null && type.isNotEmpty)
              ? FormType.values.byName(type)
              : FormType.add,
          clientId: clientId,
        ),
        settings: const RouteSettings(name: RoutesName.clientForm),
      );

    // ============================================
    // MARK: - Invoice
    // ============================================

    case RoutesName.invoiceForm:
      final type = argsParser.getString('type');
      final invoiceId = argsParser.getInt('invoiceId');

      return MaterialPageRoute(
        builder: (_) => InvoiceFormPage(
          type: (type != null && type.isNotEmpty)
              ? FormType.values.byName(type)
              : FormType.add,
          invoiceId: invoiceId,
        ),
        settings: const RouteSettings(name: RoutesName.invoiceForm),
      );

    case RoutesName.invoiceDetail:
      final invoiceId = argsParser.getInt('invoiceId');
      // A missing/invalid id falls through to the not-found page instead of
      // crashing on a null force-unwrap.
      if (invoiceId == null || invoiceId <= 0) {
        return MaterialPageRoute(
          builder: (_) => const NoRoutePage(),
          settings: settings,
        );
      }

      return MaterialPageRoute(
        builder: (_) => InvoiceDetailPage(invoiceId: invoiceId),
        settings: const RouteSettings(name: RoutesName.invoiceDetail),
      );

    case RoutesName.invoicePreview:
      final invoiceId = argsParser.getInt('invoiceId');
      if (invoiceId == null || invoiceId <= 0) {
        return MaterialPageRoute(
          builder: (_) => const NoRoutePage(),
          settings: settings,
        );
      }

      return MaterialPageRoute(
        builder: (_) => InvoicePreviewPage(invoiceId: invoiceId),
        settings: const RouteSettings(name: RoutesName.invoicePreview),
      );

    default:
      return MaterialPageRoute(
        builder: (_) => const NoRoutePage(),
        settings: settings,
      );
  }
}
