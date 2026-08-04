"""Resolve request country scope from headers, CDN, GeoIP, timezone, locale."""

from __future__ import annotations

import logging
import re
from functools import lru_cache
from pathlib import Path
from typing import TYPE_CHECKING

from django.conf import settings

from src.apps.core.request_meta import client_ip_from_request

if TYPE_CHECKING:
    from django.http import HttpRequest

    from src.apps.organizations.models import Country

logger = logging.getLogger(__name__)

HEADER_COUNTRY = 'HTTP_X_COUNTRY'
HEADER_TIMEZONE = 'HTTP_X_TIMEZONE'
CDN_ISO2_HEADERS = (
    'HTTP_CF_IPCOUNTRY',
    'HTTP_CLOUDFRONT_VIEWER_COUNTRY',
)

_ISO2_RE = re.compile(r'^[A-Za-z]{2}$')
_UUID_RE = re.compile(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
)
def active_country_by_iso2(iso2: str | None) -> Country | None:
    """Return active Vaxiil Country for an ISO-3166-1 alpha-2 code."""
    if not iso2 or not _ISO2_RE.match(iso2):
        return None
    from src.apps.organizations.models import Country

    return (
        Country.objects.filter(
            is_active=True,
            deleted_at__isnull=True,
            cities_country__code__iexact=iso2.upper(),
        )
        .select_related('cities_country')
        .first()
    )


def active_country_by_id(country_id: str | None) -> Country | None:
    if not country_id or not _UUID_RE.match(country_id):
        return None
    from src.apps.organizations.models import Country

    return (
        Country.objects.filter(
            pk=country_id,
            is_active=True,
            deleted_at__isnull=True,
        )
        .select_related('cities_country')
        .first()
    )


def country_from_x_country(request: HttpRequest) -> Country | None:
    raw = (request.META.get(HEADER_COUNTRY) or '').strip()
    if not raw:
        return None
    if _ISO2_RE.match(raw):
        return active_country_by_iso2(raw)
    return active_country_by_id(raw)


def country_from_cdn(request: HttpRequest) -> Country | None:
    for key in CDN_ISO2_HEADERS:
        raw = (request.META.get(key) or '').strip()
        if not raw or raw.upper() in {'XX', 'T1', 'ZZ'}:
            continue
        country = active_country_by_iso2(raw)
        if country is not None:
            return country
    return None


def country_from_ip(request: HttpRequest) -> Country | None:
    path = getattr(settings, 'GEOIP_PATH', '') or ''
    if not path:
        return None
    ip = client_ip_from_request(request)
    if not ip:
        return None
    try:
        from django.contrib.gis.geoip2 import GeoIP2
    except ImportError:
        return None
    try:
        geo = GeoIP2(path=path)
        data = geo.country(ip)
    except Exception:
        logger.debug('GeoIP lookup failed for %s', ip, exc_info=True)
        return None
    code = (data.get('country_code') if isinstance(data, dict) else None) or ''
    return active_country_by_iso2(code)


@lru_cache(maxsize=1)
def _timezone_to_iso2_map() -> dict[str, str]:
    """Load IANA zone → ISO2 from zone.tab (one country per zone)."""
    candidates: list[Path] = []
    custom = getattr(settings, 'TZ_ZONE_TAB_PATH', '') or ''
    if custom:
        candidates.append(Path(custom))
    candidates.extend(
        [
            Path('/usr/share/zoneinfo/zone.tab'),
            Path('/usr/share/zoneinfo/zone1970.tab'),
        ]
    )
    try:
        import tzdata  # type: ignore[import-untyped]

        pkg = Path(tzdata.__file__).resolve().parent
        candidates.append(pkg / 'zoneinfo' / 'zone.tab')
        candidates.append(pkg / 'zoneinfo' / 'zone1970.tab')
    except Exception:
        pass

    mapping: dict[str, str] = {}
    for path in candidates:
        if not path.is_file():
            continue
        try:
            text = path.read_text(encoding='utf-8')
        except OSError:
            continue
        for line in text.splitlines():
            line = line.strip()
            if not line or line.startswith('#'):
                continue
            parts = line.split('\t')
            if len(parts) < 3:
                continue
            countries = parts[0].split(',')
            # Ambiguous multi-country zones: skip (fall through to Accept-Language)
            if len(countries) != 1:
                continue
            iso2 = countries[0].strip().upper()
            zone = parts[2].strip()
            if _ISO2_RE.match(iso2) and zone and zone not in mapping:
                mapping[zone] = iso2
        if mapping:
            break
    return mapping


def iso2_from_timezone(timezone_name: str | None) -> str | None:
    if not timezone_name:
        return None
    zone = timezone_name.strip()
    if not zone or zone.startswith('Etc/'):
        return None
    return _timezone_to_iso2_map().get(zone)


def country_from_timezone(request: HttpRequest) -> Country | None:
    raw = (request.META.get(HEADER_TIMEZONE) or '').strip()
    return active_country_by_iso2(iso2_from_timezone(raw))


def iso2_from_accept_language(header: str | None) -> str | None:
    if not header:
        return None
    for part in header.split(','):
        tag = part.split(';')[0].strip().replace('_', '-')
        if not tag:
            continue
        segments = tag.split('-')
        for seg in reversed(segments[1:]):
            if len(seg) == 2 and seg.isalpha():
                return seg.upper()
    return None


def clear_timezone_map_cache() -> None:
    """Test helper — reset zone.tab cache after settings overrides."""
    _timezone_to_iso2_map.cache_clear()


def country_from_accept_language(request: HttpRequest) -> Country | None:
    header = request.META.get('HTTP_ACCEPT_LANGUAGE') or ''
    return active_country_by_iso2(iso2_from_accept_language(header))


def resolve_country(
    request: HttpRequest,
    *,
    ignore_x_country: bool = False,
) -> Country | None:
    """Resolve country per locked priority.

    X-Country → CDN → GeoIP → X-Timezone → Accept-Language → None
    """
    if not ignore_x_country:
        country = country_from_x_country(request)
        if country is not None:
            return country
    for resolver in (
        country_from_cdn,
        country_from_ip,
        country_from_timezone,
        country_from_accept_language,
    ):
        country = resolver(request)
        if country is not None:
            return country
    return None


def country_iso2(country: Country | None) -> str | None:
    if country is None:
        return None
    code = (getattr(country, 'iso_code2', None) or '').strip().upper()
    return code or None
