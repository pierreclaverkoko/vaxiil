"""Bodies for LegalDocumentVersion seeds (en/fr).

`PRIVACY_2026_07_19_*` freeze the original privacy seed for migration 0007.
`PRIVACY_*` is the current privacy policy body.
"""

TERMS_SUMMARY_EN = (
    'Marketplace terms for VAXIIL users and businesses, including cancellations, '
    'store-credit refunds, and settlement holds.'
)
TERMS_SUMMARY_FR = (
    'Conditions du marketplace VAXIIL pour utilisateurs et entreprises, y compris '
    'annulations, crédits magasin et gels de règlement.'
)
PRIVACY_2026_07_19_SUMMARY_EN = (
    'How VAXIIL collects, uses, and protects personal data for users and businesses.'
)
PRIVACY_2026_07_19_SUMMARY_FR = (
    'Comment VAXIIL collecte, utilise et protège les données personnelles des utilisateurs et entreprises.'
)
PRIVACY_SUMMARY_EN = (
    'How VAXIIL collects, uses, and protects personal data for users and businesses, '
    'including Cloudflare Turnstile bot protection and Sumsub identity verification.'
)
PRIVACY_SUMMARY_FR = (
    'Comment VAXIIL collecte, utilise et protège les données personnelles des utilisateurs '
    'et entreprises, y compris Cloudflare Turnstile et la vérification d’identité Sumsub.'
)

