import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/auth_provider.dart';
import '../services/firebase_service.dart';
import '../widgets/common.dart';
import 'modules.dart';

class RoleHome extends StatelessWidget {
  const RoleHome({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final profile = auth.profile;

    if (profile == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (profile.status != 'active') {
      final message = profile.status == 'pending'
          ? 'طلبك قيد مراجعة الإدارة. سيتم فتح لوحة التحكم بعد الموافقة.'
          : 'الحساب غير نشط حاليًا. تواصل مع إدارة النظام.';
      return Scaffold(
        appBar: AppBar(
          title: const Text('طبيبي'),
          actions: [
            IconButton(
              onPressed: auth.logout,
              tooltip: 'تسجيل الخروج',
              icon: const Icon(Icons.logout),
            ),
          ],
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20),
            ),
          ),
        ),
      );
    }

    return Dashboard(role: profile.role, name: profile.name);
  }
}

class Dashboard extends StatelessWidget {
  final String role;
  final String name;

  const Dashboard({super.key, required this.role, required this.name});

  @override
  Widget build(BuildContext context) {
    final items = <({String title, IconData icon, Widget screen})>[];

    switch (role) {
      case 'patient':
        items.addAll([
          (
            title: 'العيادات والأطباء',
            icon: Icons.local_hospital,
            screen: const ClinicsScreen(),
          ),
          (
            title: 'مواعيدي',
            icon: Icons.calendar_month,
            screen: const MyAppointments(),
          ),
          (
            title: 'وصفاتي',
            icon: Icons.receipt_long,
            screen: const PrescriptionsScreen(),
          ),
          (
            title: 'البحث عن دواء',
            icon: Icons.medication,
            screen: const MedicineSearch(),
          ),
        ]);
        break;
      case 'clinic':
        items.addAll([
          (
            title: 'الأطباء',
            icon: Icons.medical_information,
            screen: const DoctorsManage(),
          ),
          (
            title: 'الفترات والمواعيد',
            icon: Icons.schedule,
            screen: const SlotsManage(),
          ),
          (
            title: 'الحجوزات',
            icon: Icons.event_available,
            screen: const ClinicBookings(),
          ),
        ]);
        break;
      case 'doctor':
        items.addAll([
          (
            title: 'جدول المواعيد والمرضى',
            icon: Icons.calendar_today,
            screen: const DoctorAppointments(),
          ),
          (
            title: 'إصدار وصفة',
            icon: Icons.receipt_long,
            screen: const CreatePrescription(),
          ),
        ]);
        break;
      case 'pharmacy':
        items.add((
          title: 'مخزون الأدوية',
          icon: Icons.inventory_2,
          screen: const InventoryManage(),
        ));
        break;
      case 'admin':
        items.addAll([
          (
            title: 'طلبات الانضمام',
            icon: Icons.approval,
            screen: const JoinRequests(),
          ),
          (
            title: 'إدارة المستخدمين',
            icon: Icons.people,
            screen: const UsersManage(),
          ),
          (
            title: 'إحصاءات المنصة',
            icon: Icons.analytics,
            screen: const StatsScreen(),
          ),
        ]);
        break;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('مرحبًا، $name'),
        actions: [
          IconButton(
            onPressed: () => context.read<AuthProvider>().logout(),
            tooltip: 'تسجيل الخروج',
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: items.isEmpty
          ? const EmptyState('لا توجد صلاحيات متاحة لهذا الحساب')
          : GridView.count(
              crossAxisCount: MediaQuery.sizeOf(context).width > 600 ? 3 : 2,
              padding: const EdgeInsets.all(16),
              children: [
                for (final item in items)
                  Card(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => item.screen),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            item.icon,
                            size: 42,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(height: 10),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              item.title,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ProfileScreen()),
        ),
        icon: const Icon(Icons.person),
        label: const Text('الملف الشخصي'),
      ),
    );
  }
}



class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirebaseService _service = FirebaseService();

  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();

  final TextEditingController _name = TextEditingController();
  final TextEditingController _phone = TextEditingController();

