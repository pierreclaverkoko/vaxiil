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
  String get turnstileRequired => 'Veuillez compléter la vérification de sécurité.';

  @override
  String get forgotPasswordTitle => 'Réinitialiser le mot de passe';

  @override
  String get forgotPasswordLede => 'Nous vous enverrons un code à usage unique pour définir un nouveau mot de passe.';

  @override
  String get forgotPasswordEmail => 'Adresse e-mail';

  @override
  String get forgotPasswordEmailRequired => 'Saisissez une adresse e-mail valide.';

  @override
  String get forgotPasswordSendCode => 'Envoyer le code';

  @override
  String get forgotPasswordReset => 'Réinitialiser le mot de passe';

  @override
  String get forgotPasswordNewPassword => 'Nouveau mot de passe';

  @override
  String get forgotPasswordPasswordShort => 'Au moins 8 caractères';

  @override
  String get forgotPasswordCodeSent => 'Si un compte existe pour cet e-mail, un code a été envoyé.';

  @override
  String get forgotPasswordDone => 'Mot de passe réinitialisé. Vous pouvez vous connecter.';

  @override
  String get forgotPasswordBackToLogin => 'Retour à la connexion';

  @override
  String get forgotPasswordMissingChallenge => 'Demandez d\'abord un nouveau code.';

  @override
  String get escrowBalanceTitle => 'Crédit magasin';

  @override
  String get escrowBalanceHint => 'Crédit issu des annulations ou des recharges. Utilisez-le au paiement de votre prochaine réservation.';

  @override
  String get escrowTopUp => 'Ajouter des fonds';

  @override
  String get escrowTopUpAmount => 'Montant à ajouter';

  @override
  String get escrowTopUpSubmit => 'Continuer vers le paiement';

  @override
  String get escrowTopUpHint => 'Ajoutez des fonds en toute sécurité à votre crédit magasin.';

  @override
  String get payUseEscrowTitle => 'Utiliser le crédit magasin ?';

  @override
  String payUseEscrowBody(String balance, String currency) {
    return 'Vous avez $balance $currency en crédit magasin. L\'appliquer à ce paiement ?';
  }

  @override
  String get payEscrowApplied => 'Crédit magasin appliqué';

  @override
  String get payCardAmount => 'Montant à payer maintenant';

  @override
  String get payFullyPaidEscrow => 'Payé avec le crédit magasin.';

  @override
  String get payUseEscrowYes => 'Oui, utiliser le crédit';

  @override
  String get payUseEscrowNo => 'Non';

  @override
  String bookingCancelledEscrowCredit(String amount, String currency) {
    return 'Réservation annulée. $amount $currency crédité(s) sur le crédit magasin.';
  }

  @override
  String get businessBookingVenue => 'Lieu';

  @override
  String get businessBookingSpecialRequests => 'Demandes spéciales';

  @override
  String get kycRequiredForBooking => 'Vérifiez votre identité avant de réserver.';

  @override
  String get bookingLocationTitle => 'Lieu';

  @override
  String get bookingLocationOffice => 'Sur place';

  @override
  String get bookingLocationHome => 'À mon domicile';

  @override
  String get bookingLocationVirtual => 'Virtuel / en ligne';

  @override
  String get bookingLocationMobile => 'Service mobile';

  @override
  String get businessBookingFeeBase => 'Prix du service';

  @override
  String get businessBookingFeePlatform => 'Frais de plateforme';

  @override
  String get businessBookingFeeTotal => 'Total';

  @override
  String get businessBookingNetCaptured => 'Net encaissé';

  @override
  String get bookingPaidBadge => 'Payé';

  @override
  String get bookingCannotAcceptUnpaid => 'Vous ne pouvez accepter qu’après le paiement du client.';

  @override
  String get bookingReschedulePendingClient => 'En attente de la réponse du client à votre proposition de report.';

  @override
  String get bookingReschedulePendingBusiness => 'L’entreprise a proposé un nouveau créneau. Acceptez ou refusez ci-dessous.';

  @override
  String get bookingReschedulePayFirst => 'Payez pour confirmer le nouvel horaire, ou refusez la proposition.';

  @override
  String get bookingRescheduleProposed => 'Reprogrammation proposée';

  @override
  String get profileSecurityTwoFactorTitle => 'Vérification e-mail à la connexion';

  @override
  String get profileSecurityTwoFactorBody => 'Un code à usage unique est envoyé à votre e-mail lorsque vous vous connectez avec un mot de passe.';

  @override
  String get profileSecurityTwoFactorDisableConfirm => 'Désactiver la vérification e-mail à la connexion ?';

  @override
  String get profileSecurityTwoFactorOn => 'La vérification e-mail est activée';

  @override
  String get profileSecurityTwoFactorOff => 'La vérification e-mail est désactivée';

  @override
  String get bookingAcceptReschedule => 'Accepter le report';

  @override
  String get bookingDeclineReschedule => 'Refuser le report';

  @override
  String get bookingRescheduleAccepted => 'Report accepté';

  @override
  String get bookingRescheduleDeclined => 'Report refusé';

  @override
  String get bookingAvailableTime => 'Horaires disponibles';

  @override
  String get bookingSlotsLoading => 'Chargement des créneaux…';

  @override
  String get bookingNoSlotsForDay => 'Aucun créneau disponible ce jour-là. Choisissez une autre date.';

  @override
  String get bookingReschedulePickTitle => 'Choisir un nouvel horaire';

  @override
  String get bookingRescheduleConfirmSlot => 'Proposer ce créneau';

  @override
  String get businessServiceAcceptedVenues => 'Lieux acceptés';

  @override
  String get businessServicePriceFromOptions => 'La fourchette de prix est définie par les options ci-dessous.';

  @override
  String get notificationsTitle => 'Notifications';

  @override
  String get notificationsSubtitle => 'Restez informé de votre parcours bien-être';

  @override
  String get notificationsMarkAllRead => 'Tout marquer comme lu';

  @override
  String get notificationsMarkRead => 'Marquer comme lu';

  @override
  String get notificationsViewDetails => 'Voir les détails';

  @override
  String get notificationsEmpty => 'Vous êtes à jour ! Aucune nouvelle notification.';

  @override
  String get notificationsEmptyCta => 'Explorer les services';

  @override
  String get notificationsLoadError => 'Impossible de charger les notifications';

  @override
  String get notificationsRetry => 'Réessayer';

  @override
  String get notificationsToday => 'Aujourd\'hui';

  @override
  String get notificationsYesterday => 'Hier';

  @override
  String get notificationsEarlier => 'Plus tôt';

  @override
  String get profileNotificationsInbox => 'Notifications';
}