TERMS_EN = """
# Terms of Service — VAXIIL

**Version:** 2026.08.05  
**Effective date:** 5 August 2026  
**Operator:** BAP IMAGINE SPRL (RC 0068614/25, NIF 4003075266), operating the VAXIIL platform.  
**Contact:** info@bapimagine.com

These Terms of Service (“Terms”) govern access to and use of the VAXIIL platform (website, applications, and related services). By creating an account or using VAXIIL, you agree to these Terms and to our Privacy Policy.

---

## 1. About VAXIIL

VAXIIL operates an online marketplace that connects people seeking wellness and related services (“Users” or “Clients”) with independent businesses and professionals (“Businesses”) listed on the platform.

**VAXIIL does not itself provide wellness, massage, therapy, beauty, rental, or other professional services.** Services are offered solely by Businesses that have been accepted on the platform. VAXIIL is not a party to the service contract between a User and a Business, except as described in these Terms regarding payments, platform fees, and account rules.

---

## 2. Terms for Users (Clients)

### 2.1 Eligibility and account
You must provide accurate registration information and keep it up to date. You are responsible for safeguarding your credentials and for activity under your account.

### 2.2 Bookings and payments
When you book a service, you enter into a commercial relationship with the Business for that service. Prices shown are based on the Business’s catalogue (base price). Depending on the Business’s fee configuration set by VAXIIL:

- If the **client pays** the platform fee, the amount you pay may include the base price **plus** VAXIIL’s platform fee (gain rate).
- If the **business pays** the platform fee, you pay the **base price** shown; the Business receives less after the platform fee.

Payments may be processed through third-party payment providers. Cancellation credits follow section 2.2b and are issued as **VAXIIL store credit** (refund wallet), not as a card or mobile-money chargeback, unless VAXIIL decides otherwise.

### 2.2a Identity verification fee
To help cover identity-verification costs (including Sumsub KYC) and keep the marketplace secure with real verified people, VAXIIL charges a **one-time verification fee** of **USD 5** (or the equivalent in the booking currency using VAXIIL’s published FX rates). The fee is collected on your **first successful booking payment**, is shown clearly at checkout, and is not charged again once paid. You must complete identity verification before booking.

### 2.2b Cancellations and store credit (Clients)
If a paid booking is cancelled, VAXIIL credits your **store credit (refund wallet)** with the eligible amount. Credits are funded from the Business’s revenue balance on the platform. **Platform fees already charged are not reversed** as a separate cash refund.

- If the **Business** cancels (or rejects / declines a reschedule in a way that ends the booking), you receive store credit for **100%** of the amount you paid for that booking (including the platform fee when you paid it).
- If **you** cancel **24 hours or more** before the earliest scheduled start time, you receive store credit for **100%** of the amount you paid.
- If **you** cancel **less than 24 hours** before the earliest scheduled start time, you receive store credit for **50%** of the amount you paid. Of the retained **50%**: **80%** remains with the Business and **20%** is retained by VAXIIL as a late-cancellation platform share. The app warns you before you confirm a late cancellation.

Store credit can be applied to future bookings on VAXIIL where the product allows.

### 2.3 Conduct
You agree not to misuse the platform, harass others, circumvent payments, or post unlawful or harmful content. VAXIIL may suspend accounts that violate these Terms.

### 2.4 Service quality
The quality, safety, and professionalism of services are the **responsibility of each Business**. VAXIIL performs business verification (KYB) to help ensure listed Businesses are legitimate professionals, but VAXIIL does not guarantee the outcome of any appointment.

### 2.5 Privacy
VAXIIL is committed to protecting your privacy as described in our Privacy Policy (Trust Alias, visibility controls, and related features).

---

## 3. Terms for Businesses

### 3.1 Listing and verification
To offer services, you must create or join an organization, submit verification documents when requested, and maintain accurate profile, pricing, and availability information. VAXIIL may approve, reject, suspend, or remove listings.

### 3.2 Your responsibility for services
You alone are responsible for the services you provide, applicable licenses, hygiene and safety standards, staffing, and compliance with applicable law. VAXIIL’s verification process does not transfer that responsibility to VAXIIL.

### 3.3 Platform fees (gain rate)
VAXIIL charges a platform fee on bookings. The **default** rate is **1%** of the base price, but rates are **configurable** by VAXIIL and may vary:

- **by service category**; and/or  
- **by company (organization)**.

When VAXIIL applies or changes a **company-specific** fee arrangement, **VAXIIL will contact the company**. You can view applicable fee information in your business account settings; **Businesses cannot set platform fee rates themselves**—fees are managed by VAXIIL staff.

VAXIIL may also configure, per company, whether the **client** or the **business** pays the platform fee (default: client). If the business pays, the client sees and pays the catalogue base price, and the amount attributable to the Business is reduced by the fee. If the client pays, the client is charged base price plus fee.

**Platform fees accrued on a paid booking are not reversed when the booking is cancelled.**

### 3.3a Cancellations funded from your revenue (Businesses)
When a paid booking is cancelled, client store credit is funded by debiting your organization revenue wallet (which may go negative):

- **Business-initiated** cancel (and reject / full-return reschedule decline): the client receives **100%** of what they paid as store credit; your revenue is debited for that full amount.
- **Client cancel ≥ 24 hours** before start: same **100%** client store credit and revenue debit.
- **Client cancel &lt; 24 hours** before start: the client receives **50%** as store credit; of the retained **50%**, **80%** stays with you and **20%** is taken by VAXIIL (additional revenue debit). Accrued platform fees are not reversed.

### 3.4 Annual subscription, payouts, and records
VAXIIL charges Businesses an **annual subscription** of **USD 15** (or the local-currency equivalent via published FX rates). It is collected from the organization’s revenue balance on the **first successful booking payment** for that organization in each annual period (and renews on the next successful payment after the paid-through date). If the net credit from that payment is less than the subscription amount, the organization’s revenue balance may temporarily go **negative** solely for this subscription debit; cancellation debits may also leave the balance negative.

Businesses may configure settlement destinations (bank/IBAN, accepted mobile-money numbers, or Interac email), periodicity, and a minimum payout amount (at least the USD 10 equivalent). Manual settlement requests of at least that minimum are reviewed by VAXIIL staff. Until a payout rail is integrated for a method, settlements are processed manually after staff confirmation. You must keep your own tax and accounting records.

**Settlement hold:** revenue attributed to bookings that are **not yet completed** is **not available for settlement**. Only amounts linked to **completed** bookings (and other non-held ledger items) may be withdrawn. Funds on confirmed or in-progress bookings remain held because those bookings can still be cancelled or claimed.

### 3.5 Team and data
You must ensure that staff you invite respect privacy rules and use client data only for fulfilling bookings and lawful business needs.

---

## 4. Platform rules (all parties)

### 4.1 Intellectual property
VAXIIL branding, software, and content remain VAXIIL’s property. You retain rights to content you upload, and grant VAXIIL a license to host and display it for platform operation.

### 4.2 Prohibited use
No fraud, money laundering, infringement, scraping that harms the service, or attempts to bypass fees or security.

### 4.3 Suspension
VAXIIL may suspend or terminate access for breach, legal risk, or to protect Users and Businesses.

### 4.4 Limitation of liability
To the fullest extent permitted by applicable law, VAXIIL is not liable for the acts or omissions of Businesses or Users, service outcomes, or indirect damages. VAXIIL’s aggregate liability related to the platform is limited to fees paid to VAXIIL in the three months preceding the claim, except where liability cannot be limited by law.

### 4.5 Indemnity
You agree to indemnify VAXIIL against claims arising from your misuse of the platform or your breach of these Terms (including Businesses’ service delivery).

### 4.6 Changes
We may update these Terms by publishing a new version. Material changes require renewed acceptance before continued use.

### 4.7 Contact
For questions about these Terms or company-specific fees: contact VAXIIL support through the application or at info@bapimagine.com.

---

By accepting these Terms, Users and Businesses acknowledge the marketplace nature of VAXIIL, the fee rules above, and each Business’s responsibility for professional service delivery.
""".strip()

