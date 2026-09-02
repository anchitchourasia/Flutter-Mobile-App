import 'dart:async';
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;

class ApplicantListItem {
  final String applicantId;
  final String applicantName;

  ApplicantListItem({required this.applicantId, required this.applicantName});

  factory ApplicantListItem.fromJson(Map<String, dynamic> json) {
    return ApplicantListItem(
      applicantId: (json['applicantId'] ?? '').toString(),
      applicantName: (json['applicantName'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'applicantId': applicantId,
    'applicantName': applicantName,
  };
}

class ApplicantsPage extends StatefulWidget {
  const ApplicantsPage({super.key});

  @override
  State<ApplicantsPage> createState() => _ApplicantsPageState();
}

class _ApplicantsPageState extends State<ApplicantsPage> {
  static final String _apiKey = dotenv.env['API_KEY'] ?? '';
  static final String _baseUrl = dotenv.env['BASE_URL'] ?? '';
  static const String _cacheKey = 'applicants_cache_v1';

  // ✅ Same background as InsuranceUploadPage
  static const Color _bg1 = Color(0xFF0B1E3A);
  static const Color _bg2 = Color(0xFF0EA5A4);

  final Box _box = Hive.box('cache');
  StreamSubscription<List<ConnectivityResult>>? _connSub;

  final TextEditingController _searchCtrl = TextEditingController();

  List<ApplicantListItem> _items = []; // full list
  List<ApplicantListItem> _filtered = []; // filtered list for UI

  bool _loading = true;
  bool _syncing = false;
  String? _status;

  @override
  void initState() {
    super.initState();
    _loadFromCache(); // instant UI from offline cache
    _listenConnectivity(); // when back online, refresh
    _trySync(); // attempt immediately

    _searchCtrl.addListener(() {
      _applySearch(_searchCtrl.text);
    });
  }

  @override
  void dispose() {
    _connSub?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _listenConnectivity() {
    _connSub = Connectivity().onConnectivityChanged.listen((results) {
      final online = results.any(
        (r) =>
            r == ConnectivityResult.wifi ||
            r == ConnectivityResult.mobile ||
            r == ConnectivityResult.ethernet ||
            r == ConnectivityResult.vpn,
      );

      if (online) _trySync();
    });
  }

  void _applySearch(String q) {
    final query = q.trim().toLowerCase();
    if (query.isEmpty) {
      setState(() => _filtered = List.of(_items));
      return;
    }

    setState(() {
      _filtered = _items.where((a) {
        final name = a.applicantName.toLowerCase();
        final id = a.applicantId.toLowerCase();
        return name.contains(query) || id.contains(query);
      }).toList();
    });
  }

  void _loadFromCache() {
    final cached = _box.get(_cacheKey);
    if (cached is String && cached.isNotEmpty) {
      try {
        final List<dynamic> data = jsonDecode(cached) as List<dynamic>;
        final loaded = data
            .map((e) => ApplicantListItem.fromJson(e as Map<String, dynamic>))
            .toList();

        setState(() {
          _items = loaded;
          _filtered = List.of(loaded);
          _loading = false;
          _status = 'Loaded from offline cache';
        });

        // apply current search (if any)
        _applySearch(_searchCtrl.text);
      } catch (_) {
        setState(() {
          _loading = false;
          _status = 'Cache parse failed';
        });
      }
    } else {
      setState(() {
        _loading = false;
        _status = 'No cache yet';
      });
    }
  }

  Future<void> _trySync() async {
    if (_syncing) return;

    setState(() {
      _syncing = true;
      _status = 'Syncing...';
    });

    try {
      final fresh = await _fetchApplicants();

      final jsonStr = jsonEncode(fresh.map((e) => e.toJson()).toList());
      await _box.put(_cacheKey, jsonStr);

      if (!mounted) return;
      setState(() {
        _items = fresh;
        _filtered = List.of(fresh);
        _status = 'Updated from server (${fresh.length})';
      });

      _applySearch(_searchCtrl.text);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = 'Offline / sync failed';
      });
    } finally {
      if (!mounted) return;
      setState(() => _syncing = false);
    }
  }

  Future<List<ApplicantListItem>> _fetchApplicants({int? limit}) async {
    final Uri uri = (limit == null)
        ? Uri.parse('$_baseUrl/api/applicants')
        : Uri.parse('$_baseUrl/api/applicants?limit=$limit');

    final res = await http.get(
      uri,
      headers: {'X-API-KEY': _apiKey, 'Accept': 'application/json'},
    );

    if (res.statusCode != 200) {
      throw Exception('HTTP ${res.statusCode}: ${res.body}');
    }

    final List<dynamic> data = jsonDecode(res.body) as List<dynamic>;
    return data
        .map((e) => ApplicantListItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_bg1, _bg2],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: const Color.fromARGB(255, 243, 241, 241),
          elevation: 0,
          title: const Text('Applicants'),
          actions: [
            IconButton(
              onPressed: _syncing ? null : _trySync,
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
            ),
          ],
        ),
        body: SafeArea(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                      child: _SearchBar(
                        controller: _searchCtrl,
                        onClear: () {
                          _searchCtrl.clear();
                          FocusScope.of(context).unfocus();
                        },
                      ),
                    ),
                    if (_status != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                        child: _StatusPill(text: _status!),
                      ),
                    Expanded(
                      child: _filtered.isEmpty
                          ? Center(
                              child: Text(
                                _searchCtrl.text.trim().isEmpty
                                    ? 'No applicants'
                                    : 'No match found',
                                style: const TextStyle(color: Colors.white),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                              itemCount: _filtered.length,
                              itemBuilder: (context, i) {
                                final a = _filtered[i];
                                return _ApplicantCard(item: a);
                              },
                            ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onClear;

  const _SearchBar({required this.controller, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.search, color: Colors.white),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              style: const TextStyle(color: Colors.white),
              cursorColor: Colors.white,
              decoration: const InputDecoration(
                hintText: '',
                hintStyle: TextStyle(color: Colors.white70, fontSize: 13),
                border: InputBorder.none,
              ),
            ),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) {
              final show = value.text.trim().isNotEmpty;
              if (!show) return const SizedBox.shrink();
              return IconButton(
                onPressed: onClear,
                icon: const Icon(Icons.close, color: Colors.white),
                tooltip: 'Clear',
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ApplicantCard extends StatelessWidget {
  final ApplicantListItem item;
  const _ApplicantCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF0EA5A4).withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.person, color: Color(0xFF0B1E3A)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.applicantName.isEmpty ? '(No name)' : item.applicantName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0B1E3A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Applicant ID: ${item.applicantId}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF5A6B7A),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String text;
  const _StatusPill({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.25)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
