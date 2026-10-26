import 'package:flutter/foundation.dart';

import 'db/repository.dart';

/// Tiny app-wide state holder (no extra packages needed).
class AppState extends ChangeNotifier {
  AppState._();
  static final AppState instance = AppState._();

  final Repository repo = Repository();

  AppUser? user;
  int points = 0;
  List<ActivityItem> activity = const [];

  Future<void> init() async {
    user = await repo.restoreSession();
    await _load();
  }

  Future<void> _load() async {
    final u = user;
    if (u == null) {
      points = 0;
      activity = const [];
    } else {
      points = await repo.balance(u.id);
      activity = await repo.recentActivity(u.id);
    }
  }

  /// Re-reads points + activity from the database.
  Future<void> refresh() async {
    await _load();
    notifyListeners();
  }

  Future<void> setUser(AppUser u) async {
    user = u;
    await _load();
    notifyListeners();
  }

  Future<void> logOut() async {
    await repo.logOut();
    user = null;
    await _load();
    notifyListeners();
  }
}
