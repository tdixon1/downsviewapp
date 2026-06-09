import 'package:flutter/material.dart';

import '../services/supabase_service.dart';
import '../theme.dart';
import '../widgets/parity_widgets.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.onContinueAsGuest});

  final VoidCallback onContinueAsGuest;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  bool _isLogin = true;
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _loading = true);
    try {
      if (_isLogin) {
        await supabase.auth.signInWithPassword(
          email: _email.text.trim(),
          password: _password.text,
        );
      } else {
        await supabase.auth.signUp(
          email: _email.text.trim(),
          password: _password.text,
          data: {'full_name': _name.text.trim()},
          emailRedirectTo: 'https://downsviewsda.org/verified/',
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Account created. Please verify your email before signing in. '
                'If you do not see it, check your junk or spam folder.',
              ),
            ),
          );
          setState(() => _isLogin = true);
        }
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.authBackground,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.navy,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Image.asset('assets/downsview-logo-white.png', width: 230),
                  const SizedBox(height: 24),
                  Text(
                    _isLogin ? 'Welcome home' : 'Create your account',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _isLogin
                        ? 'Sign in to stay connected with your church community.'
                        : 'Join the app for attendance, appeals, and church updates.',
                    style:
                        const TextStyle(color: Color(0xFFD8E2EF), fontSize: 16),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ParityPanel(
              radius: AppRadii.panel,
              padding: const EdgeInsets.all(20),
              child: Padding(
                padding: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!_isLogin) ...[
                      TextField(
                        controller: _name,
                        decoration:
                            const InputDecoration(labelText: 'Full Name'),
                        textCapitalization: TextCapitalization.words,
                      ),
                      const SizedBox(height: 14),
                    ],
                    TextField(
                      controller: _email,
                      decoration:
                          const InputDecoration(labelText: 'Email Address'),
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _password,
                      decoration: const InputDecoration(labelText: 'Password'),
                      obscureText: true,
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      height: 54,
                      child: FilledButton(
                        onPressed: _loading ? null : _submit,
                        child: _loading
                            ? const SizedBox.square(
                                dimension: 22,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(_isLogin ? 'Sign In' : 'Create Account'),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _isLogin
                              ? "Don't have an account?"
                              : 'Already have an account?',
                          style: const TextStyle(
                              color: AppColors.muted, fontSize: 14),
                        ),
                        TextButton(
                          onPressed: () => setState(() => _isLogin = !_isLogin),
                          style: TextButton.styleFrom(
                            minimumSize: Size.zero,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 4),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            _isLogin ? 'Sign Up' : 'Sign In',
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 28),
                    SizedBox(
                      height: 52,
                      child: OutlinedButton(
                        onPressed: widget.onContinueAsGuest,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.text,
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadii.input),
                          ),
                          textStyle:
                              const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        child: const Text('Continue as Guest'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Browse sermons, events, bulletins, and appeals. Create an account later for saved notes, profile details, and member features.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.muted, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
