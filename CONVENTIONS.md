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
