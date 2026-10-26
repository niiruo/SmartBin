import 'package:flutter/material.dart';

import '../app_state.dart';
import '../db/repository.dart';
import 'widgets.dart';

final _app = AppState.instance;

bool _looksLikeEmail(String s) =>
    RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s);

// ------------------------------------------------------------------- Login

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = _email.text.trim();
    final pass = _password.text;
    if (email.isEmpty || pass.isEmpty) {
      snack(context, 'Please enter your email and password.');
      return;
    }
    setState(() => _busy = true);
    try {
      final user = await _app.repo.logIn(email, pass);
      await _app.setUser(user); // root widget switches to the dashboard
    } on AppException catch (e) {
      if (mounted) snack(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Login',
      titleSize: 30,
      children: [
        SbField(
          controller: _email,
          hint: 'Email:',
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 12),
        SbField(
          controller: _password,
          hint: 'Password:',
          obscure: true,
          textInputAction: TextInputAction.done,
          onSubmitted: _login,
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            SbLink('Forgot Password?',
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const ForgotScreen()))),
            SbLink('Sign up',
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const SignupDetailsScreen()))),
          ],
        ),
        const SizedBox(height: 28),
        SbButton(label: 'Login', onPressed: _login, loading: _busy),
        const SizedBox(height: 28),
        const Text('If you are creating a new account,\nTerms & Conditions and Privacy Policy will apply.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFFD0D0D3), fontSize: 11)),
      ],
    );
  }
}

// ------------------------------------------------------------ Sign up (1/2)

class SignupDetailsScreen extends StatefulWidget {
  const SignupDetailsScreen({super.key});
  @override
  State<SignupDetailsScreen> createState() => _SignupDetailsScreenState();
}

class _SignupDetailsScreenState extends State<SignupDetailsScreen> {
  final _first = TextEditingController();
  final _last = TextEditingController();

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    super.dispose();
  }

  void _continue() {
    final first = _first.text.trim();
    final last = _last.text.trim();
    if (first.isEmpty || last.isEmpty) {
      snack(context, 'Please enter your first and last name.');
      return;
    }
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => CreateAccountScreen(firstName: first, lastName: last)));
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Personal details',
      titleSize: 24,
      subtitle: 'Please fill in your details.',
      children: [
        SbField(
            controller: _first,
            hint: 'First name:',
            textInputAction: TextInputAction.next),
        const SizedBox(height: 12),
        SbField(
            controller: _last,
            hint: 'Last name:',
            textInputAction: TextInputAction.done,
            onSubmitted: _continue),
        const Padding(
          padding: EdgeInsets.fromLTRB(5, 10, 0, 18),
          child: Text('*Required information',
              style: TextStyle(color: Color(0xFFD0D0D3), fontSize: 11)),
        ),
        SbButton(label: 'Continue', onPressed: _continue),
        const SizedBox(height: 14),
        Center(child: SbLink('Back to Login', onTap: () => Navigator.pop(context))),
      ],
    );
  }
}

// ------------------------------------------------------------ Sign up (2/2)

class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen(
      {super.key, required this.firstName, required this.lastName});
  final String firstName;
  final String lastName;
  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final email = _email.text.trim();
    final pass = _password.text;
    if (!_looksLikeEmail(email)) {
      snack(context, 'Please enter a valid email address.');
      return;
    }
    if (pass.length < 6) {
      snack(context, 'Password must be at least 6 characters.');
      return;
    }
    setState(() => _busy = true);
    try {
      final user = await _app.repo.signUp(
        firstName: widget.firstName,
        lastName: widget.lastName,
        email: email,
        password: pass,
      );
      final nav = Navigator.of(context);
      await _app.setUser(user);
      nav.popUntil((r) => r.isFirst); // back to root -> dashboard
    } on AppException catch (e) {
      if (mounted) snack(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Create your account',
      titleSize: 22,
      subtitle: 'Please fill in your login details.',
      children: [
        SbField(
          controller: _email,
          hint: 'Email:',
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 12),
        SbField(
          controller: _password,
          hint: 'Password:',
          obscure: true,
          textInputAction: TextInputAction.done,
          onSubmitted: _create,
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(5, 10, 0, 18),
          child: Text('*Required information',
              style: TextStyle(color: Color(0xFFD0D0D3), fontSize: 11)),
        ),
        SbButton(label: 'Create account', onPressed: _create, loading: _busy),
        const SizedBox(height: 14),
        Center(child: SbLink('Go Back', onTap: () => Navigator.pop(context))),
      ],
    );
  }
}

// --------------------------------------------------------- Forgot password

/// Offline: no email can be sent, so the password is reset on this device.
class ForgotScreen extends StatefulWidget {
  const ForgotScreen({super.key});
  @override
  State<ForgotScreen> createState() => _ForgotScreenState();
}

class _ForgotScreenState extends State<ForgotScreen> {
  final _email = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _reset() async {
    final email = _email.text.trim();
    if (email.isEmpty || _new.text.isEmpty || _confirm.text.isEmpty) {
      snack(context, 'Please fill in every field.');
      return;
    }
    if (_new.text.length < 6) {
      snack(context, 'Password must be at least 6 characters.');
      return;
    }
    if (_new.text != _confirm.text) {
      snack(context, 'Passwords do not match.');
      return;
    }
    setState(() => _busy = true);
    try {
      await _app.repo.resetPasswordByEmail(email, _new.text);
      if (!mounted) return;
      snack(context, 'Password updated. You can log in now.');
      Navigator.pop(context);
    } on AppException catch (e) {
      if (mounted) snack(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Forgot your password?',
      titleSize: 20,
      subtitle: 'Enter your email and choose a new password.',
      children: [
        SbField(
            controller: _email,
            hint: 'Email:',
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next),
        const SizedBox(height: 12),
        SbField(
            controller: _new,
            hint: 'New Password:',
            obscure: true,
            textInputAction: TextInputAction.next),
        const SizedBox(height: 12),
        SbField(
            controller: _confirm,
            hint: 'Re-enter Password:',
            obscure: true,
            textInputAction: TextInputAction.done,
            onSubmitted: _reset),
        const SizedBox(height: 22),
        SbButton(label: 'Reset Password', onPressed: _reset, loading: _busy),
        const SizedBox(height: 14),
        Center(child: SbLink('Back to Login', onTap: () => Navigator.pop(context))),
      ],
    );
  }
}
