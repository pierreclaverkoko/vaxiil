# Project conventions

This document summarizes backend, API, and client conventions for the Vaxiil codebase.

## Backend (Django / DRF)

- Prefer **ViewSets** (`GenericViewSet` + `@action`) over function-based views; use `APIView` only when a ViewSet is a poor fit.
- **Choices**: define nested `TextChoices` / `IntegerChoices` on the owning model (for example `User.UserRole`). Use `max_length=1` for stored single-character enums unless a longer code is required.
- **CSS for API consumers**: when exposing choice fields with `django_drf_dynamics.serializers.fields.ChoiceEnumField`, implement optional `get_<field>_css()` on the model so the API returns a semantic Bootstrap-style token (`default`, `primary`, `secondary`, `success`, `warning`, `danger`, `info`). Do **not** duplicate CSS maps in serializers.
- Import `ChoiceEnumField` from `django_drf_dynamics.serializers.fields` (the package’s `serializers` package does not re-export it).
- **Migrations**: when changing stored codes or shrinking `max_length`, add a data migration before altering the column.
- **Python environment**: use **uv** for dependencies (`uv sync`, `uv add`, `uv run`).

## Mobile / backend contract

- Choice fields serialized with `ChoiceEnumField` appear as **`{ "value", "title", "css" }`**. The `css` key is a **semantic token**, not raw CSS.
- Flutter: parse with shared `ChoiceEnumData` / `ChoiceEnumWidget`; treat unknown `css` values safely (fallback styling).
- **Versioning**: APIs are under a version prefix (for example `/api/v1/`); JWT auth as implemented. Breaking JSON shape changes need coordinated mobile releases.

## Process and style

- Keep diffs focused; match existing code style; avoid unrelated refactors.

## Testing

- **Backend (Python):** When you change or add behavior, add or update **unit tests** in the same area. Run tests with `uv run pytest` (or the project’s documented command) before considering work complete.
- **Mobile (Flutter):** Add or update **unit/widget tests** for non-trivial logic and shared widgets. Run `flutter test` in `mobile/` before considering work complete.
- Cursor agents should **write tests alongside code changes** where practical and **verify** them by running the appropriate test command.