TERMS_FR = """
# Conditions d’utilisation — VAXIIL

**Version :** 2026.08.05  
**Date d’effet :** 5 août 2026  
**Exploitant :** BAP IMAGINE SPRL (RC 0068614/25, NIF 4003075266), exploitant la plateforme VAXIIL.  
**Contact :** info@bapimagine.com

Les présentes Conditions d’utilisation (« Conditions ») régissent l’accès et l’utilisation de la plateforme VAXIIL (site, applications et services associés). En créant un compte ou en utilisant VAXIIL, vous acceptez ces Conditions et notre Politique de confidentialité.

---

## 1. À propos de VAXIIL

VAXIIL exploite une place de marché en ligne mettant en relation des personnes cherchant des services de bien-être et services associés (« Utilisateurs » ou « Clients ») avec des entreprises et professionnels indépendants (« Entreprises ») référencés sur la plateforme.

**VAXIIL ne fournit pas elle-même de services de bien-être, massage, thérapie, beauté, location ou autres services professionnels.** Les services sont proposés uniquement par des Entreprises acceptées sur la plateforme. VAXIIL n’est pas partie au contrat de service entre un Utilisateur et une Entreprise, sauf pour ce qui concerne les paiements, les frais de plateforme et les règles de compte décrites ici.

---

## 2. Conditions pour les Utilisateurs (Clients)

### 2.1 Éligibilité et compte
Vous devez fournir des informations d’inscription exactes et les tenir à jour. Vous êtes responsable de la confidentialité de vos identifiants et de l’activité réalisée via votre compte.

### 2.2 Réservations et paiements
Lorsque vous réservez un service, vous entrez dans une relation commerciale avec l’Entreprise pour ce service. Les prix affichés sont basés sur le catalogue de l’Entreprise (prix de base). Selon la configuration des frais de l’Entreprise définie par VAXIIL :

- Si le **client paie** les frais de plateforme, le montant que vous payez peut inclure le prix de base **plus** les frais VAXIIL (taux de gain).
- Si l’**entreprise paie** les frais de plateforme, vous payez le **prix de base** affiché ; l’Entreprise reçoit un montant moindre après déduction des frais.

Les paiements peuvent être traités via des prestataires tiers. Les crédits d’annulation suivent la section 2.2b et sont émis en **crédit magasin VAXIIL** (portefeuille de remboursement), et non comme un remboursement carte ou mobile money, sauf décision contraire de VAXIIL.

### 2.2a Frais de vérification d’identité
Pour contribuer aux coûts de vérification d’identité (notamment Sumsub KYC) et maintenir une plateforme sécurisée avec des personnes réellement vérifiées, VAXIIL facture des **frais de vérification uniques** de **5 USD** (ou l’équivalent dans la devise de la réservation selon les taux de change publiés par VAXIIL). Ces frais sont prélevés lors de votre **premier paiement de réservation réussi**, sont indiqués clairement au paiement, et ne sont plus facturés une fois payés. Vous devez terminer la vérification d’identité avant de réserver.

### 2.2b Annulations et crédit magasin (Clients)
Si une réservation payée est annulée, VAXIIL crédite votre **crédit magasin (portefeuille de remboursement)** du montant éligible. Les crédits sont financés à partir du solde de revenus de l’Entreprise sur la plateforme. **Les frais de plateforme déjà prélevés ne sont pas annulés** sous forme de remboursement cash séparé.

- Si l’**Entreprise** annule (ou refuse / décline un report d’une manière qui met fin à la réservation), vous recevez un crédit magasin de **100 %** du montant payé pour cette réservation (y compris les frais de plateforme si vous les avez payés).
- Si **vous** annulez **24 heures ou plus** avant le début prévu le plus tôt, vous recevez un crédit magasin de **100 %** du montant payé.
- Si **vous** annulez **moins de 24 heures** avant le début prévu le plus tôt, vous recevez un crédit magasin de **50 %** du montant payé. Sur les **50 %** retenus : **80 %** restent à l’Entreprise et **20 %** sont retenus par VAXIIL (part plateforme pour annulation tardive). L’application vous avertit avant de confirmer une annulation tardive.

Le crédit magasin peut être utilisé pour de futures réservations VAXIIL lorsque le produit le permet.

### 2.3 Comportement
Vous vous engagez à ne pas abuser de la plateforme, harceler autrui, contourner les paiements ni publier de contenu illicite ou nuisible. VAXIIL peut suspendre les comptes en violation.

### 2.4 Qualité du service
La qualité, la sécurité et le professionnalisme des services relèvent de la **responsabilité de chaque Entreprise**. VAXIIL vérifie les entreprises (KYB) pour favoriser le référencement de professionnels légitimes, sans garantir le résultat d’un rendez-vous.

### 2.5 Confidentialité
VAXIIL s’engage à protéger votre vie privée conformément à la Politique de confidentialité (Trust Alias, contrôles de visibilité, etc.).

---

## 3. Conditions pour les Entreprises

### 3.1 Référencement et vérification
Pour proposer des services, vous devez créer ou rejoindre une organisation, transmettre les documents de vérification demandés, et maintenir des informations exactes (profil, tarifs, disponibilités). VAXIIL peut approuver, refuser, suspendre ou retirer des annonces.

### 3.2 Votre responsabilité
Vous êtes seul responsable des services fournis, des licences applicables, des normes d’hygiène et de sécurité, du personnel et du respect du droit applicable. La vérification VAXIIL ne transfère pas cette responsabilité à VAXIIL.

### 3.3 Frais de plateforme (taux de gain)
VAXIIL prélève des frais de plateforme sur les réservations. Le taux **par défaut** est de **1 %** du prix de base, mais les taux sont **configurables** par VAXIIL et peuvent varier :

- **par catégorie de service** ; et/ou  
- **par entreprise (organisation)**.

Lorsque VAXIIL applique ou modifie un arrangement de frais **spécifique à une entreprise**, **VAXIIL contactera l’entreprise**. Vous pouvez consulter les frais applicables dans les paramètres de votre compte professionnel ; **les Entreprises ne définissent pas elles-mêmes les taux de frais de plateforme**—ceux-ci sont gérés par le personnel VAXIIL.

VAXIIL peut aussi configurer, par entreprise, si le **client** ou l’**entreprise** paie les frais (par défaut : client). Si l’entreprise paie, le client voit et paie le prix de base du catalogue, et le montant attribué à l’Entreprise est réduit des frais. Si le client paie, le client est facturé prix de base plus frais.

**Les frais de plateforme déjà comptabilisés sur une réservation payée ne sont pas annulés lorsque la réservation est annulée.**

### 3.3a Annulations financées sur vos revenus (Entreprises)
Lorsqu’une réservation payée est annulée, le crédit magasin client est financé par un débit sur le portefeuille de revenus de votre organisation (qui peut devenir négatif) :

- **Annulation initiée par l’Entreprise** (et refus / déclin de report avec remboursement intégral) : le client reçoit **100 %** de ce qu’il a payé en crédit magasin ; vos revenus sont débités de ce montant.
- **Annulation client ≥ 24 heures** avant le début : même crédit magasin **100 %** et débit revenus.
- **Annulation client &lt; 24 heures** avant le début : le client reçoit **50 %** en crédit magasin ; sur les **50 %** retenus, **80 %** restent chez vous et **20 %** sont prélevés par VAXIIL (débit revenus supplémentaire). Les frais de plateforme déjà comptabilisés ne sont pas annulés.

### 3.4 Abonnement annuel, règlements et registres
VAXIIL facture aux Entreprises un **abonnement annuel** de **15 USD** (ou l’équivalent en devise locale via les taux de change publiés). Il est prélevé sur le solde de revenus de l’organisation lors du **premier paiement de réservation réussi** pour cette organisation dans chaque période annuelle (et se renouvelle au prochain paiement réussi après la date de couverture). Si le crédit net de ce paiement est inférieur au montant de l’abonnement, le solde de revenus peut temporairement devenir **négatif** pour ce débit d’abonnement ; les débits d’annulation peuvent aussi laisser le solde négatif.

Les Entreprises peuvent configurer des destinations de règlement (banque/IBAN, numéros mobile money acceptés, ou e-mail Interac), la périodicité et un montant minimum (au moins l’équivalent de 10 USD). Les demandes de règlement manuel d’au moins ce minimum sont examinées par le personnel VAXIIL. Tant qu’un rail de paiement n’est pas intégré pour une méthode, les règlements sont traités manuellement après confirmation du personnel. Vous devez conserver vos propres registres fiscaux.

**Gel de règlement :** les revenus liés à des réservations **non encore terminées** ne sont **pas disponibles pour règlement**. Seuls les montants liés à des réservations **terminées** (et autres écritures non gelées) peuvent être retirés. Les fonds des réservations confirmées ou en cours restent gelés car elles peuvent encore être annulées ou réclamées.

### 3.5 Équipe et données
Vous devez veiller à ce que le personnel invité respecte les règles de confidentialité et n’utilise les données clients que pour l’exécution des réservations et des besoins légitimes.

---

## 4. Règles de la plateforme (toutes les parties)

### 4.1 Propriété intellectuelle
La marque, les logiciels et contenus VAXIIL restent la propriété de VAXIIL. Vous conservez vos droits sur les contenus que vous téléversez et accordez à VAXIIL une licence pour les héberger et les afficher aux fins de la plateforme.

### 4.2 Usages interdits
Fraude, blanchiment, contrefaçon, extraction abusive nuisant au service, ou contournement des frais ou de la sécurité sont interdits.

### 4.3 Suspension
VAXIIL peut suspendre ou résilier l’accès en cas de manquement, de risque juridique ou pour protéger Utilisateurs et Entreprises.

### 4.4 Limitation de responsabilité
Dans la mesure permise par le droit applicable, VAXIIL n’est pas responsable des actes ou omissions des Entreprises ou Utilisateurs, des résultats des services, ni des dommages indirects. La responsabilité globale de VAXIIL liée à la plateforme est limitée aux frais payés à VAXIIL au cours des trois mois précédant la réclamation, sauf lorsque la loi interdit une telle limitation.

### 4.5 Indemnisation
Vous acceptez d’indemniser VAXIIL contre les réclamations résultant de votre mauvaise utilisation de la plateforme ou de la violation des présentes Conditions (y compris la prestation de services par les Entreprises).

### 4.6 Modifications
Nous pouvons mettre à jour ces Conditions en publiant une nouvelle version. Les changements importants exigent une nouvelle acceptation avant poursuite de l’utilisation.

### 4.7 Contact
Pour toute question sur ces Conditions ou les frais spécifiques à une entreprise : contactez le support VAXIIL via l’application ou à info@bapimagine.com.

---

En acceptant ces Conditions, Utilisateurs et Entreprises reconnaissent la nature marketplace de VAXIIL, les règles de frais ci-dessus, et la responsabilité de chaque Entreprise quant à la prestation professionnelle des services.
""".strip()

