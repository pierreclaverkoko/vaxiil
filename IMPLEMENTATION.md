# Vaxiil SaaS Wellness Platform - Implementation Progress

## Project Overview
SaaS platform for wellness services (massage, therapy, room rentals) with privacy-focused features, multi-tenancy, and comprehensive booking/payment system.

## Implementation Progress

### Phase 1: Django SaaS Foundation (25% / 25%)
- [x] Project Structure Creation (5% / 5%)
- [x] Core Setup (5% / 10%)
- [x] Authentication & Authorization (8% / 8%)
- [x] Initial Models (7% / 7%)

### Phase 2: Services & Booking System (~18% / 30%) — **catalog and booking REST; availability and team workflows underway**
- [x] Service Management (~6% / 12%) — **partial**
  - [x] Dynamic Organization Types (2% / 2%)
    - [x] Create OrganizationType model with dynamic instances (`OrganizationTypeModel`)
    - [x] Update Organization model to use FK to OrganizationType
    - [x] Create admin interface for managing organization types (`OrganizationTypeModelAdmin`, `OrganizationTypeSubCategoryAdmin`)
    - [ ] Data migration for existing organization types (only if legacy enum data needs backfill)
  - [x] Service Categories & Sub-categories (4% / 4%)
    - [x] Create ServiceCategory / ServiceSubCategory models
    - [x] Link **organization types** to default sub-categories (`OrganizationTypeSubCategory`); not a direct Organization↔SubCategory M2M
    - [x] Admin for categories, sub-categories, and org-type↔subcategory links
    - [ ] Add per-organization sub-category management in `OrganizationAdmin` (not present; links are type-level)
  - [x] Service Catalog (2% / 4%)
    - [x] Service, ServiceVariant (`ServiceVariantModel`), ServiceMedia models with availability fields
    - [x] Flexible scheduling / day & seasonal fields on `Service` (see model + tests in `services/tests/test_availability.py`)
    - [x] Comprehensive Django admin for services, variants, media (`services/admin.py`)
  - [x] Service Features (~1.5% / 2%) — **models + admin; no public API**
    - [x] `ServiceFeature`, `ServiceFeatureMapping` (and related types)
    - [x] Admin for features and inline mapping on `Service`
    - [x] REST catalog — `GET /api/v1/services/categories/`, `GET /api/v1/services/` (search, `featured`, `category`, `sub_category`; paginated `page_size`) — see `services/views.py`, `services/serializers.py`, `services/tests/test_catalog_api.py`
    - [ ] REST for **ServiceFeature** and non-catalog service write/admin APIs (not exposed)
- [x] Booking Engine (~7% / 10%) — **booking REST, status actions, and overlap validation**
  - [x] Availability Management (schema)
    - [x] BusinessHours, AvailabilityException, PractitionerAvailability, ResourceAvailability models
    - [x] `AvailabilityService` validates overlap, notice windows, and business hours; `list_open_slots` + `GET /api/v1/services/{id}/open-slots/`
  - [x] Booking Models (4% / 4%)
    - [x] Booking, BookingTimeSlot, BookingLog, BookingRescheduleProposal; status choices and `confirm` / `complete` / `cancel` on `Booking`
    - [x] Django admin for bookings, BusinessHours, AvailabilityException (`bookings/admin.py`)
  - [x] Booking Logic (~2% / 2%)
    - [x] Booking creation/reschedule availability validation
    - [x] Organization-staff confirmation (requires `is_paid`), rejection (refund if paid), and completion workflows (complete only after earliest slot start)
    - [x] Reschedule as counterparty proposal (accept requires `is_paid` → Confirmed; decline → cancel + store-credit refund if paid)
    - [x] Org/service `accepted_location_types`; service `price_min`/`price_max` derived from variants
    - [x] In-app notifications + Verdant Pulse HTML emails on booking received / confirmed / cancelled / reschedule events (`/api/v1/notifications/`; Angular + Flutter inbox)
  - [x] In-app messaging (`/api/v1/messaging/`; P2P invites, booking/support/platform support threads; business starts booking chat after payment until complete/slot end; Angular + Flutter)
  - [x] Scoped personal / business / staff message & notification feeds (`audience`, `?scope=` / `?organization_id=`)
  - [x] Operating addresses via django-cities (`city_id`, nested `/organizations/{id}/addresses/`); user `default_country` + catalog `?country=`
  - [x] Country filter scope: middleware + `X-Country`/`X-Timezone`/`X-Resolved-Country`, `geo-country` detect, country-scoped services + trusted venues (paginated discovery), client localStorage/secure storage + autocomplete
  - [x] Payment receipt + wallet top-up emails; team invite emails; booking notification CTAs; KYC/KYB validation emails
  - [x] Service primary image upload for providers (`POST .../services/{id}/media/`); feature choice cards on create/edit
  - [x] Staff user detail (`/staff/users/:id`) with KYC preview, platform support chat, manual refund-wallet credit/debit
  - [x] Staff settlements queue + FX rates on fees config; org revenue debit from KYB modal
    - [x] First-time email verification gate (`email_verified_at`, OTP purpose `E`, welcome email with quick actions; Angular + Flutter blocking pages)
    - [ ] Practitioner alias request system
    - [x] Conflict detection: overlap validation names conflicting booking ref/time (no full resolution workflow)
    - [x] REST API for bookings (create, confirm, reject, cancel, reschedule propose/accept/decline)
