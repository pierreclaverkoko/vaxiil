import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:heroicons/heroicons.dart';
import 'package:vaxiil_mobile/core/constants/app_routes.dart';
import 'package:vaxiil_mobile/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:vaxiil_mobile/features/auth/presentation/cubit/auth_state.dart';
import 'package:vaxiil_mobile/shared/themes/app_theme.dart';
import 'package:vaxiil_mobile/shared/widgets/soft_card.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  var _obscure = true;
  final _googleSignIn = GoogleSignIn(scopes: ['email', 'openid']);

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthCubit, AuthState>(
      listenWhen: (p, c) => p.status != c.status || p.errorMessage != c.errorMessage,
      listener: (context, state) {
        if (state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.errorMessage!)),
          );
          context.read<AuthCubit>().clearError();
        }
      },
      child: Scaffold(
        body: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(24, 56, 24, 40),
                decoration: const BoxDecoration(
                  color: AppTheme.primaryVariant,
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(32),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    HeroIcon(
                      HeroIcons.sparkles,
                      style: HeroIconStyle.outline,
                      color: Colors.white,
                      size: 40,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Welcome back',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sign in to continue your wellness journey',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Colors.white70,
                          ),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.all(20),
              sliver: SliverToBoxAdapter(
                child: SoftCard(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            labelText: 'Email',
                            prefixIcon: Padding(
                              padding: const EdgeInsets.only(left: 12, right: 8),
                              child: HeroIcon(
                                HeroIcons.envelope,
                                style: HeroIconStyle.outline,
                                color: AppTheme.textSecondary,
                                size: 22,
                              ),
                            ),
                            prefixIconConstraints: const BoxConstraints(
                              minWidth: 40,
                              minHeight: 48,
                            ),
                          ),
                          validator: (v) {
                            if (v == null || !v.contains('@')) {
                              return 'Enter a valid email';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _password,
                          obscureText: _obscure,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: Padding(
                              padding: const EdgeInsets.only(left: 12, right: 8),
                              child: HeroIcon(
                                HeroIcons.lockClosed,
                                style: HeroIconStyle.outline,
                                color: AppTheme.textSecondary,
                                size: 22,
                              ),
                            ),
                            prefixIconConstraints: const BoxConstraints(
                              minWidth: 40,
                              minHeight: 48,
                            ),
                            suffixIcon: IconButton(
                              icon: HeroIcon(
                                _obscure
                                    ? HeroIcons.eye
                                    : HeroIcons.eyeSlash,
                                style: HeroIconStyle.outline,
                                color: AppTheme.textSecondary,
                                size: 22,
                              ),
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.length < 8) {
                              return 'At least 8 characters';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),
                        BlocBuilder<AuthCubit, AuthState>(
                          builder: (context, state) {
                            return FilledButton(
                              onPressed: state.isLoading
                                  ? null
                                  : () async {
                                      if (_formKey.currentState?.validate() !=
                                          true) {
                                        return;
                                      }
                                      await context.read<AuthCubit>().login(
                                            email: _email.text.trim(),
                                            password: _password.text,
                                          );
                                    },
                              child: state.isLoading
                                  ? const SizedBox(
                                      height: 22,
                                      width: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppTheme.onAccentCta,
                                      ),
                                    )
                                  : const Text('Sign in'),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: () async {
                            try {
                              final account = await _googleSignIn.signIn();
                              if (account == null) return;
                              final auth = await account.authentication;
                              final idToken = auth.idToken;
                              if (idToken == null) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Could not get Google ID token'),
                                    ),
                                  );
                                }
                                return;
                              }
                              await context.read<AuthCubit>().signInWithGoogle(idToken);
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(e.toString())),
                                );
                              }
                            }
                          },
                          icon: const Text('G', style: TextStyle(fontWeight: FontWeight.bold)),
                          label: const Text('Continue with Google'),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () => context.push(AppRoutes.register),
                          child: const Text('Create an account'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
