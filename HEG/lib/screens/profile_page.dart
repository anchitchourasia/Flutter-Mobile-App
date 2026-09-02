import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/session_store.dart';
import '../widgets/notification_bell.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  static const _bg1 = Color(0xFF0B1220);
  static const _bg2 = Color(0xFF0EA5A4);

  static const List<String> _dummyAvatars = [
    'assets/images/avatar_1.jpg',
    'assets/images/avatar_2.jpg',
    'assets/images/avatar_3.jpg',
  ];

  String? _selectedAvatar;

  String _avatarKey(String ec) => 'selected_avatar_$ec';

  @override
  void initState() {
    super.initState();
    _loadAvatar();
  }

  Future<void> _loadAvatar() async {
    final user = SessionStore.currentUser;
    if (user == null) return;

    final prefs = await SharedPreferences.getInstance();
    final savedAvatar = prefs.getString(_avatarKey(user.ec));

    final isValid = savedAvatar != null && _dummyAvatars.contains(savedAvatar);

    if (!isValid && savedAvatar != null) {
      await prefs.remove(_avatarKey(user.ec));
    }

    if (!mounted) return;
    setState(() {
      _selectedAvatar = isValid ? savedAvatar : null;
    });
  }

  String? _avatarFor(SessionUser user) => _selectedAvatar;

  Future<void> _saveAvatar(SessionUser user, String avatarPath) async {
    if (!_dummyAvatars.contains(avatarPath)) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_avatarKey(user.ec), avatarPath);

    if (!mounted) return;
    setState(() {
      _selectedAvatar = avatarPath;
    });
  }

  Future<void> _removeAvatar(SessionUser user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_avatarKey(user.ec));

    if (!mounted) return;
    setState(() {
      _selectedAvatar = null;
    });
  }

  Future<void> _openEditPhoto(SessionUser user) async {
    final result = await showModalBottomSheet<String?>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true, // ← IMPORTANT
      builder: (_) => _EditAvatarSheet(
        avatars: _dummyAvatars,
        initial: _avatarFor(user),
        initialsFallback: user.name.isNotEmpty ? user.name[0] : '?',
      ),
    );

    if (!mounted || result == null) return;

    if (result.isEmpty) {
      await _removeAvatar(user);
      return;
    }

    await _saveAvatar(user, result);
  }

  @override
  Widget build(BuildContext context) {
    final user = SessionStore.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        actions: const [NotificationBell(), SizedBox(width: 8)],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [_bg1, _bg2],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: user == null
              ? const Center(
                  child: Text(
                    'No user logged in',
                    style: TextStyle(color: Colors.white),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
                  children: [
                    Card(
                      elevation: 10,
                      shadowColor: Colors.black26,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                        child: Column(
                          children: [
                            Stack(
                              alignment: Alignment.bottomRight,
                              children: [
                                CircleAvatar(
                                  radius: 52,
                                  backgroundColor: const Color(0xFFE5E7EB),
                                  backgroundImage: _avatarFor(user) == null
                                      ? null
                                      : AssetImage(_avatarFor(user)!),
                                  child: _avatarFor(user) == null
                                      ? Text(
                                          user.name.isNotEmpty
                                              ? user.name[0]
                                              : '?',
                                          style: const TextStyle(
                                            fontSize: 28,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF111827),
                                          ),
                                        )
                                      : null,
                                ),
                                Material(
                                  color: const Color(0xFF2563EB),
                                  shape: const CircleBorder(),
                                  child: IconButton(
                                    onPressed: () => _openEditPhoto(user),
                                    icon: const Icon(
                                      Icons.edit,
                                      color: Colors.white,
                                    ),
                                    tooltip: 'Edit profile photo',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Text(
                              user.name,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${user.designation} • ${user.department}',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.black.withOpacity(0.65),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () => _openEditPhoto(user),
                                icon: const Icon(Icons.image_outlined),
                                label: const Text('Edit profile photo'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Card(
                      elevation: 10,
                      shadowColor: Colors.black26,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                        child: Column(
                          children: [
                            _InfoRow(
                              icon: Icons.badge_outlined,
                              label: 'EC',
                              value: user.ec,
                            ),
                            const Divider(height: 18),
                            _InfoRow(
                              icon: Icons.apartment_outlined,
                              label: 'Department',
                              value: user.department,
                            ),
                            const Divider(height: 18),
                            _InfoRow(
                              icon: Icons.work_outline,
                              label: 'Designation',
                              value: user.designation,
                            ),
                            const Divider(height: 18),
                            _InfoRow(
                              icon: Icons.category_outlined,
                              label: 'Category',
                              value: user.category.isEmpty
                                  ? '-'
                                  : user.category,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFF2563EB).withOpacity(0.10),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: const Color(0xFF2563EB)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  letterSpacing: 0.4,
                  color: Colors.black.withOpacity(0.55),
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EditAvatarSheet extends StatefulWidget {
  final List<String> avatars;
  final String? initial;
  final String initialsFallback;

  const _EditAvatarSheet({
    required this.avatars,
    required this.initial,
    required this.initialsFallback,
  });

  @override
  State<_EditAvatarSheet> createState() => _EditAvatarSheetState();
}

class _EditAvatarSheetState extends State<_EditAvatarSheet> {
  String? _temp;

  @override
  void initState() {
    super.initState();
    _temp = widget.initial;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Edit profile photo',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context, null),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 10),
          CircleAvatar(
            radius: 56,
            backgroundColor: const Color(0xFFE5E7EB),
            backgroundImage: (_temp == null) ? null : AssetImage(_temp!),
            child: (_temp == null)
                ? Text(
                    widget.initialsFallback,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF111827),
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: widget.avatars.map((a) {
              final selected = _temp == a;
              return InkWell(
                onTap: () => setState(() => _temp = a),
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected
                          ? const Color(0xFF2563EB)
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 26,
                    backgroundImage: AssetImage(a),
                    backgroundColor: const Color(0xFFE5E7EB),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.pop(context, ''),
              icon: const Icon(Icons.refresh),
              label: const Text('Use default photo'),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.pop(context, _temp ?? ''),
              icon: const Icon(Icons.check),
              label: const Text('Use this photo'),
            ),
          ),
        ],
      ),
    );
  }
}