- [x] Business Features (~2% / 8%) — **cancellation/analytics are model-layer; not productized**
  - [x] Cancellation System — **models + instance logic**
    - [x] `CancellationPolicy`, `CancellationRequest`, `CancellationAuditLog` with penalty/refund helpers and `approve`/`reject`
    - [ ] Admin registration for cancellation models (**not in admin**)
    - [x] End-to-end cancellation flows exposed via API/views (cancel/reject + refund wallet credit)
    - [x] Refund wallet (store credit on cancel; apply at payment-link)
- [ ] Business Management — **live organization aggregates; no dashboard or reporting app**
    - [x] `BookingAnalytics`, `PractitionerPerformance`, `ServiceAnalytics`, `ResourceUtilization` models with helper methods
    - [x] Organization analytics API with live booking counts and paid completed revenue
    - [ ] Practitioner assignment **system** (assignment fields may exist on `Booking`; no workflow)
    - [ ] Resource scheduling optimization (no runtime optimizer)
    - [ ] Business reporting features (no reports or scheduled aggregation jobs wired)

### Phase 3: Payment & Store Credit System (~6% / 15%) — **partial**
- [x] Payment Integration (~4% / 8%) — **partial**
  - [x] Secure collection via MM Aggregator adapter (user-facing copy de-branded)
  - [x] Booking collect + webhook sets `is_paid` (status stays Requested until business confirms)
  - [x] Store credit (refund wallet) credit on cancel/reject/reschedule-decline, apply at checkout, top-up via collection
  - [x] Booking `payment_state` (`paid`/`processing`/`unpaid`/`refunded`) + `pending_payment_reference` for client badges; in-flight collect shows Processing (not Unpaid), hides Pay now, Refresh status via `POST .../transactions/{ref}/refresh/`; cancel refund txns use status Refunded; full refund marks original PAYMENT Refunded
  - [x] MM Aggregator Vaxiil setup runbook: `docs/backend/payment_integration/vaxiil_setup.md` (admin per-operator CD/CG/BI rails + identifier UI config)
  - [x] PaymentMethod identifier UI (`identifier_type` phone/email/generic, placeholders, dial codes); grouped amount+currency; truncated red error banners; profile Add funds modal
  - [ ] Full multi-provider / store-credit productization
- [x] Financial Models (~2% / 7%) — **partial**
  - [x] Platform fee snapshots on booking + staff fee APIs
  - [x] User inscription fee ($5 USD eq, one-time) + business annual fee ($15 USD eq) on first successful booking payment; staff FX rates; org revenue wallet/ledger
  - [x] Business settlement accounts/settings/requests + staff complete/reject (confirmation image staff-only)
  - [x] PaymentConnector / PaymentMethod catalog (Django admin) + settlement accounts on PaymentMethod; currency autocomplete; Management Admin link (`vx-mgmt/`) for superusers
  - [x] Refund wallet / ledger (including TOP_UP)
  - [x] Broader ledger / reporting surfaces (consumer `GET /payments/transactions/` + web/Flutter lists; staff ledger already shipped)
  - [x] Consumer transaction detail + provider status refresh (`POST .../transactions/{ref}/refresh/` → MM Aggregator deposit status check; web modal; Flutter on-card refresh)

