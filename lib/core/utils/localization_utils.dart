// import 'package:flutter/material.dart';
// import '../../configs/l10n/generated/app_localizations.dart';

// /// Utility class for handling dynamic feature names in localization
// class LocalizationUtils {
//   /// Get localized feature name for signatures
//   static String getSignatureName(BuildContext context) {
//     final l10n = AppLocalizations.of(context)!;
//     return l10n.signatures;
//   }

//   /// Get localized feature name for businesses
//   static String getBusinessName(BuildContext context) {
//     final l10n = AppLocalizations.of(context)!;
//     return l10n.businesses;
//   }

//   /// Get localized feature name for clients
//   static String getClientName(BuildContext context) {
//     final l10n = AppLocalizations.of(context)!;
//     return l10n.clients;
//   }

//   /// Get localized feature name for taxes
//   static String getTaxName(BuildContext context) {
//     final l10n = AppLocalizations.of(context)!;
//     return l10n.taxes;
//   }

//   /// Get localized feature name for terms
//   static String getTermsName(BuildContext context) {
//     final l10n = AppLocalizations.of(context)!;
//     return l10n.terms;
//   }

//   /// Get localized search placeholder for a feature
//   static String getSearchPlaceholder(BuildContext context, String featureName) {
//     final l10n = AppLocalizations.of(context)!;
//     return l10n.searchFeature(featureName);
//   }

//   /// Get localized empty state message for a feature
//   static String getEmptyStateMessage(BuildContext context, String featureName) {
//     final l10n = AppLocalizations.of(context)!;
//     return l10n.noFeatureFound(featureName);
//   }

//   /// Get localized create first message for a feature
//   static String getCreateFirstMessage(
//     BuildContext context,
//     String featureName,
//   ) {
//     final l10n = AppLocalizations.of(context)!;
//     return l10n.createFirstFeature(featureName);
//   }

//   /// Get localized no matching message for a feature
//   static String getNoMatchingMessage(BuildContext context, String featureName) {
//     final l10n = AppLocalizations.of(context)!;
//     return l10n.noMatchingFeature(featureName);
//   }

//   /// Get localized success message for feature update
//   static String getUpdateSuccessMessage(
//     BuildContext context,
//     String featureName,
//   ) {
//     final l10n = AppLocalizations.of(context)!;
//     return l10n.featureUpdated(featureName);
//   }

//   /// Get localized success message for feature deletion
//   static String getDeleteSuccessMessage(
//     BuildContext context,
//     String featureName,
//   ) {
//     final l10n = AppLocalizations.of(context)!;
//     return l10n.featureDeleted(featureName);
//   }

//   /// Get localized success message for feature addition
//   static String getAddSuccessMessage(BuildContext context, String featureName) {
//     final l10n = AppLocalizations.of(context)!;
//     return l10n.featureAdded(featureName);
//   }

//   /// Get localized success message for marking feature as active
//   static String getFeatureMarkedActiveMessage(
//     BuildContext context,
//     String featureName,
//   ) {
//     final l10n = AppLocalizations.of(context)!;
//     return l10n.featureMarkedActive(featureName);
//   }

//   /// Get localized success message for marking feature as inactive
//   static String getFeatureMarkedInactiveMessage(
//     BuildContext context,
//     String featureName,
//   ) {
//     final l10n = AppLocalizations.of(context)!;
//     return l10n.featureMarkedInactive(featureName);
//   }

//   /// Get localized delete confirmation message for a feature
//   static String getDeleteConfirmationMessage(
//     BuildContext context,
//     String featureName,
//   ) {
//     final l10n = AppLocalizations.of(context)!;
//     return l10n.deleteFeatureConfirmation(featureName);
//   }

//   /// Get localized delete dialog title for a feature
//   static String getDeleteDialogTitle(BuildContext context, String featureName) {
//     final l10n = AppLocalizations.of(context)!;
//     return l10n.deleteFeature(featureName);
//   }

//   /// Get localized new form title for a feature
//   static String getNewFormTitle(BuildContext context, String featureName) {
//     final l10n = AppLocalizations.of(context)!;
//     return l10n.newFeature(featureName);
//   }

