import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:vaxiil_mobile/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:vaxiil_mobile/features/auth/presentation/cubit/auth_state.dart';

/// Notifies [GoRouter] when [AuthCubit] state changes so redirects re-run.
class GoRouterRefresh extends ChangeNotifier {
  GoRouterRefresh(AuthCubit authCubit) {
    _sub = authCubit.stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<AuthState> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