### Phase 4: Privacy & Security Features (~4% / 15%) — **partial**
- [ ] Trust Alias System (0% / 7%)
- [ ] KYC/KYB Framework (~5.5% / 8%) — **partial**
  - [x] User KYC: `rejection_reason` and `verified_at` on profile JSON; Django admin approval sets `verified_at` and clears rejection; `POST /api/v1/auth/verify/` (multipart, legacy fallback)
  - [x] Sumsub KYC: `POST /api/v1/auth/kyc/sumsub/access-token/`, `POST /api/v1/auth/kyc/sumsub/websdk-link/`, `POST /api/v1/auth/kyc/sumsub/return/` (redirect JWT + applicant/docs sync), `POST /api/v1/auth/webhooks/sumsub/` (HMAC); `User.sumsub_applicant_id` + `UserKycSumsubEvent`; webhook/return drive `verification_status` (see `docs/integrations/sumsub.md`)
  - [x] Organization KYB: `POST /api/v1/organizations/{id}/submit-verification/` (multipart); org detail includes `rejection_reason`, license/tax fields; admin approval sets `verified_at`
  - [x] Flutter: Sumsub Idensic SDK on mobile + WebSDK link fallback on Flutter web; business KYB upload on `BusinessProfilePage` (`OrganizationKybSection`)
  - [x] Angular: KYC page redirects to Sumsub WebSDK; return route `/profile/verify/return`
  - [x] Staff review APIs: `/api/v1/staff/users/` + `/api/v1/staff/organizations/` approve/reject/suspend (status-gated); `GET /staff/overview/`; Angular staff admin kit + Chart.js home (W5); profile exposes `is_staff`
  - [x] KYC required to create bookings (backend + Angular/Flutter Book gates)
  - [x] KYC required for wallet top-up (backend + Angular/Flutter profile gates)
  - [x] Process payment wizard (Bank/MoMo/Fintech/Crypto → method + country → amount/currency → confirm) on Angular + Flutter
  - [x] Optional organization venue address; At venue (`O`) gated when no usable venue
  - [x] Service list cards show town + accepted location-type tags (list API city + effective types)
  - [x] Transactional email logo uses frontend `/assets/logo.png`
  - [x] Email OTP login 2FA + password change/reset endpoints; profile `two_factor_enabled` toggle (Angular security + Flutter profile); HTML OTP mail; forgot-password UI (Angular + Flutter)
  - [x] Cloudflare Turnstile on guest auth POSTs (`TurnstileField` + siteverify; Angular + Flutter widgets; `cf_turnstile_response`)
  - [x] Generic `AuditEvent` + `AuditedModelMixin` (IP, user agent, optional GPS) on payments, booking actions, cancellations, legal acceptances

### Phase 5: Advanced Features (0% / 10%)
- [ ] Enhanced Functionality (0% / 5%)
- [ ] Performance & Optimization (0% / 5%)

### Phase 6: Flutter Application Foundation (15% / 15%) ✅ COMPLETED
- [x] Project Setup & Configuration (3% / 3%)
  - [x] Initialize Flutter project with proper structure
  - [x] Configure pubspec.yaml with all dependencies
  - [x] Set up platform-specific configurations (Android/iOS/Web)
  - [x] Configure build scripts and CI/CD pipeline
  - [x] Set up code quality tools (very_good_analysis)
- [x] Architecture Setup (4% / 4%)
  - [x] Implement clean architecture with feature-based structure
  - [x] Set up dependency injection (get_it + injectable)
  - [x] Configure state management (bloc/cubit)
  - [x] Set up routing (go_router)
  - [x] Create base classes and interfaces
- [x] Core Services & Utilities (3% / 3%)
  - [x] Implement HTTP client with Dio and interceptors
  - [x] Set up secure storage for JWT tokens
  - [x] Create logging service
  - [x] Implement network connectivity monitoring
  - [x] Set up error handling and reporting
- [x] Theming & Design System (5% / 5%)
  - [x] Extract colors from vaxiil_logo.png for theme
  - [x] Create design system based on theme_like_example.jpeg
  - [x] Implement responsive design utilities
  - [x] Create custom widgets and components
  - [x] Set up dark/light theme support

