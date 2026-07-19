"""Shared search / ordering helpers for staff list endpoints."""

from __future__ import annotations

from django.db.models import Q, QuerySet
from rest_framework.request import Request


def apply_search(qs: QuerySet, request: Request, fields: list[str]) -> QuerySet:
    term = (request.query_params.get('search') or '').strip()
    if not term or not fields:
        return qs
    combined = Q()
    for field in fields:
        combined |= Q(**{f'{field}__icontains': term})
    return qs.filter(combined)


def apply_ordering(
    qs: QuerySet,
    request: Request,
    *,
    allowed: set[str],
    default: str,
) -> QuerySet:
    raw = (request.query_params.get('ordering') or '').strip() or default
    if raw.lstrip('-') not in allowed:
        raw = default
    return qs.order_by(raw)
