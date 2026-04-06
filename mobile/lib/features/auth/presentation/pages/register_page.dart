import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:heroicons/heroicons.dart';
import 'package:vaxiil_mobile/core/constants/app_routes.dart';
import 'package:vaxiil_mobile/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:vaxiil_mobile/features/auth/presentation/cubit/auth_state.dart';
import 'package:vaxiil_mobile/shared/themes/app_theme.dart';
import 'package:vaxiil_mobile/shared/widgets/soft_card.dart';
import 'package:vaxiil_mobile/shared/widgets/vaxiil_logo.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _username = TextEditingController();
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  var _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _username.dispose();
    _first.dispose();
    _last.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthCubit, AuthState>(
      listenWhen: (p, c) => p.errorMessage != c.errorMessage,
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
                padding: EdgeInsets.fromLTRB(
                  4,
                  MediaQuery.paddingOf(context).top + 8,
                  24,
                  40,
                ),
                decoration: const BoxDecoration(
                  gradient: AppTheme.splashVerticalGradient,
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(32),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IconButton(
                      icon: const HeroIcon(
                        HeroIcons.arrowLeft,
                        style: HeroIconStyle.outline,
                        color: Colors.white,
                      ),
                      onPressed: () => context.go(AppRoutes.login),
                    ),
                    const Center(child: VaxiilLogo(height: 56)),
                    const SizedBox(height: 16),
                    Text(
                      'Create account',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Join Vaxiil and book wellness services with confidence',
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
                                color: Theme.of(context).colorScheme.outline,
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
                              return 'Valid email required';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _username,
                          decoration: const InputDecoration(
                            labelText: 'Username',
                          ),
                          validator: (v) {
                            if (v == null || v.trim().length < 3) {
                              return 'At least 3 characters';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _first,
                          decoration: const InputDecoration(
                            labelText: 'First name',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _last,
                          decoration: const InputDecoration(
                            labelText: 'Last name',
                          ),
                        ),
                        const SizedBox(height: 12),
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
                                color: Theme.of(context).colorScheme.outline,
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
                                color: Theme.of(context).colorScheme.outline,
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
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _confirm,
                          obscureText: _obscure,
                          decoration: const InputDecoration(
                            labelText: 'Confirm password',
                          ),
                          validator: (v) {
                            if (v != _password.text) {
                              return 'Passwords must match';
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
                                      await context.read<AuthCubit>().register(
                                            email: _email.text.trim(),
                                            username: _username.text.trim(),
                                            password: _password.text,
                                            passwordConfirm: _confirm.text,
                                            firstName: _first.text.trim(),
                                            lastName: _last.text.trim(),
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
                                  : const Text('Register'),
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () => context.go(AppRoutes.login),
                          child: const Text('Already have an account? Sign in'),
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
