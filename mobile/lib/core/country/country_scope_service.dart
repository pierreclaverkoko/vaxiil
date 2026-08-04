import 'package:dio/dio.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:vaxiil_mobile/core/constants/app_constants.dart';
import 'package:vaxiil_mobile/core/network/dio_client.dart';
import 'package:vaxiil_mobile/core/storage/secure_storage_service.dart';
import 'package:vaxiil_mobile/features/business/data/organization_models.dart';

/// Shared consumer country filter: storage + headers + geo-country bootstrap.
class CountryScopeService {
  CountryScopeService({required SecureStorageService storage})
      : _storage = storage;

  final SecureStorageService _storage;
  DioClient? _dioClient;
  String _timezone = '';
  CountryBriefModel? _country;
  List<CountryBriefModel> _countries = [];
  Future<void>? _initPromise;

  CountryBriefModel? get country => _country;
  String? get countryId => _country?.id;
  String get isoCode2 => (_country?.isoCode2 ?? '').trim().toUpperCase();
  String get timezone => _timezone;
  List<CountryBriefModel> get countries => List.unmodifiable(_countries);

  void attachDio(DioClient client) {
    _dioClient = client;
  }

  Future<void> ensureTimezone() async {
    if (_timezone.isNotEmpty) return;
    try {
      _timezone = await FlutterTimezone.getLocalTimezone();
    } catch (_) {
      _timezone = '';
    }
  }

  Future<void> setCountry(CountryBriefModel country) async {
    _country = country;
    await _storage.writeMap(AppConstants.countryScopeStorageKey, {
      'id': country.id,
      'iso_code2': country.isoCode2.toUpperCase(),
      'name': country.name,
    });
  }

  Future<void> setCountryById(String countryId) async {
    for (final c in _countries) {
      if (c.id == countryId) {
        await setCountry(c);
        return;
      }
    }
  }

  void rememberCountries(List<CountryBriefModel> countries) {
    _countries = countries;
  }

  Future<void> ensureInitialized({
    List<CountryBriefModel> countries = const [],
    String? profileDefaultCountryId,
  }) {
    if (countries.isNotEmpty) {
      rememberCountries(countries);
    }
    return _initPromise ??= _bootstrap(
      profileDefaultCountryId: profileDefaultCountryId,
    );
  }

  void hydrateFromResolvedIso2(String? iso2) {
    if (_country != null || iso2 == null) return;
    final code = iso2.trim().toUpperCase();
    if (code.length != 2) return;
    for (final c in _countries) {
      if (c.isoCode2.toUpperCase() == code) {
        // ignore: discarded_futures
        setCountry(c);
        return;
      }
    }
  }

  Future<void> _bootstrap({String? profileDefaultCountryId}) async {
    await ensureTimezone();
    final stored = await _readStored();
    if (stored != null) {
      if (_countries.isNotEmpty) {
        for (final c in _countries) {
          if (c.id == stored.id ||
              c.isoCode2.toUpperCase() == stored.isoCode2.toUpperCase()) {
            await setCountry(c);
            return;
          }
        }
      }
      _country = stored;
      return;
    }

    if (profileDefaultCountryId != null && _countries.isNotEmpty) {
      for (final c in _countries) {
        if (c.id == profileDefaultCountryId) {
          await setCountry(c);
          return;
        }
      }
    }

    final detected = await _fetchGeoCountry();
    if (detected != null) {
      await setCountry(detected);
      return;
    }

    if (_countries.isNotEmpty) {
      await setCountry(_countries.first);
    }
  }

  Future<CountryBriefModel?> _fetchGeoCountry() async {
    final dio = _dioClient;
    if (dio == null) return null;
    try {
      await ensureTimezone();
      final response = await dio.get<dynamic>(
        AppConstants.organizationsGeoCountryPath,
        options: Options(
          headers: {
            if (_timezone.isNotEmpty) 'X-Timezone': _timezone,
          },
          validateStatus: (code) =>
              code != null && (code == 200 || code == 204),
        ),
      );
      final resolved = response.headers.value('x-resolved-country') ??
          response.headers.value('X-Resolved-Country');
      if (response.statusCode == 204 || response.data == null) {
        hydrateFromResolvedIso2(resolved);
        return null;
      }
      if (response.data is Map) {
        final country = CountryBriefModel.fromJson(
          Map<String, dynamic>.from(response.data as Map),
        );
        hydrateFromResolvedIso2(resolved);
        return country;
      }
    } catch (_) {}
    return null;
  }

  Future<CountryBriefModel?> _readStored() async {
    try {
      final map = await _storage.readMap(AppConstants.countryScopeStorageKey);
      if (map == null) return null;
      final id = map['id']?.toString() ?? '';
      final iso = map['iso_code2']?.toString() ?? '';
      if (id.isEmpty || iso.isEmpty) return null;
      return CountryBriefModel(
        id: id,
        isoCode2: iso.toUpperCase(),
        name: map['name']?.toString() ?? '',
      );
    } catch (_) {
      return null;
    }
  }
}
