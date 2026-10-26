import 'package:flutter/material.dart';

import '../app_state.dart';
import '../db/repository.dart';
import '../theme.dart';
import 'widgets.dart';

AppState get _app => AppState.instance;

// ----------------------------------------------------------------- Profile

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  void _push(BuildContext c, Widget w) =>
      Navigator.push(c, MaterialPageRoute(builder: (_) => w));

  Future<void> _confirmLogout(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Are you sure you want to log out?',
            style: TextStyle(
                color: Color(0xFF111111),
                fontSize: 15,
                fontWeight: FontWeight.bold)),
        content: const Text(
            'If you log out now, you will not be able to use deals or rewards.',
            style: TextStyle(color: Color(0xFF666666), fontSize: 12)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel',
                  style: TextStyle(color: Color(0xFF666666)))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Log out', style: TextStyle(color: SB.red))),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final nav = Navigator.of(context);
    await _app.logOut();
    nav.popUntil((r) => r.isFirst); // root now shows the login screen
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SB.bg,
      body: ListenableBuilder(
        listenable: _app,
        builder: (context, _) {
          final u = _app.user;
          if (u == null) return const SizedBox.shrink();
          return ListView(
            padding: EdgeInsets.zero,
            children: [
              Stack(children: [
                Container(height: 125, width: double.infinity, color: SB.cover),
                Positioned(
                  top: 0,
                  left: 0,
                  child: SafeArea(
                    child: TextButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.chevron_left, color: Color(0xFFE8E8E8)),
                      label: const Text('Dashboard',
                          style: TextStyle(
                              color: Color(0xFFE8E8E8),
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 91),
                  child: Center(
                    child: GestureDetector(
                      onTap: () => _push(context, const EditProfileScreen()),
                      child: SizedBox(
                        width: 68,
                        height: 68,
                        child: Stack(children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: SB.panel,
                              border: Border.all(color: SB.bg, width: 3),
                            ),
                            child: const ClipOval(
                              child: SbImage(kProfileAsset,
                                  size: 62, fallback: Icons.person),
                            ),
                          ),
                          const Positioned(
                            right: 0,
                            bottom: 0,
                            child: CircleAvatar(
                              radius: 11,
                              backgroundColor: SB.text,
                              child: Icon(Icons.edit,
                                  size: 12, color: Color(0xFF222222)),
                            ),
                          ),
                        ]),
                      ),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              Center(
                  child: Text(u.fullName.isEmpty ? 'Smart Bin User' : u.fullName,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold))),
              const SizedBox(height: 2),
              Center(
                  child: Text(u.email,
                      style: const TextStyle(fontSize: 12, color: SB.muted))),
              const SizedBox(height: 26),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 25),
                child: Row(children: [
                  SbLogo(18),
                  SizedBox(width: 6),
                  Text('Account',
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                ]),
              ),
              const SizedBox(height: 6),
              _row(context, 'Personal details',
                  () => _push(context, const PersonalDetailsScreen())),
              _row(context, 'Password & Security',
                  () => _push(context, const ChangePasswordScreen())),
              _row(context, 'Log out', () => _confirmLogout(context),
                  color: SB.red),
              _row(context, 'Delete account',
                  () => _push(context, const DeleteAccountScreen()),
                  color: SB.red),
            ],
          );
        },
      ),
    );
  }

  Widget _row(BuildContext context, String label, VoidCallback onTap,
      {Color color = SB.text}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 48,
        margin: const EdgeInsets.symmetric(horizontal: 25),
        decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: SB.border))),
        child: Row(children: [
          Expanded(
              child: Text(label, style: TextStyle(fontSize: 14, color: color))),
          const Icon(Icons.chevron_right, color: SB.muted),
        ]),
      ),
    );
  }
}

// -------------------------------------------------------- Personal details

