# Mobile / Web responsive progress

Last updated: 2026-07-18

## Summary

| Metric | Value |
|--------|-------|
| **Overall** | **100%** |
| Foundation (25% weight) | 100% |
| Pages mean (75% weight) | 100% |

Formula: `overall = 0.25 * foundation% + 0.75 * mean(page scores)`.  
Page score = 50% small + 50% large (`done`=1, `partial`=0.5, `todo`=0).

---

## Foundation (25% of overall)

| Item | Status | Weight |
|------|--------|--------|
| Breakpoint helpers (`md` 768 / `lg` 1024 / shell 768) | done | 1/6 |
| Shell bottom-nav conditional (hide ≥768) | done | 1/6 |
| Expanded top nav links | done | 1/6 |
| Site footer (`VaxiilSiteFooter`) | done | 1/6 |
| Logo asset swap (`assets/logo.png`) | done | 1/6 |
| Stitch images in `assets/images/` (38 files + `StitchImages`) | done | 1/6 |

**Foundation %:** 100%

### Key files

- [`mobile/lib/shared/utils/responsive.dart`](../../mobile/lib/shared/utils/responsive.dart) — `shellBreakpoint` / `mdBreakpoint` / `lgBreakpoint`
- [`mobile/lib/shared/widgets/vaxiil_main_shell.dart`](../../mobile/lib/shared/widgets/vaxiil_main_shell.dart) — conditional pill
- [`mobile/lib/shared/widgets/vaxiil_frosted_top_bar.dart`](../../mobile/lib/shared/widgets/vaxiil_frosted_top_bar.dart) — logo + expanded nav
- [`mobile/lib/shared/widgets/vaxiil_site_footer.dart`](../../mobile/lib/shared/widgets/vaxiil_site_footer.dart) — footer + `ResponsiveContent`
- [`mobile/lib/core/constants/stitch_images.dart`](../../mobile/lib/core/constants/stitch_images.dart) — local asset paths

---

## Pages (75% of overall)

Status: `todo` | `partial` | `done`

### Stitch-mapped

| Page | Stitch source | Small | Large | Notes |
|------|---------------|-------|-------|-------|
| splash_page | splash_onboarding_refined | done | done | Collage row height md+; local images; logo asset |
| login_page | login | done | done | Compact form; md split image+form; site footer |
| register_page | signup | done | done | Compact form; md split panel; site footer |
| home_page | home_discovery_with_logo | done | done | max-w-7xl; hero 8+4; cards 1→2→3; footer |
| bookings_page | my_bookings_1, my_bookings_2 | done | done | max-w-2xl rail; chrome + footer |
| booking_detail_page | booking_details_* | done | done | max-w-2xl; footer |
| service_booking_page | booking_scheduling_refined | done | done | max-w-2xl; footer |
| service_detail_page | service_details_* | done | done | Full-bleed hero; constrained sheet; footer |
| profile_page | profile_* | done | done | max-w-2xl; footer |
| messages_page | notifications | done | done | max-w-2xl; footer |
| business_list_page | my_companies | done | done | Grid 1→2→3; title scale; footer |
| business_profile_page | company_hub_*, business_hub_kyb_* | done | done | Banner md:row; lg 7+5; footer |
| business_analytics_page | company_analytics | done | done | KPI md:3; charts lg:2; footer |
| business_settings_page | company_settings | done | done | lg 8+4 sidebar save; compact floating save |

### Orphan (no dedicated Stitch HTML)

| Page | Small | Large | Notes |
|------|-------|-------|-------|
| booking_confirmation_page | done | done | max-w-2xl + footer |
| services_page | done | done | max-w-7xl + footer |
| business_bookings_page | done | done | max-w rail + footer |
| business_booking_detail_page | done | done | max-w-2xl + footer |
| business_services_page | done | done | 1→2 cols md+ |
| business_service_edit_page | done | done | form max-w-2xl |
| business_team_page | done | done | 1→2 cols md+ |
| business_setup_page | done | done | form max-w |
| edit_profile_page | done | done | form max-w |
| privacy_settings_page | done | done | form max-w |
| theme_settings_page | done | done | form max-w |
| identity_verification_page | done | done | form max-w |
| about_page | done | done | max-w centered |

**Pages mean %:** 100%

---

## Chrome behavior (shell)

| Width | Bottom pill | Top bar | Site footer |
|-------|-------------|---------|-------------|
| &lt; 768 | Visible | Menu + logo + avatar | Hidden |
| ≥ 768 | Hidden | Logo + Discover/Bookings/Messages/Profile + avatar | Shown at scroll end / auth |

---

## Tests

- `test/vaxiil_main_shell_test.dart` — pill, expanded nav, footer, breakpoints
- `test/splash_page_test.dart` — onboarding + logo asset
- `test/widget_test.dart` — app smoke
