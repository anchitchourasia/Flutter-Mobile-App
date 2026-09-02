import 'package:flutter/material.dart';
import '../data/session_store.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/api_config.dart'; // ← if not already imported

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();

  final _userController = TextEditingController();
  final _passController = TextEditingController();

  bool _obscure = true;
  bool _loading = false;

  @override
  void dispose() {
    _userController.dispose();
    _passController.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>?> _fetchEmployeeDetails(String empCode) async {
    final code = empCode.trim();

    if (code.isEmpty) {
      return null;
    }

    try {
      final response = await http
          .get(
            Uri.parse(
              '${ApiConfig.employeeReport}/${Uri.encodeComponent(code)}',
            ),
            headers: {
              'x-api-key': ApiConfig.apiKey,
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(milliseconds: 12000));

      if (response.statusCode != 200) {
        return null;
      }

      final body = jsonDecode(response.body);

      if (body is! Map<String, dynamic>) {
        return null;
      }

      final data = body['data'];

      return data is Map<String, dynamic> ? data : body;
    } catch (_) {
      return null;
    }
  }

  String _firstText(List<dynamic> values, {String fallback = ''}) {
    for (final value in values) {
      final text = value?.toString().trim() ?? '';

      if (text.isNotEmpty &&
          text.toUpperCase() != 'NULL' &&
          text.toUpperCase() != 'N/A') {
        return text;
      }
    }

    return fallback;
  }

  Future<void> _onLogin() async {
    FocusScope.of(context).unfocus();

    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    setState(() => _loading = true);

    final u = _userController.text.trim();
    final p = _passController.text.trim();

    // ════════════════════════════════════════════════════════════
    // KEEP EXISTING DEMO LOGINS (for offline testing)
    // ════════════════════════════════════════════════════════════

    // ADMIN LOGIN
    if (u == 'admin' && p == '123456') {
      const user = SessionUser(
        name: 'Admin',
        ec: '929',
        department: 'ADMIN',
        designation: 'Administrator',
        category: 'Admin',
        role: 'APPROVER', // ← ADD THIS
      );

      await SessionStore.saveLogin(userId: 'admin', admin: true, user: user);

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/home');
      return;
    }

    // USER 1
    if (u == 'admin1' && p == '123456') {
      const user = SessionUser(
        name: 'Prabhat Saxena',
        ec: '185',
        department: 'IT 163',
        designation: 'Manager',
        category: 'Executive',
        role: 'EMPLOYEE', // ← ADD THIS
      );

      await SessionStore.saveLogin(userId: 'admin1', admin: false, user: user);

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/home');
      return;
    }

    // USER 2
    if (u == 'admin2' && p == '123456') {
      const user = SessionUser(
        name: 'Arvind Kumar Bairagi',
        ec: '113',
        department: 'IT 163',
        designation: 'Senior Manager',
        category: 'Executive',
        role: 'EMPLOYEE', // ← ADD THIS
      );

      await SessionStore.saveLogin(userId: 'admin2', admin: false, user: user);

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/home');
      return;
    }

    // ════════════════════════════════════════════════════════════
    // CALL WEB API LOGIN (same as web UI)
    // ════════════════════════════════════════════════════════════

    try {
      final response = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}/api/authority/login'),
            headers: {
              'x-api-key': ApiConfig.apiKey,
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'username': u, 'password': p}),
          )
          .timeout(const Duration(milliseconds: 12000));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map;

        // Extract role from response (same as web)
        final roleStr = (data['role'] ?? 'UPLOADER')
            .toString()
            .toUpperCase()
            .trim();
        final empCodeStr = (data['empNo'] ?? u).toString().trim();

        // Map web role to mobile session
        String mappedRole;
        String mappedCategory;

        if (roleStr == 'APPROVER' || roleStr == 'ADMIN') {
          mappedRole = 'APPROVER';
          mappedCategory = 'Authority';
        } else if (roleStr == 'CONFIRMER') {
          mappedRole = 'CONFIRMER';
          mappedCategory = 'Authority';
        } else if (roleStr == 'UPLOADER') {
          mappedRole = 'UPLOADER';
          mappedCategory = 'Authority';
        } else {
          mappedRole = 'EMPLOYEE';
          mappedCategory = 'Company_Employee';
        }

        final employeeDetails = await _fetchEmployeeDetails(empCodeStr) ?? {};

        final user = SessionUser(
          name: _firstText([
            employeeDetails['empName'],
            employeeDetails['name'],
            employeeDetails['employeeName'],
            data['empName'],
            data['name'],
            empCodeStr,
          ], fallback: empCodeStr),
          ec: empCodeStr,
          department: _firstText([
            employeeDetails['department'],
            employeeDetails['departmentName'],
            employeeDetails['dept'],
            employeeDetails['deptName'],
            employeeDetails['DEPARTMENT'],
            employeeDetails['DEPT'],
            data['department'],
            data['departmentName'],
            data['dept'],
            data['deptName'],
          ], fallback: '-'),
          designation: _firstText([
            employeeDetails['designation'],
            employeeDetails['designationName'],
            employeeDetails['desig'],
            data['designation'],
            data['designationName'],
            mappedRole,
          ], fallback: mappedRole),
          category: _firstText([
            employeeDetails['category'],
            employeeDetails['employeeCategory'],
            employeeDetails['userCategory'],
            data['category'],
            data['employeeCategory'],
            mappedCategory,
          ], fallback: mappedCategory),
          role: mappedRole,
        );

        await SessionStore.saveLogin(
          userId: empCodeStr,
          admin: mappedRole == 'APPROVER',
          user: user,
        );

        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/home');
      } else if (response.statusCode == 401) {
        if (!mounted) return;
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid Employee Code or Password'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else if (response.statusCode == 404) {
        if (!mounted) return;
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Employee Code "$u" not found'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        if (!mounted) return;
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Login failed. Try again.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot reach server. Check network.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0B1220), Color(0xFF1D4ED8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          Positioned(
            top: -60,
            left: -60,
            child: _Blob(color: Colors.white.withOpacity(0.10), size: 180),
          ),
          Positioned(
            bottom: -80,
            right: -50,
            child: _Blob(color: Colors.white.withOpacity(0.08), size: 220),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: Colors.white.withOpacity(0.18)),
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 6),
                          const _BrandHeader(),
                          const SizedBox(height: 18),

                          _GlassField(
                            controller: _userController,
                            label: 'Username',
                            hint: 'e.g., admin, admin1, admin2',
                            icon: Icons.badge_outlined,
                            textInputAction: TextInputAction.next,
                            validator: (v) {
                              final value = (v ?? '').trim();
                              if (value.isEmpty) return 'Enter your username';
                              if (value.length < 3) return 'Too short';
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),

                          _GlassField(
                            controller: _passController,
                            label: 'Password',
                            hint: 'Enter your password',
                            icon: Icons.lock_outline,
                            obscureText: _obscure,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _loading ? null : _onLogin(),
                            suffix: IconButton(
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
                              icon: Icon(
                                _obscure
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                color: Colors.white.withOpacity(0.85),
                              ),
                            ),
                            validator: (v) {
                              final value = v ?? '';
                              if (value.isEmpty) return 'Enter your password';
                              if (value.length < 6) {
                                return 'Minimum 6 characters';
                              }
                              return null;
                            },
                          ),

                          const SizedBox(height: 18),

                          SizedBox(
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _loading ? null : _onLogin,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF60A5FA),
                                foregroundColor: const Color(0xFF0B1220),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: _loading
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text(
                                      'Login',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                            ),
                          ),

                          const SizedBox(height: 10),
                          Text(
                            'Demo: admin / 123456  •  admin1 / 123456  •  admin2 / 123456',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.75),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.18)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Image.asset('assets/images/image3.jpg', fit: BoxFit.contain),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'HEG Employee Portal',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Login to continue',
          style: TextStyle(color: Colors.white.withOpacity(0.80)),
        ),
      ],
    );
  }
}

class _GlassField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final bool obscureText;
  final TextInputAction textInputAction;
  final Widget? suffix;
  final String? Function(String?)? validator;
  final void Function(String)? onSubmitted;

  const _GlassField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.obscureText = false,
    this.textInputAction = TextInputAction.next,
    this.suffix,
    this.validator,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      textInputAction: textInputAction,
      onFieldSubmitted: onSubmitted,
      style: const TextStyle(color: Colors.white),
      cursorColor: Colors.white,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.85)),
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.55)),
        prefixIcon: Icon(icon, color: Colors.white.withOpacity(0.85)),
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.white.withOpacity(0.08),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.18)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.55)),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
      ),
      validator: validator,
    );
  }
}

class _Blob extends StatelessWidget {
  final Color color;
  final double size;

  const _Blob({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