### Phase 7: Authentication & User Management (~7% / 10%) — in progress
- [x] Authentication Flow (~3.5% / 4%) — complete except Apple SSO
  - [x] Implement JWT authentication with refresh tokens (Django: `token_blacklist`, `TokenRefreshView`/`TokenVerifyView`; SimpleJWT access/refresh; Flutter: `AuthRepository`, secure storage)
  - [x] Create login, register, and logout screens (soft theme, Heroicons, `AuthCubit`, `GoRouter` auth redirects)
  - [x] Implement biometric authentication (`BiometricService`, profile toggle, optional unlock on home when enabled)
  - [x] Add social login integration — **Google** (`POST /auth/google/` with ID token; Flutter `google_sign_in` + server `GOOGLE_OAUTH_CLIENT_ID`)
  - [ ] Add social login integration — **Apple** (not implemented)
  - [x] Set up automatic token refresh (`AuthInterceptor` → `auth/token/refresh/` with rotation/blacklist support)
- [ ] User Profile Management (~2.5% / 3%) — **partial** (KYC done; privacy API wiring pending)
  - [x] Create user profile screens and forms (`ProfilePage`, `EditProfilePage`; `PUT /auth/profile/`)
  - [x] Implement profile photo upload (`User.avatar`, `POST /auth/avatar/` multipart; gallery pick on edit profile)
  - [x] Add trust alias system integration — **read-only** display on profile (`trust_alias` from API; generate/verify endpoints exist server-side)
  - [x] About & branding — `AboutPage` (version via `package_info_plus`), Terms/Privacy placeholder pages, `VaxiilLogo` on splash + login/register, Appearance (`/theme`) for system/light/dark
  - [x] KYC/KYB verification in app — user identity (`IdentityVerificationPage`, gallery/camera, rejection feedback from API) + org KYB (`OrganizationKybSection` on business profile, `submit-verification` API)
  - [ ] Implement privacy settings UI (`show_real_name` / `show_phone_number` wired to API; `PrivacySettingsPage` exists)
- [ ] Business Management (~1.5% / 3%) — **partial** (stub screens only; APIs & analytics pending)
  - [x] Create business registration and onboarding — first-pass UI (`BusinessListPage`, `BusinessSetupPage`; not wired to organization APIs yet)
  - [ ] Implement business switching interface (multi-organization selection)
  - [x] Add business profile management — stub page (`BusinessProfilePage` by query id)
  - [ ] Create practitioner management system
  - [ ] Implement business analytics dashboard

## Current Status: ~57% Complete — Phase 7 auth/profile largely done; Phase 2 has **authenticated service catalog REST** + Flutter Services tab (browse/search/featured carousel); **bookings REST**, availability engine, and **booking/cancellation admin** still outstanding

## Phase 1 Completed Features
✅ **Project Structure**: Complete Django project with apps structure
✅ **Core Setup**: Dependencies, settings, middleware, and base configuration
✅ **Authentication & Authorization**: JWT system with custom User model
✅ **Initial Models**: User, Organization with soft delete and multi-tenancy

## Phase 2 In Progress (~15% / 30%)
✅ **Service Management**: Rich Django admin for org types, categories, services, variants, media, features; org-type↔subcategory links  
✅ **REST catalog**: `services/categories/` + `services/` list (search/filters/pagination) for the mobile client  
⏳ **REST layer**: `bookings/` router still empty — no booking API yet; ServiceFeature and other write APIs not productized  
✅ **Booking Engine**: Booking and availability **models** with basic status transitions on `Booking`  
⏳ **Runtime**: No availability checker, no booking creation service, no booking admin UI  
✅ **Business Features**: Cancellation and analytics **models** (policies, requests, audit, metrics)  
⏳ **Product**: No cancellation/analytics admin, dashboards, or reporting pipelines

## Phase 6 Foundation Completed (15% / 15%) ✅
✅ **Flutter Project**: Successfully initialized with proper structure
✅ **Dependencies**: All required packages configured and installed
✅ **Architecture**: Clean architecture with feature-based structure
✅ **Network Layer**: Dio client with auth, error, and logging interceptors
✅ **Storage**: Secure storage service for JWT tokens and user data
✅ **Theme System**: Complete theme with logo colors and dark/light mode
✅ **State Management**: BLoC pattern with base classes and providers
✅ **Routing**: Go Router with navigation and deep linking
✅ **Logging**: Comprehensive logging service with performance tracking
✅ **Network**: Connectivity monitoring with offline support
✅ **Responsive**: Design utilities for mobile, tablet, and desktop
✅ **Widgets**: Custom button components and UI elements
✅ **CI/CD**: GitHub Actions workflow and build scripts

