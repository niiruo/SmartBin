import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';

const String kLogoAsset = 'assets/smartbin_logo.png';
const String kProfileAsset = 'assets/profile.png';

/// Shows an asset image, or an icon if the file isn't bundled yet.
class SbImage extends StatelessWidget {
  const SbImage(this.asset,
      {super.key, required this.size, required this.fallback});
  final String asset;
  final double size;
  final IconData fallback;

  @override
  Widget build(BuildContext context) => Image.asset(
        asset,
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) =>
            Icon(fallback, size: size, color: SB.text),
      );
}

class SbLogo extends StatelessWidget {
  const SbLogo(this.size, {super.key});
  final double size;
  @override
  Widget build(BuildContext context) =>
      SbImage(kLogoAsset, size: size, fallback: Icons.delete_outline);
}

class SbField extends StatelessWidget {
  const SbField({
    super.key,
    required this.controller,
    required this.hint,
    this.obscure = false,
    this.keyboardType,
    this.inputFormatters,
    this.textInputAction,
    this.onSubmitted,
    this.compact = false,
  });

  final TextEditingController controller;
  final String hint;
  final bool obscure;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final TextInputAction? textInputAction;
  final VoidCallback? onSubmitted;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(15),
      borderSide: const BorderSide(color: SB.border),
    );
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted == null ? null : (_) => onSubmitted!(),
      style: const TextStyle(color: SB.text, fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: SB.muted, fontSize: 15),
        filled: true,
        fillColor: SB.bg,
        isDense: true,
        contentPadding:
            EdgeInsets.symmetric(horizontal: 16, vertical: compact ? 14 : 18),
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
            borderSide: const BorderSide(color: SB.blue, width: 1.5)),
      ),
    );
  }
}

class SbButton extends StatelessWidget {
  const SbButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.color = SB.blue,
    this.height = 53,
    this.radius = 14,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final double height;
  final double radius;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: color,
          disabledBackgroundColor: color.withAlpha(150),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
            side: const BorderSide(color: SB.border),
          ),
        ),
        onPressed: loading ? null : onPressed,
        child: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(label,
                    maxLines: 1,
                    softWrap: false,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold)),
              ),
      ),
    );
  }
}

class SbLink extends StatelessWidget {
  const SbLink(this.label, {super.key, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: Text(label,
              style: const TextStyle(
                  color: SB.text,
                  fontSize: 13,
                  decoration: TextDecoration.underline,
                  decorationColor: SB.text)),
        ),
      );
}

/// Login / sign-up style page: rounded brand panel on top, form below.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.children,
    this.subtitle,
    this.titleSize = 28,
    this.panelHeight = 250,
    this.showBack = false,
  });

  final String title;
  final String? subtitle;
  final double titleSize;
  final double panelHeight;
  final bool showBack;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SB.bg,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          child: Column(
            children: [
              Container(
                height: panelHeight,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: SB.bg,
                  border: Border.all(color: SB.border),
                  borderRadius:
                      const BorderRadius.vertical(bottom: Radius.circular(22)),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      SbLogo(88),
                      SizedBox(height: 14),
                      Text('Smart Bin',
                          style: TextStyle(color: SB.text, fontSize: 18)),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(40, 28, 40, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(title,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: SB.text,
                            fontSize: titleSize,
                            fontWeight: FontWeight.bold)),
                    if (subtitle != null) ...[
                      const SizedBox(height: 8),
                      Text(subtitle!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: SB.muted, fontSize: 13)),
                    ],
                    const SizedBox(height: 22),
                    ...children,
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void snack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

Future<void> showSbMessage(BuildContext context, String title, String message) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: SB.container,
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
      ],
    ),
  );
}

String formatDate(DateTime d) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.year}-${two(d.month)}-${two(d.day)}  ${two(d.hour)}:${two(d.minute)}';
}
