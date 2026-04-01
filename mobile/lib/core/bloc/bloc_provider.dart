import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vaxiil_mobile/core/di/injection_container.dart';

// Extension on BuildContext to easily provide and access BLoCs
extension BlocProviderExtension on BuildContext {
  // Provide a BLoC instance
  Widget provideBloc<B extends BlocBase<dynamic>>(B bloc) {
    return BlocProvider<B>.value(
      value: bloc,
      child: this,
    );
  }
  
  // Access a BLoC instance
  B readBloc<B extends BlocBase<dynamic>>() {
    return read<B>();
  }
  
  // Access a BLoC instance (null-safe)
  B? readBlocOrNull<B extends BlocBase<dynamic>>() {
    return read<B?>();
  }
  
  // Access a BLoC instance from service locator
  B getBloc<B extends BlocBase<dynamic>>() {
    return sl<B>();
  }
  
  // Watch a BLoC instance
  B watchBloc<B extends BlocBase<dynamic>>() {
    return watch<B>();
  }
  
  // Select a value from a BLoC
  T selectBloc<B extends BlocBase<dynamic>, T>(T Function(B bloc) selector) {
    return select<B, T>(selector);
  }
}

// Multi BLoC provider helper
class MultiBlocProviderHelper {
  static Widget withBlocs({
    required Widget child,
    required List<BlocProvider> blocs,
  }) {
    return MultiBlocProvider(
      providers: blocs,
      child: child,
    );
  }
  
  static Widget withRepositoryProviders({
    required Widget child,
    required List<RepositoryProvider> repositories,
  }) {
    return MultiRepositoryProvider(
      providers: repositories,
      child: child,
    );
  }
  
  static Widget withAll({
    required Widget child,
    required List<BlocProvider> blocs,
    required List<RepositoryProvider> repositories,
  }) {
    return MultiRepositoryProvider(
      providers: repositories,
      child: MultiBlocProvider(
        providers: blocs,
        child: child,
      ),
    );
  }
}

// BLoC listener helper
class BlocListenerHelper {
  static Widget listen<B extends BlocBase<dynamic>, S>({
    required B bloc,
    required Widget Function(BuildContext context, S state) builder,
    required void Function(BuildContext context, S state) listener,
    bool listenWhen = true,
  }) {
    return BlocListener<B, S>(
      bloc: bloc,
      listener: listener,
      listenWhen: listenWhen,
      child: builder,
    );
  }
  
  static Widget consume<B extends BlocBase<dynamic>, S>({
    required B bloc,
    required Widget Function(BuildContext context, S state) builder,
    required Widget Function(BuildContext context, S state) listener,
  }) {
    return BlocConsumer<B, S>(
      bloc: bloc,
      builder: builder,
      listener: listener,
    );
  }
}
