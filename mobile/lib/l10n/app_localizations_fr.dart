import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'Vaxiil';

  @override
  String get languageTitle => 'Langue';

  @override
  String get languageSubtitle => 'Choisissez la langue de l\'application et des messages de l\'API.';

  @override
  String get languageEnglish => 'Anglais';

  @override
  String get languageFrench => 'Français';

  @override
  String get languageSaved => 'Langue mise à jour';

  @override
  String get loginOtpLede => 'Saisissez le code de vérification envoyé à votre e-mail.';

  @override
  String get loginOtpCode => 'Code de vérification';

  @override
  String get loginOtpRequired => 'Saisissez le code de vérification.';

  @override
  String get loginVerifyOtp => 'Vérifier et se connecter';

  @override
  String get loginOtpBack => 'Retour à la connexion';

  @override
  String get escrowBalanceTitle => 'Solde escrow';

  @override
  String get escrowBalanceHint => 'Crédit issu des annulations ou des recharges. Utilisez-le au paiement de votre prochaine réservation.';

  @override
  String get escrowTopUp => 'Ajouter des fonds';

  @override
  String get escrowTopUpAmount => 'Montant à ajouter';

  @override
  String get escrowTopUpSubmit => 'Continuer vers le paiement';

  @override
  String get escrowTopUpHint => 'Ajoutez des fonds en toute sécurité à votre solde escrow.';

  @override
  String get payUseEscrowTitle => 'Utiliser le crédit escrow ?';

  @override
  String payUseEscrowBody(String balance, String currency) {
    return 'Vous avez $balance $currency en escrow. L\'appliquer à ce paiement ?';
  }

  @override
  String get payEscrowApplied => 'Crédit escrow appliqué';

  @override
  String get payCardAmount => 'Montant à payer maintenant';

  @override
  String get payFullyPaidEscrow => 'Payé avec le crédit escrow.';

  @override
  String get payUseEscrowYes => 'Oui, utiliser le crédit';

  @override
  String get payUseEscrowNo => 'Non';

  @override
  String bookingCancelledEscrowCredit(String amount, String currency) {
    return 'Réservation annulée. $amount $currency crédité(s) sur l\'escrow.';
  }

  @override
  String get businessBookingVenue => 'Lieu';

  @override
  String get businessBookingSpecialRequests => 'Demandes spéciales';

  @override
  String get kycRequiredForBooking => 'Vérifiez votre identité avant de réserver.';
}
