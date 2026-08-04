import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';
import 'package:vaxiil_mobile/core/country/country_scope_service.dart';
import 'package:vaxiil_mobile/core/di/injection_container.config.dart';
import 'package:vaxiil_mobile/core/network/dio_client.dart';
import 'package:vaxiil_mobile/core/storage/secure_storage_service.dart';
import 'package:vaxiil_mobile/features/auth/data/auth_repository.dart';
import 'package:vaxiil_mobile/features/auth/data/legal_repository.dart';
import 'package:vaxiil_mobile/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:vaxiil_mobile/features/bookings/data/bookings_repository.dart';
import 'package:vaxiil_mobile/features/business/data/organization_repository.dart';
import 'package:vaxiil_mobile/features/business/data/provider_services_repository.dart';
import 'package:vaxiil_mobile/features/notifications/data/notifications_repository.dart';
import 'package:vaxiil_mobile/features/messages/data/messaging_repository.dart';
import 'package:vaxiil_mobile/features/services/data/service_catalog_repository.dart';

final GetIt sl = GetIt.instance;

@InjectableInit()
Future<void> configureDependencies() async {
  sl.registerSingleton<SecureStorageService>(SecureStorageService());
  final countryScope = CountryScopeService(storage: sl<SecureStorageService>());
  sl.registerSingleton<CountryScopeService>(countryScope);
  await countryScope.ensureTimezone();
  final dioClient = DioClient(
    secureStorage: sl<SecureStorageService>(),
    countryScope: countryScope,
  );
  countryScope.attachDio(dioClient);
  sl.registerSingleton<DioClient>(dioClient);
  sl.registerSingleton<AuthRepository>(
    AuthRepository(
      dioClient: sl<DioClient>(),
      storage: sl<SecureStorageService>(),
    ),
  );
  sl.registerSingleton<LegalRepository>(
    LegalRepository(dioClient: sl<DioClient>()),
  );
  sl.registerSingleton<OrganizationRepository>(
    OrganizationRepository(dioClient: sl<DioClient>()),
  );
  sl.registerSingleton<ServiceCatalogRepository>(
    ServiceCatalogRepository(dioClient: sl<DioClient>()),
  );
  sl.registerSingleton<ProviderServicesRepository>(
    ProviderServicesRepository(dioClient: sl<DioClient>()),
  );
  sl.registerSingleton<BookingsRepository>(
    BookingsRepository(dioClient: sl<DioClient>()),
  );
  sl.registerSingleton<NotificationsRepository>(
    NotificationsRepository(dioClient: sl<DioClient>()),
  );
  sl.registerSingleton<MessagingRepository>(
    MessagingRepository(dioClient: sl<DioClient>()),
  );
  sl.registerSingleton<AuthCubit>(AuthCubit(sl<AuthRepository>()));
  sl<DioClient>().onSessionExpired = () {
    sl<AuthCubit>().forceLocalLogout();
  };
  sl.init();
}