PRIVACY_2026_07_19_EN = """
# Privacy Policy — VAXIIL

**Version:** 2026.07.19  
**Effective date:** 19 July 2026  
**Controller:** VAXIIL, based in the Democratic Republic of the Congo (DRC).

VAXIIL is committed to protecting your privacy. This Policy explains how we collect, use, share, and safeguard personal data when you use our marketplace platform as a User (Client) or as a Business representative.

---

## 1. Our role

VAXIIL operates a marketplace. We process account, booking, payment-related, and verification data to run the platform. **Businesses** that you book with may receive the personal data necessary to fulfill the appointment (subject to your visibility and share-consent choices). VAXIIL does not provide the underlying wellness services.

---

## 2. Data we collect

### For Users
- Account data: email, name, phone (optional), credentials, Trust Alias  
- Profile preferences: visibility toggles (real name, phone, email), date of birth / sex if provided  
- Booking data: services, times, special requests, share consents for a booking  
- Payment data: amounts, currency, transaction status, wallet credits (payment card details are handled by payment providers)  
- Device/technical data: app/browser type, approximate logs for security  
- KYC documents if you choose identity verification  

### For Businesses
- Organization profile, contacts, addresses, catalogue, team memberships  
- KYB documents and verification status  
- Booking and analytics aggregates related to your organization  
- Fee configuration visibility (rates managed by VAXIIL staff)

---

## 3. Purposes

We use data to: create and secure accounts; enable discovery and booking; process payments and refunds/wallet credits; apply platform fees; verify Users/Businesses; provide support; improve safety and prevent fraud; comply with law; and communicate service messages.

---

## 4. Privacy features we guarantee as a platform

- **Trust Alias** and related privacy controls so you can limit exposure of legal identity  
- Booking-level share consents where a Business requires certain fields  
- Role-based access so Business staff see client details only as needed for operations  
- Security measures appropriate to our size and risk (access controls, encrypted transport)

VAXIIL’s privacy commitment covers **how the platform handles data**. Each Business remains responsible for how they handle client data after receiving it for a booking.

---

## 5. Sharing

We share data with:
- The **Business** involved in your booking (as needed to deliver the service)  
- **Payment providers** (e.g. to create payment links and confirm status)  
- **Infrastructure** processors hosting our systems  
- Authorities when legally required  

We do not sell personal data.

---

## 6. Retention

We retain account and booking records for as long as needed to provide the service, resolve disputes, meet legal/accounting obligations, then delete or anonymize where practicable. Verification documents are retained for the verification lifecycle and applicable legal periods.

---

## 7. Your rights

Subject to DRC law and applicable regulations, you may request access, correction, deletion, or restriction of your personal data, and object to certain processing. Contact VAXIIL support via the app. You may also withdraw visibility consents in settings (which may affect ability to book with some Businesses).

---

## 8. International transfers

If processors or tools are located outside the DRC, we take reasonable steps to protect data in line with this Policy and applicable requirements.

---

## 9. Children

VAXIIL is not directed at children. Do not create an account if you are not legally able to contract in your jurisdiction.

---

## 10. Changes

We may publish a new Privacy Policy version. Material changes require renewed acceptance before continued use of the platform.

---

## 11. Contact

Privacy requests and questions: VAXIIL support through the application or contact channels on the VAXIIL website.
""".strip()