  // Patient
  final TextEditingController _birthDate = TextEditingController();
  final TextEditingController _address = TextEditingController();
  String _gender = '';

  // Doctor
  final TextEditingController _specialty = TextEditingController();
  final TextEditingController _licenseNumber = TextEditingController();
  final TextEditingController _experienceYears = TextEditingController();
  final TextEditingController _bio = TextEditingController();

  // Clinic
  final TextEditingController _services = TextEditingController();
  final TextEditingController _workingHours = TextEditingController();
  final TextEditingController _description = TextEditingController();

  bool _loading = true;
  bool _busy = false;

  String _role = '';
  String _email = '';
  String? _imagePath;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _birthDate.dispose();
    _address.dispose();
    _specialty.dispose();
    _licenseNumber.dispose();
    _experienceYears.dispose();
    _bio.dispose();
    _services.dispose();
    _workingHours.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      await _service.syncCurrentEmail();

      final user = _service.auth.currentUser;

      if (user == null) {
        throw Exception('المستخدم غير مسجل الدخول');
      }

      final doc =
      await _service.db.collection('users').doc(user.uid).get();

      final data = doc.data() ?? {};

      final prefs = await SharedPreferences.getInstance();

      if (!mounted) return;

      setState(() {
        _role = data['role']?.toString() ?? '';
        _email = user.email ?? data['email']?.toString() ?? '';

        _name.text = data['name']?.toString() ?? '';
        _phone.text = data['phone']?.toString() ?? '';

        _birthDate.text = data['birthDate']?.toString() ?? '';
        _gender = data['gender']?.toString() ?? '';
        _address.text = data['address']?.toString() ?? '';

        _specialty.text = data['specialty']?.toString() ?? '';
        _licenseNumber.text =
            data['licenseNumber']?.toString() ?? '';
        _experienceYears.text =
            data['experienceYears']?.toString() ?? '';
        _bio.text = data['bio']?.toString() ?? '';

        _services.text = data['services']?.toString() ?? '';
        _workingHours.text =
            data['workingHours']?.toString() ?? '';
        _description.text =
            data['description']?.toString() ?? '';

        _imagePath =
            prefs.getString('profile_image_${user.uid}');

        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => _loading = false);

      msg(
        context,
        'تعذر تحميل بيانات الملف الشخصي',
      );
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 75,
        maxWidth: 1000,
      );

      if (picked == null) return;

      final user = _service.auth.currentUser;

      if (user == null) return;

      final appDirectory =
      await getApplicationDocumentsDirectory();

      final profileDirectory = Directory(
        '${appDirectory.path}/profile_images',
      );

      if (!await profileDirectory.exists()) {
        await profileDirectory.create(
          recursive: true,
        );
      }

      final extension = picked.path.contains('.')
          ? picked.path.split('.').last
          : 'jpg';

      final destination =
          '${profileDirectory.path}/${user.uid}.$extension';

      final savedFile =
      await File(picked.path).copy(destination);

      final prefs = await SharedPreferences.getInstance();

      await prefs.setString(
        'profile_image_${user.uid}',
        savedFile.path,
      );

      if (!mounted) return;

      setState(() {
        _imagePath = savedFile.path;
      });

