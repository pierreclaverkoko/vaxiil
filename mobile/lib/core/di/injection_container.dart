import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';
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
  sl.registerSingleton<DioClient>(
    DioClient(secureStorage: sl<SecureStorageService>()),
  );
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
  sl.init();
}