PRIVACY_2026_07_19_FR = """
# Politique de confidentialité — VAXIIL

**Version :** 2026.07.19  
**Date d’effet :** 19 juillet 2026  
**Responsable de traitement :** VAXIIL, établie en République démocratique du Congo (RDC).

VAXIIL s’engage à protéger votre vie privée. La présente Politique explique comment nous collectons, utilisons, partageons et protégeons les données personnelles lorsque vous utilisez notre place de marché en tant qu’Utilisateur (Client) ou représentant d’une Entreprise.

---

## 1. Notre rôle

VAXIIL exploite une place de marché. Nous traitons des données de compte, de réservation, liées aux paiements et à la vérification pour faire fonctionner la plateforme. Les **Entreprises** avec lesquelles vous réservez peuvent recevoir les données nécessaires à l’exécution du rendez-vous (sous réserve de vos choix de visibilité et de consentement de partage). VAXIIL ne fournit pas les services de bien-être sous-jacents.

---

## 2. Données collectées

### Pour les Utilisateurs
- Données de compte : e-mail, nom, téléphone (optionnel), identifiants, Trust Alias  
- Préférences de profil : interrupteurs de visibilité (nom réel, téléphone, e-mail), date de naissance / sexe si fournis  
- Données de réservation : services, horaires, demandes spéciales, consentements de partage  
- Données de paiement : montants, devise, statut, crédits portefeuille (les données de carte sont traitées par les prestataires de paiement)  
- Données techniques : type d’appareil/navigateur, journaux de sécurité  
- Documents KYC si vous choisissez la vérification d’identité  

### Pour les Entreprises
- Profil d’organisation, contacts, adresses, catalogue, membres d’équipe  
- Documents KYB et statut de vérification  
- Agrégats de réservation et d’analytique  
- Visibilité de la configuration des frais (taux gérés par le personnel VAXIIL)

---

## 3. Finalités

Nous utilisons les données pour : créer et sécuriser les comptes ; permettre la découverte et la réservation ; traiter paiements et remboursements/crédits ; appliquer les frais de plateforme ; vérifier Utilisateurs/Entreprises ; fournir le support ; améliorer la sécurité et prévenir la fraude ; respecter la loi ; et envoyer des messages de service.

---

## 4. Engagements de confidentialité de la plateforme

- **Trust Alias** et contrôles associés pour limiter l’exposition de l’identité légale  
- Consentements de partage au niveau de la réservation lorsqu’une Entreprise l’exige  
- Accès basé sur les rôles pour que le personnel de l’Entreprise ne voie les détails clients que pour l’exploitation  
- Mesures de sécurité adaptées (contrôles d’accès, transport chiffré)

L’engagement de VAXIIL porte sur **le traitement des données par la plateforme**. Chaque Entreprise reste responsable du traitement des données clients après réception pour une réservation.

---

## 5. Partage

Nous partageons des données avec :
- l’**Entreprise** concernée par votre réservation (dans la mesure nécessaire) ;  
- les **prestataires de paiement** ;  
- les **prestataires d’infrastructure** hébergeant nos systèmes ;  
- les autorités lorsque la loi l’exige.  

Nous ne vendons pas les données personnelles.

---

## 6. Conservation

Nous conservons les comptes et réservations aussi longtemps que nécessaire pour le service, les litiges et les obligations légales/comptables, puis supprimons ou anonymisons lorsque c’est possible. Les documents de vérification sont conservés pour le cycle de vérification et les délais légaux applicables.

---

## 7. Vos droits

Sous réserve du droit congolais et des réglementations applicables, vous pouvez demander l’accès, la rectification, l’effacement ou la limitation, et vous opposer à certains traitements. Contactez le support VAXIIL via l’application. Vous pouvez aussi retirer des consentements de visibilité dans les paramètres (ce qui peut affecter la possibilité de réserver chez certaines Entreprises).

---

## 8. Transferts

Si des prestataires sont situés hors de la RDC, nous prenons des mesures raisonnables pour protéger les données conformément à la présente Politique.

---

## 9. Enfants

VAXIIL ne s’adresse pas aux enfants. Ne créez pas de compte si vous n’avez pas la capacité juridique de contracter.

---

## 10. Modifications

Nous pouvons publier une nouvelle version de la Politique. Les changements importants exigent une nouvelle acceptation avant poursuite de l’utilisation.

---

## 11. Contact

Demandes relatives à la confidentialité : support VAXIIL via l’application ou canaux publiés sur le site VAXIIL.
""".strip()