class PersonalDetailsScreen extends StatelessWidget {
  const PersonalDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _app,
      builder: (context, _) {
        final u = _app.user;
        if (u == null) return const SizedBox.shrink();
        String v(String s) => s.isEmpty ? 'Not provided' : s;
        return AuthScaffold(
          title: 'Personal details',
          titleSize: 22,
          panelHeight: 220,
          children: [
            _line('First name:', v(u.firstName)),
            _line('Last name:', v(u.lastName)),
            _line('Email address:', v(u.email)),
            _line('Phone number:', v(u.phone)),
            const SizedBox(height: 18),
            SbButton(
              label: 'Edit profile',
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const EditProfileScreen())),
            ),
            const SizedBox(height: 14),
            Center(child: SbLink('Go Back', onTap: () => Navigator.pop(context))),
          ],
        );
      },
    );
  }

  Widget _line(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text('$label $value', style: const TextStyle(fontSize: 14)),
      );
}

// ------------------------------------------------------------ Edit profile

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});
  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final _first = TextEditingController(text: _app.user?.firstName);
  late final _last = TextEditingController(text: _app.user?.lastName);
  late final _phone = TextEditingController(text: _app.user?.phone);
  bool _busy = false;

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_first.text.trim().isEmpty || _last.text.trim().isEmpty) {
      snack(context, 'First and last name are required.');
      return;
    }
    setState(() => _busy = true);
    try {
      final updated = await _app.repo.updateProfile(
        userId: _app.user!.id,
        firstName: _first.text,
        lastName: _last.text,
        phone: _phone.text,
      );
      await _app.setUser(updated);
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = _app.user?.email ?? '';
    return AuthScaffold(
      title: 'Personal details',
      titleSize: 22,
      panelHeight: 220,
      children: [
        SbField(controller: _first, hint: 'First name:', compact: true),
        const SizedBox(height: 12),
        SbField(controller: _last, hint: 'Last name:', compact: true),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: SB.border),
          ),
          child: Text('Email:  $email',
              style: const TextStyle(color: SB.muted, fontSize: 15)),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(4, 4, 0, 8),
          child: Text('*email address cannot be changed',
              style: TextStyle(fontSize: 10, color: SB.muted)),
        ),
        SbField(
            controller: _phone,
            hint: 'Phone number:',
            compact: true,
            keyboardType: TextInputType.phone),
        const SizedBox(height: 22),
        Row(children: [
          Expanded(
            child: SbButton(
                label: 'Cancel',
                height: 46,
                color: const Color(0xFF8A8A8A),
                onPressed: () => Navigator.pop(context)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SbButton(
                label: 'Save Changes',
                height: 46,
                loading: _busy,
                onPressed: _save),
          ),
        ]),
      ],
    );
  }
}

// --------------------------------------------------------- Change password

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});
  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _reset() async {
    if (_new.text.isEmpty || _confirm.text.isEmpty) {
      snack(context, 'Please fill in both password fields.');
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
      await _app.repo.changePassword(_app.user!.id, _new.text);
      if (!mounted) return;
      snack(context, 'Password changed successfully.');
      Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Change password',
      titleSize: 22,
      children: [
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
        Center(child: SbLink('Go Back', onTap: () => Navigator.pop(context))),
      ],
    );
  }
}

// ---------------------------------------------------------- Delete account

class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});
  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  final _password = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    if (_password.text.isEmpty) {
      snack(context, 'Enter your password to confirm.');
      return;
    }
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await _app.repo
          .deleteAccount(userId: _app.user!.id, password: _password.text);
      await _app.logOut(); // root switches to the login screen
      nav.popUntil((r) => r.isFirst);
      messenger.showSnackBar(
          const SnackBar(content: Text('Your account has been deleted.')));
    } on AppException catch (e) {
      if (mounted) snack(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Delete account',
      titleSize: 22,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: SB.red.withAlpha(180)),
          ),
          child: const Text(
            'This permanently deletes your account, your points, your coupons '
            'and your activity from this phone. It cannot be undone.',
            style: TextStyle(fontSize: 13, color: SB.muted),
          ),
        ),
        const SizedBox(height: 18),
        SbField(
          controller: _password,
          hint: 'Enter your password:',
          obscure: true,
          textInputAction: TextInputAction.done,
          onSubmitted: _delete,
        ),
        const SizedBox(height: 22),
        SbButton(
            label: 'Delete my account',
            color: SB.red,
            onPressed: _delete,
            loading: _busy),
        const SizedBox(height: 14),
        Center(child: SbLink('Cancel', onTap: () => Navigator.pop(context))),
      ],
    );
  }
}
