"""Accepted venue / location type helpers shared by orgs, services, and bookings."""

from __future__ import annotations

DEFAULT_LOCATION_TYPES = ['O', 'H', 'V', 'B']
VALID_LOCATION_TYPES = frozenset(DEFAULT_LOCATION_TYPES)
OFFICE_LOCATION_TYPE = 'O'


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


def has_usable_venue_address(org) -> bool:
    """True when the org has any active address with street + city."""
    if org is None:
        return False
    addresses = getattr(org, 'addresses', None)
    if addresses is None:
        return False
    qs = addresses.filter(deleted_at__isnull=True).only('address', 'cities_city_id')
    for row in qs:
        if (row.address or '').strip() and row.cities_city_id:
            return True
    return False


def without_office(codes: list[str]) -> list[str]:
    return [c for c in codes if c != OFFICE_LOCATION_TYPE]


def strip_office_from_org_location_types(org) -> None:
    """Remove At-venue (O) from org defaults when the last usable venue is gone."""
    if org is None:
        return
    current = normalize_location_types(getattr(org, 'accepted_location_types', None))
    base = current or default_location_types()
    next_codes = without_office(base)
    if next_codes == current:
        return
    org.accepted_location_types = next_codes
    org.save(update_fields=['accepted_location_types', 'updated_at'])


def effective_location_types(service) -> list[str]:
    """Service override when non-empty; otherwise organization defaults (or all four).

    At-venue (O) is omitted when the organization has no usable venue address.
    """
    service_types = normalize_location_types(getattr(service, 'accepted_location_types', None))
    org = getattr(service, 'organization', None)
    if service_types:
        types = service_types
    else:
        org_types = normalize_location_types(getattr(org, 'accepted_location_types', None))
        types = org_types or default_location_types()
    if OFFICE_LOCATION_TYPE in types and not has_usable_venue_address(org):
        types = without_office(types)
    return types