PRIVACY_EN = """
# Privacy Policy — VAXIIL

**Version:** 2026.08.04  
**Effective date:** 4 August 2026  
**Controller:** BAP IMAGINE SPRL (RC 0068614/25, NIF 4003075266), operating the VAXIIL platform.  
**Contact:** info@bapimagine.com

VAXIIL is committed to protecting your privacy. This Policy explains how we collect, use, share, and safeguard personal data when you use our marketplace platform as a User (Client) or as a Business representative.

---

## 1. Our role

VAXIIL operates a marketplace. We process account, booking, payment-related, and verification data to run the platform. **Businesses** that you book with may receive the personal data necessary to fulfill the appointment (subject to your visibility and share-consent choices). VAXIIL does not provide the underlying wellness services.

---

## 2. Data we collect

### For Users
- Account data: email, name, phone (optional), credentials, Trust Alias  
- Profile preferences: visibility toggles (real name, phone, email), date of birth / sex if provided  
- Booking data: services, times, special requests, share consents for a booking  
- Payment data: amounts, currency, transaction status, wallet credits (payment card details are handled by payment providers)  
- Device/technical data: app/browser type, approximate logs for security  
- Bot-protection signals processed by Cloudflare Turnstile when you use login, registration, password reset, and similar forms (see section 5.1)  
- KYC / identity-verification data processed via **Sumsub** when you verify your identity (government ID images, selfie/liveness, applicant identifiers; see section 5.2)  

### For Businesses
- Organization profile, contacts, addresses, catalogue, team memberships  
- KYB documents and verification status  
- Booking and analytics aggregates related to your organization  
- Fee configuration visibility (rates managed by VAXIIL staff)  
- Settlement destination details you provide (IBAN/bank details, mobile-money phone numbers, Interac email)  

---

## 3. Purposes

We use data to: create and secure accounts; enable discovery and booking; process payments and refunds/wallet credits; apply platform fees and verification/subscription fees; verify Users/Businesses (including via Sumsub); process settlement requests; provide support; improve safety and prevent fraud (including bot protection); comply with law; and communicate service messages.

---

## 4. Privacy features we guarantee as a platform

- **Trust Alias** and related privacy controls so you can limit exposure of legal identity  
- Booking-level share consents where a Business requires certain fields  
- Role-based access so Business staff see client details only as needed for operations  
- Security measures appropriate to our size and risk (access controls, encrypted transport, bot protection)

VAXIIL’s privacy commitment covers **how the platform handles data**. Each Business remains responsible for how they handle client data after receiving it for a booking.

---

## 5. Sharing

We share data with:
- The **Business** involved in your booking (as needed to deliver the service)  
- **Payment providers** (e.g. to create payment links and confirm status)  
- **Sumsub** for identity verification (KYC) when you start or continue verification  
- **Infrastructure** processors hosting our systems  
- **Cloudflare** (Turnstile) for bot protection on authentication and similar forms  
- Authorities when legally required  

We do not sell personal data.

### 5.1 Cloudflare Turnstile (bot protection)

To protect accounts and forms against automated abuse, we use Cloudflare Turnstile. Turnstile may process technical signals such as IP address, TLS fingerprint, User-Agent, site key, and related client-side signals solely to distinguish humans from bots.

Turnstile may run in **invisible mode**, in which case you may not see a widget or other visual indication that a challenge is running. Processing still occurs as described by Cloudflare.

As required for Turnstile invisible mode, we reference Cloudflare’s **Turnstile Privacy Addendum**, which governs Cloudflare’s processing of those signals:

https://www.cloudflare.com/turnstile-privacy-policy/

That Addendum supplements Cloudflare’s Privacy Policy. For questions about Cloudflare’s processing, you may also contact Cloudflare’s Data Protection Officer as described in the Addendum.

### 5.2 Sumsub (identity verification)

When you verify your identity, we use **Sumsub** as our KYC processor. Sumsub may receive and process identity documents, selfie or liveness images, and related applicant metadata under Sumsub’s terms and privacy policy. We store Sumsub applicant identifiers and verification outcomes on your Vaxiil account. Identity documents downloaded after verification may be retained on Vaxiil for the verification lifecycle and legal/accounting periods.

Sumsub privacy information: https://sumsub.com/privacy-notice/

---

## 6. Retention

We retain account and booking records for as long as needed to provide the service, resolve disputes, meet legal/accounting obligations, then delete or anonymize where practicable. Verification documents and Sumsub-related records are retained for the verification lifecycle and applicable legal periods. Settlement destination details are retained while your organization uses settlement features and for accounting periods thereafter. Turnstile challenge tokens are short-lived and used only to validate the relevant form submission.

---

## 7. Your rights

Subject to applicable law and regulations, you may request access, correction, deletion, or restriction of your personal data, and object to certain processing. Contact VAXIIL support via the app or at info@bapimagine.com. You may also withdraw visibility consents in settings (which may affect ability to book with some Businesses).

---

## 8. International transfers

If processors or tools (including Cloudflare) are located in other countries, we take reasonable steps to protect data in line with this Policy and applicable requirements.

---

## 9. Children

VAXIIL is not directed at children. Do not create an account if you are not legally able to contract in your jurisdiction.

---

## 10. Changes

We may publish a new Privacy Policy version. Material changes require renewed acceptance before continued use of the platform.

---

## 11. Contact

Privacy requests and questions: VAXIIL support through the application or at info@bapimagine.com.
""".strip()

