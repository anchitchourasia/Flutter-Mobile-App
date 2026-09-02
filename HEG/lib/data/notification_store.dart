import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';

import 'insurance_db.dart';
import 'session_store.dart';

class NotificationStore {
  static final ValueNotifier<int> unreadCount = ValueNotifier<int>(0);

  static const String _apiKey = 'HEG_12345_SECRET';
  static const String _definedBaseUrl = String.fromEnvironment('BASE_URL');
  static const int _port = 8080;

  static String get _baseUrl =>
      _definedBaseUrl.isNotEmpty ? _definedBaseUrl : 'http://10.0.2.2:$_port';

  static Map<String, String> _headers() => {
    'X-API-KEY': _apiKey,
    'Accept': 'application/json',
  };

  static Future<int> _localUnread(Database db, String userId) async {
    final res = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM user_notifications WHERE user_id = ? AND is_read = 0',
      [userId],
    );
    return Sqflite.firstIntValue(res) ?? 0;
  }

  static Future<void> refreshUnreadCount() async {
    final userId = SessionStore.currentUserId;
    if (userId == null || userId.isEmpty) {
      unreadCount.value = 0;
      return;
    }

    final db = await InsuranceDb.database;

    // count before sync (to detect increases)
    final before = await _localUnread(db, userId);

    // sync from server -> upsert into local
    try {
      final uri = Uri.parse(
        '$_baseUrl/api/insurance/notifications',
      ).replace(queryParameters: {'userId': userId});

      final res = await http.get(uri, headers: _headers());
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final decoded = jsonDecode(res.body);
        if (decoded is List) {
          await InsuranceDb.upsertNotificationsForUser(userId, decoded);
        }
      }
    } catch (_) {
      // ignore network errors; still update from local
    }

    final after = await _localUnread(db, userId);

    // update notifier only if changed (ValueNotifier notifies on change)
    if (unreadCount.value != after) unreadCount.value = after;

    // If you want: when new notification arrives, ensure at least one "change"
    // even if some edge-case made count same, you can force refresh by toggling:
    // (Not recommended normally; better fix upsert uniqueness.)
    // if (after == before && after > 0) { unreadCount.value = after; }
  }

  static void add() {
    refreshUnreadCount();
  }

  static Future<void> clear() async {
    final userId = SessionStore.currentUserId;
    if (userId == null || userId.isEmpty) {
      unreadCount.value = 0;
      return;
    }
    await InsuranceDb.clearNotificationsForUser(userId);
    await refreshUnreadCount();
  }

  static void resetLocal() {
    unreadCount.value = 0;
  }

  static Future<void> markAllAsReadLocal() async {
    final userId = SessionStore.currentUserId;
    if (userId == null || userId.isEmpty) {
      unreadCount.value = 0;
      return;
    }

    final db = await InsuranceDb.database;
    await db.rawUpdate(
      'UPDATE user_notifications SET is_read = 1 WHERE user_id = ?',
      [userId],
    );

    if (unreadCount.value != 0) unreadCount.value = 0;
  }
}
