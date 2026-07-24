"""Accepted venue / location type helpers shared by orgs, services, and bookings."""

from __future__ import annotations

DEFAULT_LOCATION_TYPES = ['O', 'H', 'V', 'B']
VALID_LOCATION_TYPES = frozenset(DEFAULT_LOCATION_TYPES)


def normalize_location_types(value) -> list[str]:
    if not value:
        return []
    out: list[str] = []
    for item in value:
        code = str(item).strip().upper()
        if code in VALID_LOCATION_TYPES and code not in out:
            out.append(code)
    return out


def default_location_types() -> list[str]:
    return list(DEFAULT_LOCATION_TYPES)


def effective_location_types(service) -> list[str]:
    """Service override when non-empty; otherwise organization defaults (or all four)."""
    service_types = normalize_location_types(getattr(service, 'accepted_location_types', None))
    if service_types:
        return service_types
    org = getattr(service, 'organization', None)
    org_types = normalize_location_types(getattr(org, 'accepted_location_types', None))
    return org_types or default_location_types()
