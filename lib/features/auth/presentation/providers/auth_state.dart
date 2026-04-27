import 'package:flutter/foundation.dart';

import '../../domain/entities/user.dart';

sealed class AuthState {
  const AuthState();
}

@immutable
class AuthInitial extends AuthState {
  const AuthInitial();
}

@immutable
class AuthAuthenticated extends AuthState {
  const AuthAuthenticated(this.user);
  final User user;
}

@immutable
class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated({this.errorMessage});
  final String? errorMessage;
}
