import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_state.dart';
import '../config.dart';
import '../db/repository.dart';
import '../theme.dart';
import 'profile_screens.dart';
import 'widgets.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _code = TextEditingController();
  bool _busy = false;
  AppState get _app => AppState.instance;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  /// The user types the code shown on the bin's OLED -> verify -> save.
  Future<void> _redeem() async {
    final raw = _code.text.trim();
    if (raw.isEmpty) {
      snack(context, 'Please enter a code.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    try {
      final r = await _app.repo.redeemCode(userId: _app.user!.id, raw: raw);
      await _app.refresh();
      _code.clear();
      if (mounted) {
        await showSbMessage(
          context,
          '+${r.points} points',
          '${r.items} item${r.items == 1 ? '' : 's'} recycled.\nNew balance: ${r.balance} points.',
        );
      }
    } on AppException catch (e) {
      if (mounted) snack(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _getCoupon(int cost) async {
    try {
      final code = await _app.repo.buyCoupon(userId: _app.user!.id, cost: cost);
      await _app.refresh();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: SB.container,
          title: const Text('Coupon Generated'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Your coupon code is:'),
              const SizedBox(height: 10),
              SelectableText(code,
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5)),
              const SizedBox(height: 10),
              Text('Remaining points: ${_app.points}',
                  style: const TextStyle(color: SB.muted)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Clipboard.setData(ClipboardData(text: code)),
              child: const Text('Copy'),
            ),
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
          ],
        ),
      );
    } on AppException catch (e) {
      if (mounted) snack(context, e.message);
    }
  }

  void _openProfile() => Navigator.push(
      context, MaterialPageRoute(builder: (_) => const ProfileScreen()));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SB.bg,
      appBar: AppBar(
        backgroundColor: SB.bg,
        surfaceTintColor: Colors.transparent,
        shape: const Border(bottom: BorderSide(color: SB.border)),
        titleSpacing: 18,
        title: const Row(children: [
          SbLogo(24),
          SizedBox(width: 8),
          Text('Smart Bin',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        ]),
        actions: [
          IconButton(
            onPressed: _openProfile,
            icon: const CircleAvatar(
              radius: 14,
              backgroundColor: SB.cover,
              child: ClipOval(
                child: SbImage(kProfileAsset,
                    size: 28, fallback: Icons.person),
              ),
            ),
          ),
        ],
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusScope.of(context).unfocus(),
        child: ListenableBuilder(
          listenable: _app,
          builder: (context, _) => ListView(
            padding: const EdgeInsets.all(15),
            children: [
              _pointsCard(),
              const SizedBox(height: 15),
              _couponsCard(),
              const SizedBox(height: 15),
              _codeCard(),
              const SizedBox(height: 22),
              _activity(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pointsCard() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
            color: SB.cover, borderRadius: BorderRadius.circular(18)),
        child: Row(children: [
          const SbLogo(30),
          const SizedBox(width: 14),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${_app.points}',
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const Text('Available Points',
                style: TextStyle(fontSize: 11, color: Color(0xFFE5E5E5))),
          ]),
        ]),
      );

  Widget _couponsCard() => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: SB.container,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: SB.border),
        ),
        child: Column(children: [
          for (final cost in kCouponCosts) ...[
            _couponRow(cost),
            if (cost != kCouponCosts.last) const SizedBox(height: 12),
          ],
        ]),
      );

  Widget _couponRow(int cost) => Container(
        height: 52,
        padding: const EdgeInsets.only(left: 16, right: 12),
        decoration: BoxDecoration(
            color: SB.black, borderRadius: BorderRadius.circular(14)),
        child: Row(children: [
          Text('$cost',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(width: 14),
          const Expanded(
              child: Text('GET COUPON',
                  style: TextStyle(fontSize: 11, color: SB.muted))),
          SizedBox(
            width: 64,
            child: SbButton(
                label: 'GET',
                height: 30,
                radius: 10,
                onPressed: () => _getCoupon(cost)),
          ),
        ]),
      );

  Widget _codeCard() => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: SB.container,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: SB.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Code',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('Enter the 8 digits shown on the bin screen.',
              style: TextStyle(fontSize: 11, color: SB.muted)),
          const SizedBox(height: 10),
          SbField(
            controller: _code,
            hint: 'Type the code here',
            compact: true,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            onSubmitted: _redeem,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(8),
            ],
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              width: 100,
              child: SbButton(
                  label: 'Redeem',
                  height: 36,
                  radius: 10,
                  loading: _busy,
                  onPressed: _redeem),
            ),
          ),
        ]),
      );

  Widget _activity() {
    final items = _app.activity;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Padding(
        padding: EdgeInsets.only(left: 4, bottom: 8),
        child: Text('Recent activity',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
      ),
      if (items.isEmpty)
        const Padding(
          padding: EdgeInsets.all(4),
          child: Text(
              'Nothing yet. Recycle at a Smart Bin, then enter the code it shows.',
              style: TextStyle(fontSize: 12, color: SB.muted)),
        )
      else
        for (final a in items)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: SB.panel,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: SB.border.withAlpha(120)),
            ),
            child: Row(children: [
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(a.title, style: const TextStyle(fontSize: 13)),
                      const SizedBox(height: 2),
                      Text(formatDate(a.createdAt),
                          style: const TextStyle(fontSize: 10, color: SB.muted)),
                    ]),
              ),
              Text('${a.amount > 0 ? '+' : ''}${a.amount}',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: a.amount > 0
                          ? const Color(0xFF5FD38D)
                          : SB.muted)),
            ]),
          ),
    ]);
  }
}
