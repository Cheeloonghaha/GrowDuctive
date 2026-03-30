import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_preferences_model.dart';

class UserPreferencesViewModel extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  String? _userId;

  /// Stable stream per signed-in user so [StreamBuilder] does not resubscribe every frame.
  Stream<UserPreferencesModel?>? _cachedPrefsStream;
  String? _cachedPrefsStreamUserId;

  void setUserId(String? userId) {
    if (_userId != userId) {
      _cachedPrefsStream = null;
      _cachedPrefsStreamUserId = null;
      _optimisticTheme = null;
      _latestPreferencesSnapshot = null;
    }
    _userId = userId;
    notifyListeners();
  }

  /// Last preferences from the Firestore listener or [fetchPreferences]. Cleared on user switch.
  UserPreferencesModel? _latestPreferencesSnapshot;

  /// Latest known preferences (stream snapshot or last fetch). Cleared on user switch.
  UserPreferencesModel? get latestPreferencesSnapshot => _latestPreferencesSnapshot;

  /// While Firestore syncs, we show this theme immediately for responsive UI.
  String? _optimisticTheme;

  /// Resolved theme for UI: optimistic tap first, then prefs stream, then default.
  String themeResolved(String? prefsTheme) {
    if (_optimisticTheme != null) return _optimisticTheme!;
    return prefsTheme ?? 'light';
  }

  String? get userId => _userId;

  static const String _collection = 'user_preferences';

  /// Stream of current user's preferences. Returns null when logged out or doc missing.
  Stream<UserPreferencesModel?> get preferencesStream {
    final uid = _userId;
    if (uid == null || uid.isEmpty) {
      return Stream<UserPreferencesModel?>.value(null);
    }
    if (_cachedPrefsStreamUserId != uid || _cachedPrefsStream == null) {
      _cachedPrefsStreamUserId = uid;
      _cachedPrefsStream = _db.collection(_collection).doc(uid).snapshots().map((doc) {
        if (!doc.exists || doc.data() == null) {
          _latestPreferencesSnapshot = null;
          return null;
        }
        final prefs = UserPreferencesModel.fromMap(doc.data()!, doc.id);
        _latestPreferencesSnapshot = prefs;
        if (_optimisticTheme != null && prefs.theme == _optimisticTheme) {
          _optimisticTheme = null;
        }
        return prefs;
      });
    }
    return _cachedPrefsStream!;
  }

  /// One-time fetch. Returns null if doc does not exist.
  Future<UserPreferencesModel?> fetchPreferences() async {
    final uid = _userId;
    if (uid == null || uid.isEmpty) return null;
    try {
      final doc = await _db.collection(_collection).doc(uid).get();
      if (!doc.exists || doc.data() == null) {
        _latestPreferencesSnapshot = null;
        return null;
      }
      final prefs = UserPreferencesModel.fromMap(doc.data()!, doc.id);
      _latestPreferencesSnapshot = prefs;
      return prefs;
    } catch (e) {
      debugPrint('UserPreferencesViewModel fetchPreferences: $e');
      return null;
    }
  }

  /// Ensure the user has a preferences document. Creates one with defaults if missing.
  /// Call after login so subsequent fetch/stream return a doc.
  ///
  /// Uses a transaction so we never overwrite a doc created by a concurrent [update]
  /// (the old get-then-set pattern could replace the whole document and wipe fields).
  Future<void> ensureDefaults() async {
    final uid = _userId;
    if (uid == null || uid.isEmpty) return;
    try {
      final ref = _db.collection(_collection).doc(uid);
      var created = false;
      await _db.runTransaction((transaction) async {
        final snap = await transaction.get(ref);
        if (snap.exists && snap.data() != null) return;
        final now = DateTime.now();
        final defaults = UserPreferencesModel(
          userId: uid,
          updatedAt: now,
        );
        transaction.set(ref, defaults.toMap());
        created = true;
      });
      if (created) {
        debugPrint('UserPreferencesViewModel: created default prefs for user $uid');
      }
    } catch (e) {
      debugPrint('UserPreferencesViewModel ensureDefaults: $e');
    }
  }

  /// Update one or more preference fields. Merges with existing doc.
  Future<void> update(Map<String, dynamic> fields) async {
    final uid = _userId;
    if (uid == null || uid.isEmpty) {
      throw StateError('Cannot save preferences: not signed in.');
    }
    try {
      final updateData = Map<String, dynamic>.from(fields)
        ..['user_id'] = uid
        ..['updated_at'] = Timestamp.fromDate(DateTime.now());
      await _db.collection(_collection).doc(uid).set(updateData, SetOptions(merge: true));
      notifyListeners();
    } catch (e) {
      debugPrint('UserPreferencesViewModel update: $e');
      rethrow;
    }
  }

  /// Update Smart Task Organizer break settings.
  Future<void> updateScheduleBreakPreferences({
    required int breakDurationMinutes,
    required int breakAfterTaskMinutes,
  }) async {
    await update({
      'break_duration_minutes': breakDurationMinutes,
      'break_after_task_minutes': breakAfterTaskMinutes,
    });
  }

  /// Update theme (applies optimistically, then persists to Firestore).
  Future<void> updateTheme(String theme) async {
    _optimisticTheme = theme;
    notifyListeners();
    try {
      await update({'theme': theme});
    } catch (e) {
      _optimisticTheme = null;
      notifyListeners();
      rethrow;
    }
  }

}