## Phase 7 Completed / Remaining (summary)
**Done:** End-to-end JWT (register/login/logout, refresh/blacklist), Flutter `AuthCubit` + `GoRouter` guards, login/register/splash UI, Dio token refresh interceptor, Google Sign-In (server + app), biometric opt-in + unlock, profile + edit profile + avatar upload API, trust alias shown on profile, KYC identity + KYB org verification flows (API + Flutter), About + **versioned Terms/Privacy (en/fr) with signup + re-accept gates** (fees + Sumsub named in Privacy), appearance settings, branded logo on splash/auth, public routes (`/about`, `/theme`, `/terms`, `/privacy`) when logged out, theme-aware `SoftCard` + bottom navigation for dark mode. **Platform fee (gain rate)** with global/category/org overrides (staff-managed), fee ledger, client/business payer rules, **$5 inscription / $15 annual fees** (FX), and **business settlement** UI.

**Remaining for Phase 7:** Apple Sign-In; privacy toggles wired to API; wire remaining business screens to `organizations` APIs; business switching; practitioner tools; business analytics UI.

**Client catalog (done):** Authenticated `GET /api/v1/services/categories/` and `GET /api/v1/services/`; Flutter `ServiceCatalogRepository`, `heroIconFromDbName` for `ServiceCategory.icon` (kebab-case Heroicon names), and `ServicesPage` (mint discovery layout: pill search + filter sheet, category orbs with **All** first, horizontal **Featured / Favorite / Nearby** carousels with rating badge + heart + Book now, then home-style vertical `DiscoveryServiceCard` feed). `sub_category` query param is supported on the client for future filters.

### Planned: service ratings & favorites (backend — mobile data layer ready)

**Flutter (implemented for forward compatibility):**

- `ServiceListItemModel` optional fields: `average_rating` → `averageRating`, `rating_count` → `ratingCount`, `is_favorite` → `isFavorite`; `ratingLabel` formats one decimal for UI badges.
- Favorites not yet from API: client stores a list of service UUIDs in secure storage under `favorite_service_ids` and merges with `is_favorite` when the API adds it.
- Repository: `listServices` accepts `subCategoryId` (maps to `sub_category` query param; already supported by `ServiceCatalogFilter`).

**Backend (to implement):**

1. **Aggregate rating** on catalog list/detail: add `average_rating` (float, nullable) and `rating_count` (int) on `ServiceListSerializer` / `ServiceDetailSerializer`, sourced from a `ServiceReview` or post-booking feedback model (define aggregation rules, e.g. mean of published reviews).
2. **Favorites:** `POST` / `DELETE` ` /api/v1/services/{id}/favorite/` (or `PATCH` user profile relation) with `GET /api/v1/services/?favorites=1` or `GET /api/v1/users/me/favorite-services/` returning the same list shape as the catalog. Sync client storage with server on login.
3. **Nearby:** extend catalog with `ordering=distance` and `lat`/`lng` (or `place_id`) query params; require GeoDjango / point field on `Organization` or `Service` address; filter `Service` queryset by distance.

## Next Steps
1. ✅ Set up project structure with uv and pyproject.toml
2. ✅ Configure pre-commit hooks
3. ✅ Initialize Django project with custom structure
4. ✅ Complete authentication system (core JWT + Phase 7 client flows)
5. ✅ Create initial models with admin interfaces
6. ⏳ Set up PostgreSQL with GeoDjango
7. ✅ Begin Phase 2: Services & Booking System (8% complete)
8. ⏳ Phase 2: Expose **bookings** via DRF (ViewSets), availability + booking services, admin for bookings/cancellations (service **catalog** list endpoints are live)
9. ⏳ Finish Phase 7: Apple SSO, org API integration, privacy/KYC UI
10. ⏳ Begin Phase 3: Payment & Store Credit System

## Technical Stack
- **Backend**: Django + Django REST Framework
- **Database**: PostgreSQL with GeoDjango
- **Package Manager**: uv with pyproject.toml
- **Code Quality**: flake8, black, ruff, django-upgrade (120 line limit)
- **Authentication**: JWT
- **Frontend**: Django Admin (interim for legacy) + Flutter mobile app (Phase 6–7 foundation + auth live) + Angular web (`web/`, **100%** — W0–W6 complete including platform staff queues; see [docs/web/implementation.md](docs/web/implementation.md))
- **Deployment**: Docker (future)

## Key Features
- Multi-tenancy via Organization model
- Soft deletes with global unique constraints
- UUID primary keys for all models
- Trust alias system for privacy
- Store credit payment system
- Geo-based service discovery
- KYC/KYB verification framework