PRIVACY_FR = """
# Politique de confidentialité — VAXIIL

**Version :** 2026.08.04  
**Date d’effet :** 4 août 2026  
**Responsable de traitement :** BAP IMAGINE SPRL (RC 0068614/25, NIF 4003075266), exploitant la plateforme VAXIIL.  
**Contact :** info@bapimagine.com

VAXIIL s’engage à protéger votre vie privée. La présente Politique explique comment nous collectons, utilisons, partageons et protégeons les données personnelles lorsque vous utilisez notre place de marché en tant qu’Utilisateur (Client) ou représentant d’une Entreprise.

---

## 1. Notre rôle

VAXIIL exploite une place de marché. Nous traitons des données de compte, de réservation, liées aux paiements et à la vérification pour faire fonctionner la plateforme. Les **Entreprises** avec lesquelles vous réservez peuvent recevoir les données nécessaires à l’exécution du rendez-vous (sous réserve de vos choix de visibilité et de consentement de partage). VAXIIL ne fournit pas les services de bien-être sous-jacents.

---

## 2. Données collectées

### Pour les Utilisateurs
- Données de compte : e-mail, nom, téléphone (optionnel), identifiants, Trust Alias  
- Préférences de profil : interrupteurs de visibilité (nom réel, téléphone, e-mail), date de naissance / sexe si fournis  
- Données de réservation : services, horaires, demandes spéciales, consentements de partage  
- Données de paiement : montants, devise, statut, crédits portefeuille (les données de carte sont traitées par les prestataires de paiement)  
- Données techniques : type d’appareil/navigateur, journaux de sécurité  
- Signaux de protection anti-bots traités par Cloudflare Turnstile lors de la connexion, de l’inscription, de la réinitialisation du mot de passe et formulaires similaires (voir section 5.1)  
- Données KYC / vérification d’identité traitées via **Sumsub** lorsque vous vérifiez votre identité (pièces d’identité, selfie/vivacité, identifiants demandeur ; voir section 5.2)  

### Pour les Entreprises
- Profil d’organisation, contacts, adresses, catalogue, membres d’équipe  
- Documents KYB et statut de vérification  
- Agrégats de réservation et d’analytique  
- Visibilité de la configuration des frais (taux gérés par le personnel VAXIIL)  
- Destinations de règlement que vous fournissez (IBAN/banque, téléphone mobile money, e-mail Interac)  

---

## 3. Finalités

Nous utilisons les données pour : créer et sécuriser les comptes ; permettre la découverte et la réservation ; traiter paiements et remboursements/crédits ; appliquer les frais de plateforme et les frais de vérification/abonnement ; vérifier Utilisateurs/Entreprises (y compris via Sumsub) ; traiter les demandes de règlement ; fournir le support ; améliorer la sécurité et prévenir la fraude (y compris la protection anti-bots) ; respecter la loi ; et envoyer des messages de service.

---

## 4. Engagements de confidentialité de la plateforme

- **Trust Alias** et contrôles associés pour limiter l’exposition de l’identité légale  
- Consentements de partage au niveau de la réservation lorsqu’une Entreprise l’exige  
- Accès basé sur les rôles pour que le personnel de l’Entreprise ne voie les détails clients que pour l’exploitation  
- Mesures de sécurité adaptées (contrôles d’accès, transport chiffré, protection anti-bots)

L’engagement de VAXIIL porte sur **le traitement des données par la plateforme**. Chaque Entreprise reste responsable du traitement des données clients après réception pour une réservation.

---

## 5. Partage

Nous partageons des données avec :
- l’**Entreprise** concernée par votre réservation (dans la mesure nécessaire) ;  
- les **prestataires de paiement** ;  
- **Sumsub** pour la vérification d’identité (KYC) lorsque vous démarrez ou continuez une vérification ;  
- les **prestataires d’infrastructure** hébergeant nos systèmes ;  
- **Cloudflare** (Turnstile) pour la protection anti-bots sur l’authentification et formulaires similaires ;  
- les autorités lorsque la loi l’exige.  

Nous ne vendons pas les données personnelles.

### 5.1 Cloudflare Turnstile (protection anti-bots)

Pour protéger les comptes et formulaires contre les abus automatisés, nous utilisons Cloudflare Turnstile. Turnstile peut traiter des signaux techniques tels que l’adresse IP, l’empreinte TLS, l’en-tête User-Agent, la clé de site et d’autres signaux côté client, uniquement pour distinguer les humains des bots.

Turnstile peut fonctionner en **mode invisible**, auquel cas vous pouvez ne voir aucun widget ni indication visuelle qu’un défi est en cours. Le traitement a néanmoins lieu comme décrit par Cloudflare.

Conformément aux conditions du mode invisible de Turnstile, nous référons à l’**Addendum de confidentialité Turnstile** de Cloudflare, qui régit le traitement de ces signaux par Cloudflare :

https://www.cloudflare.com/turnstile-privacy-policy/

Cet Addendum complète la Politique de confidentialité de Cloudflare. Pour toute question relative au traitement par Cloudflare, vous pouvez également contacter le délégué à la protection des données de Cloudflare comme indiqué dans l’Addendum.

### 5.2 Sumsub (vérification d’identité)

Lorsque vous vérifiez votre identité, nous utilisons **Sumsub** comme prestataire KYC. Sumsub peut recevoir et traiter des pièces d’identité, des images selfie ou de vivacité, et des métadonnées de demandeur selon ses conditions et sa politique de confidentialité. Nous stockons les identifiants demandeur Sumsub et les résultats de vérification sur votre compte Vaxiil. Les documents d’identité téléchargés après vérification peuvent être conservés sur Vaxiil pour le cycle de vérification et les délais légaux/comptables.

Informations de confidentialité Sumsub : https://sumsub.com/privacy-notice/

---

## 6. Conservation

Nous conservons les comptes et réservations aussi longtemps que nécessaire pour le service, les litiges et les obligations légales/comptables, puis supprimons ou anonymisons lorsque c’est possible. Les documents de vérification et les enregistrements liés à Sumsub sont conservés pour le cycle de vérification et les délais légaux applicables. Les destinations de règlement sont conservées tant que votre organisation utilise le règlement, puis pour les délais comptables. Les jetons de défi Turnstile sont de courte durée et utilisés uniquement pour valider la soumission du formulaire concerné.

---

## 7. Vos droits

Sous réserve du droit et des réglementations applicables, vous pouvez demander l’accès, la rectification, l’effacement ou la limitation, et vous opposer à certains traitements. Contactez le support VAXIIL via l’application ou à info@bapimagine.com. Vous pouvez aussi retirer des consentements de visibilité dans les paramètres (ce qui peut affecter la possibilité de réserver chez certaines Entreprises).

---

## 8. Transferts

Si des prestataires ou outils (y compris Cloudflare) sont situés dans d’autres pays, nous prenons des mesures raisonnables pour protéger les données conformément à la présente Politique.

---

## 9. Enfants

VAXIIL ne s’adresse pas aux enfants. Ne créez pas de compte si vous n’avez pas la capacité juridique de contracter.

---

## 10. Modifications

Nous pouvons publier une nouvelle version de la Politique. Les changements importants exigent une nouvelle acceptation avant poursuite de l’utilisation.

---

## 11. Contact

Demandes relatives à la confidentialité : support VAXIIL via l’application ou à info@bapimagine.com.
""".strip()
