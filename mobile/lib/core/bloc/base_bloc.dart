import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vaxiil_mobile/core/errors/failures.dart';

// Base event class
abstract class BaseEvent extends Equatable {
  const BaseEvent();
  
  @override
  List<Object> get props => [];
}

// Base state class
abstract class BaseState extends Equatable {
  const BaseState();
  
  @override
  List<Object> get props => [];
}

// Initial state
class InitialState extends BaseState {}

// Loading state
class LoadingState extends BaseState {}

// Success state
class SuccessState extends BaseState {
  
  const SuccessState({this.message});
  final String? message;
  
  @override
  List<Object?> get props => [message];
}

// Error state
class ErrorState extends BaseState {
  
  const ErrorState(this.failure, {this.message});
  final Failure failure;
  final String? message;
  
  @override
  List<Object?> get props => [failure, message];
  
  @override
  String toString() => 'ErrorState(failure: $failure, message: $message)';
}

// Base BLoC class
abstract class BaseBloc<Event extends BaseEvent, State extends BaseState> 
    extends Bloc<Event, State> {
  BaseBloc(super.initialState);
  
  void emitLoading() => emit(LoadingState() as State);
  
  void emitSuccess([String? message]) => emit(SuccessState(message: message) as State);
  
  void emitError(Failure failure, [String? message]) => 
      emit(ErrorState(failure, message: message) as State);
}

// Generic BLoC for simple operations
class GenericBloc<Event extends BaseEvent, State extends BaseState> 
    extends BaseBloc<Event, State> {
  GenericBloc(super.initialState);
}
