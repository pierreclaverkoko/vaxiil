import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:vaxiil_mobile/core/di/injection_container.dart';

// Extension on BuildContext to easily provide and access BLoCs
extension BlocProviderExtension on BuildContext {
  /// Wraps [child] with [BlocProvider.value] for an existing [bloc].
  Widget provideBloc<B extends BlocBase<Object?>>({
    required Widget child,
    required B bloc,
  }) {
    return BlocProvider<B>.value(
      value: bloc,
      child: child,
    );
  }

  /// Access a BLoC instance
  B readBloc<B extends BlocBase<Object?>>() {
    return read<B>();
  }

  /// Access a BLoC instance if present in the tree
  B? readBlocOrNull<B extends BlocBase<Object?>>() {
    try {
      return Provider.of<B>(this, listen: false);
    } on ProviderNotFoundException {
      return null;
    }
  }

  /// Access a BLoC instance from service locator
  B getBloc<B extends BlocBase<Object?>>() {
    return sl<B>();
  }

  /// Watch a BLoC instance
  B watchBloc<B extends BlocBase<Object?>>() {
    return watch<B>();
  }

  /// Select a value from a BLoC
  T selectBloc<B extends BlocBase<Object?>, T>(T Function(B bloc) selector) {
    return select<B, T>(selector);
  }
}

// Multi BLoC provider helper
class MultiBlocProviderHelper {
  static Widget withBlocs({
    required Widget child,
    required List<SingleChildWidget> blocs,
  }) {
    return MultiBlocProvider(
      providers: blocs,
      child: child,
    );
  }

  static Widget withRepositoryProviders({
    required Widget child,
    required List<SingleChildWidget> repositories,
  }) {
    return MultiRepositoryProvider(
      providers: repositories,
      child: child,
    );
  }

  static Widget withAll({
    required Widget child,
    required List<SingleChildWidget> blocs,
    required List<SingleChildWidget> repositories,
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
  static Widget listen<B extends StateStreamable<S>, S>({
    required B bloc,
    required Widget child,
    required void Function(BuildContext context, S state) listener,
    BlocListenerCondition<S>? listenWhen,
  }) {
    return BlocListener<B, S>(
      bloc: bloc,
      listenWhen: listenWhen,
      listener: listener,
      child: child,
    );
  }

  static Widget consume<B extends StateStreamable<S>, S>({
    required B bloc,
    required Widget Function(BuildContext context, S state) builder,
    required void Function(BuildContext context, S state) listener,
    BlocListenerCondition<S>? listenWhen,
  }) {
    return BlocConsumer<B, S>(
      bloc: bloc,
      listenWhen: listenWhen,
      builder: builder,
      listener: listener,
    );
  }
}