//   /// Get localized edit form title for a feature
//   static String getEditFormTitle(BuildContext context, String featureName) {
//     final l10n = AppLocalizations.of(context)!;
//     return l10n.editFeature(featureName);
//   }

//   /// Get localized add button text for a feature
//   static String getAddButtonText(BuildContext context, String featureName) {
//     final l10n = AppLocalizations.of(context)!;
//     return l10n.addFeature(featureName);
//   }

//   /// Get localized update button text for a feature
//   static String getUpdateButtonText(BuildContext context, String featureName) {
//     final l10n = AppLocalizations.of(context)!;
//     return l10n.updateFeature(featureName);
//   }

//   /// Get localized email field hint for a feature
//   static String getEmailFieldHint(BuildContext context, String featureName) {
//     final l10n = AppLocalizations.of(context)!;
//     return l10n.enterFeatureEmail(featureName);
//   }

//   /// Get localized website field hint for a feature
//   static String getWebsiteFieldHint(BuildContext context, String featureName) {
//     final l10n = AppLocalizations.of(context)!;
//     return l10n.enterFeatureWebsite(featureName);
//   }

//   /// Get localized phone field hint for a feature
//   static String getPhoneFieldHint(BuildContext context, String featureName) {
//     final l10n = AppLocalizations.of(context)!;
//     return l10n.enterFeaturePhone(featureName);
//   }

//   /// Get localized company field hint for a feature
//   static String getCompanyFieldHint(BuildContext context, String featureName) {
//     final l10n = AppLocalizations.of(context)!;
//     return l10n.enterFeatureCompany(featureName);
//   }

//   /// Get localized name field hint for a feature
//   static String getNameFieldHint(BuildContext context, String featureName) {
//     final l10n = AppLocalizations.of(context)!;
//     return l10n.enterFeatureName(featureName);
//   }

//   /// Get localized name validation message for a feature
//   static String getNameValidationMessage(
//     BuildContext context,
//     String featureName,
//   ) {
//     final l10n = AppLocalizations.of(context)!;
//     return l10n.pleaseEnterFeatureName(featureName);
//   }

//   /// Get localized message for marking a feature with a specific status
//   static String getFeatureMarkedStatusMessage(
//     BuildContext context,
//     String featureName,
//     String status,
//   ) {
//     final l10n = AppLocalizations.of(context)!;
//     return l10n.featureMarkedActiveStatus(featureName, status);
//   }

//   /// Get localized message for setting a feature as default
//   static String getDefaultFeatureSetMessage(
//     BuildContext context,
//     String featureName,
//   ) {
//     final l10n = AppLocalizations.of(context)!;
//     return l10n.defaultFeatureSet(featureName);
//   }

//   /// Example usage of dynamic patterns
//   /// This shows how to use the reusable translations with different features
//   static Map<String, String> getExampleUsage(BuildContext context) {
//     final signatureName = getSignatureName(context);
//     final businessName = getBusinessName(context);
//     final clientName = getClientName(context);

//     return {
//       'signature_search': getSearchPlaceholder(
//         context,
//         signatureName.toLowerCase(),
//       ),
//       'business_search': getSearchPlaceholder(
//         context,
//         businessName.toLowerCase(),
//       ),
//       'client_search': getSearchPlaceholder(context, clientName.toLowerCase()),
//       'signature_empty': getEmptyStateMessage(
//         context,
//         signatureName.toLowerCase(),
//       ),
//       'business_empty': getEmptyStateMessage(
//         context,
//         businessName.toLowerCase(),
//       ),
//       'signature_updated': getUpdateSuccessMessage(context, signatureName),
//       'business_updated': getUpdateSuccessMessage(context, businessName),
//       'new_signature_title': getNewFormTitle(context, signatureName),
//       'edit_business_title': getEditFormTitle(context, businessName),
//       'add_client_button': getAddButtonText(context, clientName),
//       'delete_signature_confirm': getDeleteConfirmationMessage(
//         context,
//         signatureName.toLowerCase(),
//       ),
//     };
//   }
// }
