import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';
import 'package:vaxiil_mobile/core/di/injection_container.config.dart';

final GetIt sl = GetIt.instance;

@InjectableInit()
Future<void> configureDependencies() async {
  sl.init();
}
