import 'dart:async';

import 'package:flutter/material.dart';

import '../services/firebase_service.dart';
import '../widgets/common.dart';
class SplashGate extends StatefulWidget {
  const SplashGate({super.key});

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> {
  bool _showOnboarding = false;

  @override
  void initState() {
    super.initState();

    Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _showOnboarding = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_showOnboarding) return const Onboarding();

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/logo.png',
              width: 140,
              height: 140,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 12),
            const Text(
              'طبيبي',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Text(
              'رعايتك الصحية في مكان واحد',
            ),
          ],
        ),
      ),
    );
  }
}
class Onboarding extends StatelessWidget {
  const Onboarding({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.medical_services_outlined,
                size: 120,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 24),
              const Text(
                'احجز موعدك، تابع وصفاتك وابحث عن دوائك بسهولة',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 32),
              BusyButton(
                'ابدأ الآن',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تسجيل الدخول')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'البريد الإلكتروني'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _password,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'كلمة المرور'),
          ),
          TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ForgotScreen()),
            ),
            child: const Text('نسيت كلمة المرور؟'),
          ),
          BusyButton(
            _busy ? 'جارٍ الدخول...' : 'دخول',
            onPressed: _busy
                ? null
                : () async {
                    if (_email.text.trim().isEmpty || _password.text.isEmpty) {
                      msg(context, 'أدخل البريد الإلكتروني وكلمة المرور.');
                      return;
                    }
                    try {
                      setState(() => _busy = true);
                      await FirebaseService().login(
                        _email.text.trim(),
                        _password.text,
                      );
                      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
                    } catch (_) {
                      if (mounted) {
                        msg(context, 'تعذر تسجيل الدخول. تحقق من البيانات.');
                      }
                    } finally {
                      if (mounted) setState(() => _busy = false);
                    }
                  },
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const RoleSelect()),
            ),
            child: const Text('إنشاء حساب / طلب انضمام'),
          ),
        ],
      ),
    );
  }
}

class RoleSelect extends StatelessWidget {
  const RoleSelect({super.key});

  @override
  Widget build(BuildContext context) {
    final roles = <({String role, String label, IconData icon})>[
      (role: 'patient', label: 'مريض', icon: Icons.person),
      (role: 'clinic', label: 'عيادة', icon: Icons.local_hospital),
      (role: 'pharmacy', label: 'صيدلية', icon: Icons.local_pharmacy),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('نوع المستخدم')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          for (final item in roles)
            Card(
              child: ListTile(
                leading: Icon(item.icon),
                title: Text(item.label),
                trailing: const Icon(Icons.chevron_left),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RegisterScreen(role: item.role),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class RegisterScreen extends StatefulWidget {
  final String role;

  const RegisterScreen({super.key, required this.role});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _phone = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _phone.dispose();
    super.dispose();
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) return 'هذا الحقل مطلوب';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isPatient = widget.role == 'patient';
    return Scaffold(
      appBar: AppBar(title: Text(isPatient ? 'إنشاء حساب' : 'طلب انضمام')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            TextFormField(
              controller: _name,
              validator: _required,
              decoration: InputDecoration(
                labelText: widget.role == 'patient' ? 'الاسم' : 'اسم الجهة',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                final requiredError = _required(value);
                if (requiredError != null) return requiredError;
                if (!value!.contains('@')) return 'أدخل بريدًا إلكترونيًا صحيحًا';
                return null;
              },
              decoration: const InputDecoration(labelText: 'البريد الإلكتروني'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              validator: _required,
              decoration: const InputDecoration(labelText: 'الهاتف'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _password,
              obscureText: true,
              validator: (value) {
                final requiredError = _required(value);
                if (requiredError != null) return requiredError;
                if (value!.length < 6) return 'كلمة المرور يجب أن تكون 6 أحرف على الأقل';
                return null;
              },
              decoration: const InputDecoration(labelText: 'كلمة المرور'),
            ),
            const SizedBox(height: 16),
            BusyButton(
              _busy ? 'جارٍ الحفظ...' : 'متابعة',
              onPressed: _busy
                  ? null
                  : () async {
                      if (!_formKey.currentState!.validate()) return;
                      try {
                        setState(() => _busy = true);
                        await FirebaseService().register(
                          email: _email.text.trim(),
                          password: _password.text,
                          name: _name.text.trim(),
                          role: widget.role,
                          phone: _phone.text.trim(),
                        );
                        if (!mounted) return;
                        msg(
                          context,
                          isPatient
                              ? 'تم إنشاء الحساب بنجاح'
                              : 'تم إرسال الطلب وسيتم تفعيل الحساب بعد موافقة الإدارة',
                        );
                        Navigator.of(context).popUntil((route) => route.isFirst);
                      } catch (error) {
                        if (mounted) msg(context, 'تعذر إنشاء الحساب: $error');
                      } finally {
                        if (mounted) setState(() => _busy = false);
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }
}

class ForgotScreen extends StatefulWidget {
  const ForgotScreen({super.key});

  @override
  State<ForgotScreen> createState() => _ForgotScreenState();
}

class _ForgotScreenState extends State<ForgotScreen> {
  final _email = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('استعادة كلمة المرور')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'البريد الإلكتروني'),
            ),
            const SizedBox(height: 16),
            BusyButton(
              _busy ? 'جارٍ الإرسال...' : 'إرسال رابط الاستعادة',
              onPressed: _busy
                  ? null
                  : () async {
                      if (_email.text.trim().isEmpty) {
                        msg(context, 'أدخل البريد الإلكتروني');
                        return;
                      }
                      try {
                        setState(() => _busy = true);
                        await FirebaseService().reset(_email.text.trim());
                        if (mounted) msg(context, 'تم إرسال رابط الاستعادة');
                      } catch (_) {
                        if (mounted) msg(context, 'تعذر إرسال الرابط');
                      } finally {
                        if (mounted) setState(() => _busy = false);
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }
}