      msg(
        context,
        'تم تحديث الصورة',
      );
    } catch (_) {
      if (!mounted) return;

      msg(
        context,
        'تعذر اختيار الصورة',
      );
    }
  }

  Future<void> _removeImage() async {
    final user = _service.auth.currentUser;

    if (user == null) return;

    final prefs = await SharedPreferences.getInstance();

    final oldPath =
    prefs.getString('profile_image_${user.uid}');

    if (oldPath != null) {
      final file = File(oldPath);

      if (await file.exists()) {
        try {
          await file.delete();
        } catch (_) {}
      }
    }

    await prefs.remove(
      'profile_image_${user.uid}',
    );

    if (!mounted) return;

    setState(() => _imagePath = null);

    msg(
      context,
      'تم حذف الصورة',
    );
  }

  Future<void> _selectBirthDate() async {
    final now = DateTime.now();

    DateTime initialDate =
    DateTime(now.year - 20, now.month, now.day);

    if (_birthDate.text.isNotEmpty) {
      try {
        initialDate =
            DateTime.parse(_birthDate.text);
      } catch (_) {}
    }

    final selected = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: 'اختيار تاريخ الميلاد',
      cancelText: 'إلغاء',
      confirmText: 'اختيار',
    );

    if (selected == null) return;

    if (!mounted) return;

    setState(() {
      _birthDate.text =
      '${selected.year.toString().padLeft(4, '0')}-'
          '${selected.month.toString().padLeft(2, '0')}-'
          '${selected.day.toString().padLeft(2, '0')}';
    });
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    try {
      setState(() => _busy = true);

      final values = <String, dynamic>{
        'name': _name.text.trim(),
        'phone': _phone.text.trim(),
      };

      switch (_role) {
        case 'patient':
          values.addAll({
            'birthDate': _birthDate.text.trim(),
            'gender': _gender,
            'address': _address.text.trim(),
          });
          break;

        case 'doctor':
          values.addAll({
            'specialty': _specialty.text.trim(),
            'licenseNumber':
            _licenseNumber.text.trim(),
            'experienceYears':
            int.tryParse(
              _experienceYears.text.trim(),
            ) ??
                0,
            'bio': _bio.text.trim(),
          });
          break;

        case 'clinic':
          values.addAll({
            'address': _address.text.trim(),
            'services': _services.text.trim(),
            'workingHours':
            _workingHours.text.trim(),
            'description':
            _description.text.trim(),
          });
          break;

        case 'pharmacy':
          values.addAll({
            'address': _address.text.trim(),
            'workingHours':
            _workingHours.text.trim(),
            'description':
            _description.text.trim(),
          });
          break;

        case 'admin':
          break;
      }

      await _service.updateCurrentUserProfile(
        values,
      );

      if (!mounted) return;

      msg(
        context,
        'تم حفظ بيانات الملف الشخصي',
      );
    } catch (e) {
      if (!mounted) return;

      msg(
        context,
        _cleanError(e),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  String _cleanError(Object error) {
    return error
        .toString()
        .replaceFirst('Exception: ', '');
  }

  String _roleName(String role) {
    switch (role) {
      case 'patient':
        return 'مريض';
      case 'doctor':
        return 'طبيب';
      case 'clinic':
        return 'عيادة';
      case 'pharmacy':
        return 'صيدلية';
      case 'admin':
        return 'مدير النظام';
      default:
        return role;
    }
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    IconData? icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    bool required = false,
    bool readOnly = false,
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: 14,
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        readOnly: readOnly,
        onTap: onTap,
        validator: required
            ? (value) {
          if (value == null ||
              value.trim().isEmpty) {
            return 'هذا الحقل مطلوب';
          }

          return null;
        }
            : null,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon:
          icon == null ? null : Icon(icon),
        ),
      ),
    );
  }

  Widget _patientFields() {
    return Column(
      children: [
        _field(
          controller: _birthDate,
          label: 'تاريخ الميلاد',
          icon: Icons.cake_outlined,
          readOnly: true,
          onTap: _selectBirthDate,
        ),
        Padding(
          padding:
          const EdgeInsets.only(bottom: 14),
          child: DropdownButtonFormField<String>(
            initialValue:
            _gender.isEmpty ? null : _gender,
            decoration: const InputDecoration(
              labelText: 'الجنس',
              prefixIcon:
              Icon(Icons.person_outline),
            ),
            items: const [
              DropdownMenuItem(
                value: 'male',
                child: Text('ذكر'),
              ),
              DropdownMenuItem(
                value: 'female',
                child: Text('أنثى'),
              ),
            ],
            onChanged: (value) {
              setState(() {
                _gender = value ?? '';
              });
            },
          ),
        ),
        _field(
          controller: _address,
          label: 'العنوان',
          icon: Icons.location_on_outlined,
        ),
      ],
    );
  }

  Widget _doctorFields() {
    return Column(
      children: [
        _field(
          controller: _specialty,
          label: 'التخصص',
          icon: Icons.medical_services_outlined,
          required: true,
        ),
        _field(
          controller: _licenseNumber,
          label: 'رقم الترخيص',
          icon: Icons.badge_outlined,
        ),
        _field(
          controller: _experienceYears,
          label: 'سنوات الخبرة',
          icon: Icons.timeline,
          keyboardType: TextInputType.number,
        ),
        _field(
          controller: _bio,
          label: 'نبذة عن الطبيب',
          icon: Icons.description_outlined,
          maxLines: 4,
        ),
      ],
    );
  }

  Widget _clinicFields() {
    return Column(
      children: [
        _field(
          controller: _address,
          label: 'عنوان العيادة',
          icon: Icons.location_on_outlined,
        ),
        _field(
          controller: _services,
          label: 'الخدمات والتخصصات',
          icon: Icons.medical_information_outlined,
          maxLines: 3,
        ),
        _field(
          controller: _workingHours,
          label: 'ساعات العمل',
          icon: Icons.schedule,
        ),
        _field(
          controller: _description,
          label: 'وصف العيادة',
          icon: Icons.description_outlined,
          maxLines: 4,
        ),
      ],
    );
  }

  Widget _pharmacyFields() {
    return Column(
      children: [
        _field(
          controller: _address,
          label: 'عنوان الصيدلية',
          icon: Icons.location_on_outlined,
        ),
        _field(
          controller: _workingHours,
          label: 'ساعات العمل',
          icon: Icons.schedule,
        ),
        _field(
          controller: _description,
          label: 'وصف الصيدلية',
          icon: Icons.description_outlined,
          maxLines: 4,
        ),
      ],
    );
  }

  Future<void> _showChangePassword() async {
    final currentPassword =
    TextEditingController();

    final newPassword =
    TextEditingController();

    final confirmPassword =
    TextEditingController();

    bool loading = false;
    bool hideCurrent = true;
    bool hideNew = true;
    bool hideConfirm = true;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title:
              const Text('تغيير كلمة المرور'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize:
                  MainAxisSize.min,
                  children: [
                    TextField(
                      controller:
                      currentPassword,
                      obscureText: hideCurrent,
                      decoration: InputDecoration(
                        labelText:
                        'كلمة المرور الحالية',
                        prefixIcon:
                        const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            hideCurrent
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                          onPressed: () {
                            setDialogState(() {
                              hideCurrent =
                              !hideCurrent;
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller:
                      newPassword,
                      obscureText: hideNew,
                      decoration: InputDecoration(
                        labelText:
                        'كلمة المرور الجديدة',
                        prefixIcon:
                        const Icon(Icons.lock_reset),
                        suffixIcon: IconButton(
                          icon: Icon(
                            hideNew
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                          onPressed: () {
                            setDialogState(() {
                              hideNew = !hideNew;
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller:
                      confirmPassword,
                      obscureText: hideConfirm,
                      decoration: InputDecoration(
                        labelText:
                        'تأكيد كلمة المرور الجديدة',
                        prefixIcon:
                        const Icon(Icons.lock),
                        suffixIcon: IconButton(
                          icon: Icon(
                            hideConfirm
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                          onPressed: () {
                            setDialogState(() {
                              hideConfirm =
                              !hideConfirm;
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: loading
                      ? null
                      : () => Navigator.pop(
                    dialogContext,
                  ),
                  child: const Text('إلغاء'),
                ),
                FilledButton(
                  onPressed: loading
                      ? null
                      : () async {
                    if (currentPassword
                        .text.isEmpty) {
                      msg(
                        context,
                        'أدخل كلمة المرور الحالية',
                      );
                      return;
                    }

                    if (newPassword
                        .text.length <
                        6) {
                      msg(
                        context,
                        'كلمة المرور الجديدة يجب أن تكون 6 أحرف على الأقل',
                      );
                      return;
                    }

                    if (newPassword.text !=
                        confirmPassword
                            .text) {
                      msg(
                        context,
                        'كلمتا المرور غير متطابقتين',
                      );
                      return;
                    }

                    setDialogState(
                          () => loading = true,
                    );

                    try {
                      await _service
                          .changePassword(
                        currentPassword:
                        currentPassword
                            .text,
                        newPassword:
                        newPassword.text,
                      );

                      if (!mounted) return;

                      Navigator.pop(
                        dialogContext,
                      );

                      msg(
                        context,
                        'تم تغيير كلمة المرور بنجاح',
                      );
                    } catch (e) {
                      if (!mounted) return;

                      msg(
                        context,
                        _cleanError(e),
                      );

                      setDialogState(
                            () => loading =
                        false,
                      );
                    }
                  },
                  child: Text(
                    loading
                        ? 'جارٍ التغيير...'
                        : 'تغيير',
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    currentPassword.dispose();
    newPassword.dispose();
    confirmPassword.dispose();
  }

  Future<void> _showChangeEmail() async {
    final emailController =
    TextEditingController(
      text: _email,
    );

    final passwordController =
    TextEditingController();

    bool loading = false;
    bool hidePassword = true;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title:
              const Text('تغيير البريد الإلكتروني'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize:
                  MainAxisSize.min,
                  children: [
                    TextField(
                      controller:
                      emailController,
                      keyboardType:
                      TextInputType.emailAddress,
                      decoration:
                      const InputDecoration(
                        labelText:
                        'البريد الإلكتروني الجديد',
                        prefixIcon:
                        Icon(Icons.email_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller:
                      passwordController,
                      obscureText: hidePassword,
                      decoration: InputDecoration(
                        labelText:
                        'كلمة المرور الحالية',
                        prefixIcon:
                        const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            hidePassword
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                          onPressed: () {
                            setDialogState(() {
                              hidePassword =
                              !hidePassword;
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'سيتم إرسال رابط تحقق إلى البريد الجديد. '
                          'لن يتغير البريد حتى يتم فتح الرابط وتأكيده.',
                      style: TextStyle(
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: loading
                      ? null
                      : () => Navigator.pop(
                    dialogContext,
                  ),
                  child: const Text('إلغاء'),
                ),
                FilledButton(
                  onPressed: loading
                      ? null
                      : () async {
                    if (emailController
                        .text
                        .trim()
                        .isEmpty) {
                      msg(
                        context,
                        'أدخل البريد الإلكتروني الجديد',
                      );
                      return;
                    }

                    if (passwordController
                        .text
                        .isEmpty) {
                      msg(
                        context,
                        'أدخل كلمة المرور الحالية',
                      );
                      return;
                    }

                    setDialogState(
                          () => loading = true,
                    );

                    try {
                      await _service.changeEmail(
                        currentPassword:
                        passwordController
                            .text,
                        newEmail:
                        emailController
                            .text
                            .trim(),
                      );

                      if (!mounted) return;

                      Navigator.pop(
                        dialogContext,
                      );

                      msg(
                        context,
                        'تم إرسال رابط التحقق إلى البريد الجديد',
                      );
                    } catch (e) {
                      if (!mounted) return;

                      msg(
                        context,
                        _cleanError(e),
                      );

                      setDialogState(
                            () => loading =
                        false,
                      );
                    }
                  },
                  child: Text(
                    loading
                        ? 'جارٍ الإرسال...'
                        : 'إرسال رابط التحقق',
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    emailController.dispose();
    passwordController.dispose();
  }

  Future<void> _syncEmail() async {
    try {
      final synced =
      await _service.syncCurrentEmail();

      final currentEmail =
          _service.auth.currentUser?.email;

      if (!mounted) return;

      if (synced &&
          currentEmail != null) {
        setState(() {
          _email = currentEmail;
        });

        msg(
          context,
          'تم تحديث البريد الإلكتروني',
        );
      } else {
        msg(
          context,
          'لم يتم تأكيد البريد الجديد بعد',
        );
      }
    } catch (_) {
      if (!mounted) return;

      msg(
        context,
        'تعذر تحديث البريد الإلكتروني',
      );
    }
  }

  Widget _securitySection() {
    return Card(
      margin: const EdgeInsets.only(
        top: 8,
        bottom: 24,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.stretch,
          children: [
            const Text(
              'الأمان والحساب',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 14),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading:
              const Icon(Icons.email_outlined),
              title:
              const Text('البريد الإلكتروني'),
              subtitle: Text(
                _email.isEmpty
                    ? 'غير متوفر'
                    : _email,
              ),
              trailing:
              const Icon(Icons.edit_outlined),
              onTap: _showChangeEmail,
            ),
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading:
              const Icon(Icons.mark_email_read_outlined),
              title: const Text(
                'تأكيد تحديث البريد',
              ),
              subtitle: const Text(
                'اضغط هنا بعد فتح رابط التحقق المرسل إلى البريد الجديد',
              ),
              trailing:
              const Icon(Icons.refresh),
              onTap: _syncEmail,
            ),
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading:
              const Icon(Icons.lock_reset),
              title:
              const Text('تغيير كلمة المرور'),
              subtitle: const Text(
                'يجب إدخال كلمة المرور الحالية',
              ),
              trailing:
              const Icon(Icons.chevron_left),
              onTap: _showChangePassword,
            ),
          ],
        ),
      ),
    );
  }

  Widget _imageSection() {
    final hasImage =
        _imagePath != null &&
            File(_imagePath!).existsSync();

    return Column(
      children: [
        Stack(
          alignment: Alignment.bottomLeft,
          children: [
            CircleAvatar(
              radius: 58,
              backgroundColor:
              Theme.of(context)
                  .colorScheme
                  .primaryContainer,
              backgroundImage: hasImage
                  ? FileImage(
                File(_imagePath!),
              )
                  : null,
              child: hasImage
                  ? null
                  : Icon(
                _role == 'doctor'
                    ? Icons.medical_services
                    : _role == 'clinic'
                    ? Icons.local_hospital
                    : _role ==
                    'pharmacy'
                    ? Icons.local_pharmacy
                    : _role ==
                    'admin'
                    ? Icons
                    .admin_panel_settings
                    : Icons
                    .person,
                size: 55,
              ),
            ),
            Material(
              color: Theme.of(context)
                  .colorScheme
                  .primary,
              shape:
              const CircleBorder(),
              child: IconButton(
                onPressed: _pickImage,
                icon: const Icon(
                  Icons.camera_alt,
                  color: Colors.white,
                ),
                tooltip: 'تغيير الصورة',
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          _name.text.isEmpty
              ? 'الملف الشخصي'
              : _name.text,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Chip(
          label: Text(
            _roleName(_role),
          ),
        ),
        if (hasImage)
          TextButton.icon(
            onPressed: _removeImage,
            icon:
            const Icon(Icons.delete_outline),
            label:
            const Text('حذف الصورة'),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          title:
          const Text('الملف الشخصي'),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title:
        const Text('الملف الشخصي'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding:
            const EdgeInsets.all(20),
            children: [
              _imageSection(),

              const SizedBox(height: 20),

              _field(
                controller: _name,
                label: _role == 'clinic'
                    ? 'اسم العيادة'
                    : _role == 'pharmacy'
                    ? 'اسم الصيدلية'
                    : 'الاسم الكامل',
                icon: _role == 'clinic'
                    ? Icons.local_hospital_outlined
                    : _role == 'pharmacy'
                    ? Icons.local_pharmacy_outlined
                    : Icons.person_outline,
                required: true,
              ),

              _field(
                controller: _phone,
                label: 'رقم الهاتف',
                icon: Icons.phone_outlined,
                keyboardType:
                TextInputType.phone,
              ),

              if (_role == 'patient')
                _patientFields(),

              if (_role == 'doctor')
                _doctorFields(),

              if (_role == 'clinic')
                _clinicFields(),

              if (_role == 'pharmacy')
                _pharmacyFields(),

              const SizedBox(height: 6),

              BusyButton(
                _busy
                    ? 'جارٍ حفظ البيانات...'
                    : 'حفظ التعديلات',
                onPressed:
                _busy ? null : _saveProfile,
              ),

              const SizedBox(height: 16),

              _securitySection(),
            ],
          ),
        ),
      ),
    );
  }
}
