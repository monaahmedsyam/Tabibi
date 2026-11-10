import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/firebase_service.dart';
import '../widgets/common.dart';

final FirebaseFirestore db = FirebaseFirestore.instance;

class ClinicsScreen extends StatelessWidget {
  const ClinicsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('العيادات')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: db
            .collection('users')
            .where('role', isEqualTo: 'clinic')
            .where('status', isEqualTo: 'active')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const EmptyState('تعذر تحميل العيادات');
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.data!.docs.isEmpty) {
            return const EmptyState('لا توجد عيادات متاحة حاليًا');
          }

          return ListView(
            children: snapshot.data!.docs.map((doc) {
              final data = doc.data();
              return Card(
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.local_hospital),
                  ),
                  title: Text(data['name']?.toString() ?? ''),
                  subtitle: Text(data['phone']?.toString() ?? ''),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DoctorsForClinic(
                        clinicId: doc.id,
                        clinicName: data['name']?.toString() ?? '',
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

class DoctorsForClinic extends StatelessWidget {
  final String clinicId;
  final String clinicName;

  const DoctorsForClinic({
    super.key,
    required this.clinicId,
    required this.clinicName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(clinicName)),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: db
            .collection('users')
            .where('role', isEqualTo: 'doctor')
            .where('clinicId', isEqualTo: clinicId)
            .where('status', isEqualTo: 'active')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const EmptyState('تعذر تحميل الأطباء');
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.data!.docs.isEmpty) {
            return const EmptyState('لا يوجد أطباء مسجلون');
          }

          return ListView(
            children: snapshot.data!.docs.map((doc) {
              final data = doc.data();
              return Card(
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(data['name']?.toString() ?? ''),
                  subtitle: Text(data['specialty']?.toString() ?? ''),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AvailableSlots(
                        doctorId: doc.id,
                        doctorName: data['name']?.toString() ?? '',
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

class AvailableSlots extends StatelessWidget {
  final String doctorId;
  final String doctorName;

  const AvailableSlots({
    super.key,
    required this.doctorId,
    required this.doctorName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('مواعيد د. $doctorName')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: db
            .collection('slots')
            .where('doctorId', isEqualTo: doctorId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const EmptyState('تعذر تحميل المواعيد');
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs.where((doc) {
            final data = doc.data();
            final booked = (data['booked'] as num?)?.toInt() ?? 0;
            final capacity = (data['capacity'] as num?)?.toInt() ?? 0;
            return booked < capacity;
          }).toList();

          if (docs.isEmpty) return const EmptyState('لا توجد فترات متاحة');

          return ListView(
            children: docs.map((doc) {
              final data = doc.data();
              final booked = (data['booked'] as num?)?.toInt() ?? 0;
              final capacity = (data['capacity'] as num?)?.toInt() ?? 0;
              return Card(
                child: ListTile(
                  title: Text(data['date']?.toString() ?? ''),
                  subtitle: Text('المتاح: ${capacity - booked}'),
                  trailing: FilledButton(
                    onPressed: () async {
                      try {
                        await FirebaseService().book(
                          doc.id,
                          context.read<AuthProvider>().user!.uid,
                        );
                        if (context.mounted) msg(context, 'تم الحجز بنجاح');
                      } catch (error) {
                        if (context.mounted) {
                          msg(
                            context,
                            error.toString().replaceFirst('Exception: ', ''),
                          );
                        }
                      }
                    },
                    child: const Text('حجز'),
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

class MyAppointments extends StatelessWidget {
  const MyAppointments({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = context.read<AuthProvider>().user!.uid;
    return Scaffold(
      appBar: AppBar(title: const Text('مواعيدي')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: db
            .collection('appointments')
            .where('patientId', isEqualTo: uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const EmptyState('تعذر تحميل الحجوزات');
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.data!.docs.isEmpty) {
            return const EmptyState('لا توجد حجوزات');
          }

          return ListView(
            children: snapshot.data!.docs.map((doc) {
              final data = doc.data();
              final status = data['status']?.toString() ?? 'booked';
              return Card(
                child: ListTile(
                  title: Text(data['date']?.toString() ?? 'موعد'),
                  subtitle: Text(status == 'cancelled' ? 'ملغي' : 'محجوز'),
                  trailing: status == 'booked'
                      ? TextButton(
                          onPressed: () async {
                            try {
                              await FirebaseService().cancel(
                                doc.id,
                                data['slotId']?.toString() ?? '',
                              );
                              if (context.mounted) msg(context, 'تم إلغاء الموعد');
                            } catch (_) {
                              if (context.mounted) msg(context, 'تعذر إلغاء الموعد');
                            }
                          },
                          child: const Text('إلغاء'),
                        )
                      : null,
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

class PrescriptionsScreen extends StatelessWidget {
  const PrescriptionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = context.read<AuthProvider>().user!.uid;
    return Scaffold(
      appBar: AppBar(title: const Text('وصفاتي الإلكترونية')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: db
            .collection('prescriptions')
            .where('patientId', isEqualTo: uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const EmptyState('تعذر تحميل الوصفات');
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.data!.docs.isEmpty) {
            return const EmptyState('لا توجد وصفات');
          }

          return ListView(
            children: snapshot.data!.docs.map((doc) {
              final data = doc.data();
              final medications = (data['medications'] as List<dynamic>?) ?? [];
              return Card(
                child: ExpansionTile(
                  title: Text('وصفة - ${data['date']?.toString() ?? ''}'),
                  children: medications.map<Widget>((item) {
                    final medication = Map<String, dynamic>.from(item as Map);
                    return ListTile(
                      title: Text(medication['name']?.toString() ?? ''),
                      subtitle: Text(
                        '${medication['dosage']?.toString() ?? ''} • '
                        '${medication['duration']?.toString() ?? ''}',
                      ),
                      trailing: IconButton(
                        tooltip: 'البحث عن الدواء',
                        icon: const Icon(Icons.search),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MedicineSearch(
                              initial: medication['name']?.toString() ?? '',
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
class MedicineSearch extends StatefulWidget {
  final String initial;

  const MedicineSearch({
    super.key,
    this.initial = '',
  });

  @override
  State<MedicineSearch> createState() => _MedicineSearchState();
}

class _MedicineSearchState extends State<MedicineSearch> {
  late final TextEditingController _query;

  @override
  void initState() {
    super.initState();
    _query = TextEditingController(
      text: widget.initial,
    );
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final normalized =
    _query.text.trim().toLowerCase();

    return Scaffold(
      appBar: AppBar(
        title: const Text('البحث عن دواء'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _query,
              onChanged: (_) {
                setState(() {});
              },
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                labelText: 'اسم الدواء',
              ),
            ),
          ),

          Expanded(
            child: normalized.isEmpty
                ? const EmptyState(
              'اكتب اسم الدواء للبحث',
            )
                : StreamBuilder<
                QuerySnapshot<
                    Map<String, dynamic>>>(
              stream: db
                  .collection('inventory')
                  .where(
                'searchName',
                isEqualTo: normalized,
              )
                  .where(
                'available',
                isEqualTo: true,
              )
                  .snapshots(),
              builder: (
                  context,
                  snapshot,
                  ) {
                if (snapshot.hasError) {
                  return const EmptyState(
                    'تعذر تنفيذ البحث',
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(
                    child:
                    CircularProgressIndicator(),
                  );
                }

                if (snapshot
                    .data!.docs.isEmpty) {
                  return const EmptyState(
                    'الدواء غير متوفر في الصيدليات المسجلة',
                  );
                }

                return ListView(
                  padding:
                  const EdgeInsets.only(
                    bottom: 16,
                  ),
                  children: snapshot.data!.docs
                      .map(
                        (doc) {
                      final data =
                      doc.data();

                      final medicineName =
                          data['name']
                              ?.toString() ??
                              '-';

                      final pharmacyName =
                          data['pharmacyName']
                              ?.toString() ??
                              'صيدلية';

                      final price =
                          data['price']
                              ?.toString() ??
                              '-';

                      final phone =
                          data['phone']
                              ?.toString() ??
                              '-';

                      final address =
                          data['address']
                              ?.toString()
                              .trim() ??
                              '';

                      return Card(
                        child: Padding(
                          padding:
                          const EdgeInsets
                              .symmetric(
                            vertical: 6,
                          ),
                          child: ListTile(
                            leading:
                            const CircleAvatar(
                              child: Icon(
                                Icons
                                    .local_pharmacy,
                              ),
                            ),

                            // اسم الدواء
                            title: Text(
                              medicineName,
                              style:
                              const TextStyle(
                                fontWeight:
                                FontWeight.bold,
                                fontSize: 17,
                              ),
                            ),

                            subtitle: Padding(
                              padding:
                              const EdgeInsets
                                  .only(
                                top: 6,
                              ),
                              child: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment
                                    .start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons
                                            .local_pharmacy_outlined,
                                        size: 18,
                                      ),
                                      const SizedBox(
                                        width: 6,
                                      ),
                                      Expanded(
                                        child: Text(
                                          'الصيدلية: $pharmacyName',
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(
                                    height: 6,
                                  ),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons
                                            .payments_outlined,
                                        size: 18,
                                      ),
                                      const SizedBox(
                                        width: 6,
                                      ),
                                      Text(
                                        'السعر: $price',
                                      ),
                                    ],
                                  ),
                                  const SizedBox(
                                    height: 6,
                                  ),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons
                                            .phone_outlined,
                                        size: 18,
                                      ),
                                      const SizedBox(
                                        width: 6,
                                      ),
                                      Text(
                                        'الهاتف: $phone',
                                      ),
                                    ],
                                  ),
                                  const SizedBox(
                                    height: 6,
                                  ),
                                  Row(
                                    crossAxisAlignment:
                                    CrossAxisAlignment
                                        .start,
                                    children: [
                                      const Icon(
                                        Icons
                                            .location_on_outlined,
                                        size: 18,
                                      ),
                                      const SizedBox(
                                        width: 6,
                                      ),
                                      Expanded(
                                        child: Text(
                                          address
                                              .isNotEmpty
                                              ? 'المكان: $address'
                                              : 'المكان: غير محدد',
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
class DoctorsManage extends StatelessWidget {
  const DoctorsManage({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = context.read<AuthProvider>().user!.uid;
    return Scaffold(
      appBar: AppBar(title: const Text('إدارة الأطباء')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showDialog<void>(
          context: context,
          builder: (_) => const AddDoctorDialog(),
        ),
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: db
            .collection('users')
            .where('role', isEqualTo: 'doctor')
            .where('clinicId', isEqualTo: uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const EmptyState('تعذر تحميل الأطباء');
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data!.docs
              .where((doc) => doc.data()['status'] != 'removed')
              .toList();
          if (docs.isEmpty) return const EmptyState('أضف أول طبيب للعيادة');

          return ListView(
            children: docs.map((doc) {
              final data = doc.data();
              return Card(
                child: ListTile(
                  title: Text(data['name']?.toString() ?? ''),
                  subtitle: Text(data['specialty']?.toString() ?? ''),
                  trailing: IconButton(
                    tooltip: 'إزالة الطبيب',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () async {
                      try {
                        await doc.reference.update({'status': 'removed'});
                        if (context.mounted) msg(context, 'تمت إزالة الطبيب');
                      } catch (_) {
                        if (context.mounted) msg(context, 'تعذر إزالة الطبيب');
                      }
                    },
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

class AddDoctorDialog extends StatefulWidget {
  const AddDoctorDialog({super.key});

  @override
  State<AddDoctorDialog> createState() => _AddDoctorDialogState();
}

class _AddDoctorDialogState extends State<AddDoctorDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _specialty = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _specialty.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('إضافة طبيب'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _name,
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'هذا الحقل مطلوب'
                    : null,
                decoration: const InputDecoration(labelText: 'الاسم'),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                validator: (value) => value == null || !value.contains('@')
                    ? 'أدخل بريدًا صحيحًا'
                    : null,
                decoration: const InputDecoration(labelText: 'البريد'),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _password,
                obscureText: true,
                validator: (value) => value == null || value.length < 6
                    ? '6 أحرف على الأقل'
                    : null,
                decoration: const InputDecoration(labelText: 'كلمة المرور'),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _specialty,
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'هذا الحقل مطلوب'
                    : null,
                decoration: const InputDecoration(labelText: 'التخصص'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: _busy
              ? null
              : () async {
                  if (!_formKey.currentState!.validate()) return;
                  try {
                    setState(() => _busy = true);
                    final auth = context.read<AuthProvider>();
                    await FirebaseService().addDoctor({
                      'name': _name.text.trim(),
                      'email': _email.text.trim(),
                      'password': _password.text,
                      'specialty': _specialty.text.trim(),
                      'clinicId': auth.user!.uid,
                    });
                    if (mounted) Navigator.pop(context);
                  } catch (error) {
                    if (mounted) msg(context, 'تعذر إضافة الطبيب: $error');
                  } finally {
                    if (mounted) setState(() => _busy = false);
                  }
                },
          child: Text(_busy ? 'جارٍ الحفظ...' : 'حفظ'),
        ),
      ],
    );
  }
}

class SlotsManage extends StatefulWidget {
  const SlotsManage({super.key});

  @override
  State<SlotsManage> createState() => _SlotsManageState();
}

class _SlotsManageState extends State<SlotsManage> {
  String? _doctorId;
  final _date = TextEditingController();
  final _capacity = TextEditingController(text: '10');
  bool _busy = false;

  @override
  void dispose() {
    _date.dispose();
    _capacity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = context.read<AuthProvider>().user!.uid;
    return Scaffold(
      appBar: AppBar(title: const Text('الفترات الزمنية')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: db
                .collection('users')
                .where('clinicId', isEqualTo: uid)
                .where('role', isEqualTo: 'doctor')
                .where('status', isEqualTo: 'active')
                .snapshots(),
            builder: (context, snapshot) {
              final items = snapshot.data?.docs
                      .map(
                        (doc) => DropdownMenuItem<String>(
                          value: doc.id,
                          child: Text(doc.data()['name']?.toString() ?? ''),
                        ),
                      )
                      .toList() ??
                  <DropdownMenuItem<String>>[];
              return DropdownButtonFormField<String>(
                initialValue: _doctorId,
                decoration: const InputDecoration(labelText: 'الطبيب'),
                items: items,
                onChanged: (value) => setState(() => _doctorId = value),
              );
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _date,
            decoration: const InputDecoration(
              labelText: 'التاريخ والوقت (مثال: 2026-08-10 10:00)',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _capacity,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'السعة'),
          ),
          const SizedBox(height: 12),
          BusyButton(
            _busy ? 'جارٍ الإنشاء...' : 'إنشاء الفترة',
            onPressed: _busy
                ? null
                : () async {
                    if (_doctorId == null) {
                      msg(context, 'اختر الطبيب');
                      return;
                    }
                    if (_date.text.trim().isEmpty) {
                      msg(context, 'أدخل التاريخ والوقت');
                      return;
                    }
                    final capacity = int.tryParse(_capacity.text.trim());
                    if (capacity == null || capacity <= 0) {
                      msg(context, 'أدخل سعة صحيحة');
                      return;
                    }
                    try {
                      setState(() => _busy = true);
                      await FirebaseService().saveSlot({
                        'clinicId': uid,
                        'doctorId': _doctorId,
                        'date': _date.text.trim(),
                        'capacity': capacity,
                      });
                      if (mounted) {
                        _date.clear();
                        msg(context, 'تم إنشاء الفترة');
                      }
                    } catch (_) {
                      if (mounted) msg(context, 'تعذر إنشاء الفترة');
                    } finally {
                      if (mounted) setState(() => _busy = false);
                    }
                  },
          ),
          const SizedBox(height: 20),
          const Text(
            'الفترات الحالية',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: db.collection('slots').where('clinicId', isEqualTo: uid).snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const LinearProgressIndicator();
              if (snapshot.data!.docs.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('لا توجد فترات منشأة حتى الآن'),
                );
              }
              return Column(
                children: snapshot.data!.docs.map((doc) {
                  final data = doc.data();
                  return Card(
                    child: ListTile(
                      title: Text(data['date']?.toString() ?? ''),
                      subtitle: Text(
                        'السعة: ${data['capacity'] ?? 0} • المحجوز: ${data['booked'] ?? 0}',
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => doc.reference.delete(),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class ClinicBookings extends StatelessWidget {
  const ClinicBookings({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = context.read<AuthProvider>().user!.uid;
    return AppointmentList(
      title: 'حجوزات العيادة',
      field: 'clinicId',
      uid: uid,
    );
  }
}

class DoctorAppointments extends StatelessWidget {
  const DoctorAppointments({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = context.read<AuthProvider>().user!.uid;
    return AppointmentList(
      title: 'جدول المواعيد والمرضى',
      field: 'doctorId',
      uid: uid,
    );
  }
}

class AppointmentList extends StatelessWidget {
  final String title;
  final String field;
  final String uid;

  const AppointmentList({
    super.key,
    required this.title,
    required this.field,
    required this.uid,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: db.collection('appointments').where(field, isEqualTo: uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const EmptyState('تعذر تحميل المواعيد');
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.data!.docs.isEmpty) {
            return const EmptyState('لا توجد مواعيد');
          }

          return ListView(
            children: snapshot.data!.docs.map((doc) {
              final data = doc.data();
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.event),
                  title: Text(data['date']?.toString() ?? ''),
                  subtitle: Text(
                    'المريض: ${data['patientId']?.toString() ?? '-'} • '
                    '${data['status']?.toString() ?? '-'}',
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

class CreatePrescription extends StatefulWidget {
  const CreatePrescription({super.key});

  @override
  State<CreatePrescription> createState() => _CreatePrescriptionState();
}

class _CreatePrescriptionState extends State<CreatePrescription> {
  String? _patientId;
  final List<_MedicationInput> _medications = [_MedicationInput()];
  bool _busy = false;

  @override
  void dispose() {
    for (final item in _medications) {
      item.dispose();
    }
    super.dispose();
  }

  void _addMedication() {
    setState(() => _medications.add(_MedicationInput()));
  }

  void _removeMedication(int index) {
    if (_medications.length == 1) return;
    final item = _medications.removeAt(index);
    item.dispose();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final doctorId = context.read<AuthProvider>().user!.uid;
    return Scaffold(
      appBar: AppBar(title: const Text('إصدار وصفة إلكترونية')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: db
                .collection('appointments')
                .where('doctorId', isEqualTo: doctorId)
                .snapshots(),
            builder: (context, snapshot) {
              final patientIds = <String>{};
              for (final doc in snapshot.data?.docs ??
                  <QueryDocumentSnapshot<Map<String, dynamic>>>[]) {
                final id = doc.data()['patientId']?.toString();
                if (id != null && id.isNotEmpty) patientIds.add(id);
              }
              return DropdownButtonFormField<String>(
                initialValue: patientIds.contains(_patientId) ? _patientId : null,
                decoration: const InputDecoration(labelText: 'المريض'),
                items: patientIds
                    .map(
                      (id) => DropdownMenuItem<String>(
                        value: id,
                        child: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                          future: db.collection('users').doc(id).get(),
                          builder: (context, userSnapshot) {
                            final name = userSnapshot.data?.data()?['name']?.toString();
                            return Text(name?.isNotEmpty == true ? name! : id);
                          },
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _patientId = value),
              );
            },
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < _medications.length; i++)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'الدواء ${i + 1}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        if (_medications.length > 1)
                          IconButton(
                            onPressed: () => _removeMedication(i),
                            icon: const Icon(Icons.close),
                          ),
                      ],
                    ),
                    TextField(
                      controller: _medications[i].name,
                      decoration: const InputDecoration(labelText: 'اسم الدواء'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _medications[i].dosage,
                      decoration: const InputDecoration(labelText: 'الجرعة والتعليمات'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _medications[i].duration,
                      decoration: const InputDecoration(labelText: 'مدة العلاج'),
                    ),
                  ],
                ),
              ),
            ),
          TextButton.icon(
            onPressed: _addMedication,
            icon: const Icon(Icons.add),
            label: const Text('إضافة دواء آخر'),
          ),
          const SizedBox(height: 10),
          BusyButton(
            _busy ? 'جارٍ إصدار الوصفة...' : 'إصدار الوصفة',
            onPressed: _busy
                ? null
                : () async {
                    if (_patientId == null) {
                      msg(context, 'اختر المريض');
                      return;
                    }
                    final medicines = _medications
                        .where((item) => item.name.text.trim().isNotEmpty)
                        .map(
                          (item) => {
                            'name': item.name.text.trim(),
                            'dosage': item.dosage.text.trim(),
                            'duration': item.duration.text.trim(),
                          },
                        )
                        .toList();
                    if (medicines.isEmpty) {
                      msg(context, 'أدخل دواءً واحدًا على الأقل');
                      return;
                    }
                    try {
                      setState(() => _busy = true);
                      await FirebaseService().prescription({
                        'patientId': _patientId,
                        'doctorId': doctorId,
                        'date': DateTime.now().toIso8601String().substring(0, 10),
                        'medications': medicines,
                      });
                      if (mounted) msg(context, 'تم إصدار الوصفة');
                    } catch (_) {
                      if (mounted) msg(context, 'تعذر إصدار الوصفة');
                    } finally {
                      if (mounted) setState(() => _busy = false);
                    }
                  },
          ),
        ],
      ),
    );
  }
}

class _MedicationInput {
  final name = TextEditingController();
  final dosage = TextEditingController();
  final duration = TextEditingController();

  void dispose() {
    name.dispose();
    dosage.dispose();
    duration.dispose();
  }
}
class InventoryManage extends StatefulWidget {
  const InventoryManage({super.key});

  @override
  State<InventoryManage> createState() =>
      _InventoryManageState();
}

class _InventoryManageState
    extends State<InventoryManage> {
  Future<void> _showMedicineDialog(
      BuildContext context,
      String pharmacyId,
      String pharmacyName,
      String phone, {
        DocumentSnapshot<Map<String, dynamic>>?
        existing,
      }) async {
    final name = TextEditingController(
      text:
      existing?.data()?['name']?.toString() ??
          '',
    );

    final price = TextEditingController(
      text:
      existing?.data()?['price']?.toString() ??
          '',
    );

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            existing == null
                ? 'إضافة دواء'
                : 'تعديل الدواء',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration:
                const InputDecoration(
                  labelText: 'اسم الدواء',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: price,
                keyboardType:
                const TextInputType
                    .numberWithOptions(
                  decimal: true,
                ),
                decoration:
                const InputDecoration(
                  labelText: 'السعر',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () async {
                final cleanName =
                name.text.trim();

                final parsedPrice =
                double.tryParse(
                  price.text.trim(),
                );

                if (cleanName.isEmpty ||
                    parsedPrice == null ||
                    parsedPrice < 0) {
                  msg(
                    dialogContext,
                    'أدخل اسم الدواء والسعر بشكل صحيح',
                  );
                  return;
                }

                try {
                  // جلب أحدث بيانات الصيدلية
                  final pharmacyDoc = await db
                      .collection('users')
                      .doc(pharmacyId)
                      .get();

                  final pharmacyData =
                  pharmacyDoc.data();

                  final currentPharmacyName =
                      pharmacyData?['name']
                          ?.toString()
                          .trim() ??
                          pharmacyName;

                  final currentPhone =
                      pharmacyData?['phone']
                          ?.toString()
                          .trim() ??
                          phone;

                  final address =
                      pharmacyData?['address']
                          ?.toString()
                          .trim() ??
                          '';

                  final values =
                  <String, dynamic>{
                    'pharmacyId':
                    pharmacyId,
                    'pharmacyName':
                    currentPharmacyName,
                    'phone':
                    currentPhone,

                    // عنوان الصيدلية
                    'address':
                    address,

                    'name':
                    cleanName,
                    'searchName':
                    cleanName
                        .toLowerCase(),
                    'price':
                    parsedPrice,
                    'available':
                    existing?.data()?[
                    'available'] ??
                        true,
                  };

                  if (existing == null) {
                    await FirebaseService()
                        .inventory(values);
                  } else {
                    await existing.reference
                        .update(values);
                  }

                  if (!dialogContext.mounted) {
                    return;
                  }

                  Navigator.pop(
                    dialogContext,
                  );

                  msg(
                    context,
                    existing == null
                        ? 'تمت إضافة الدواء'
                        : 'تم تعديل الدواء',
                  );
                } catch (_) {
                  if (!dialogContext.mounted) {
                    return;
                  }

                  msg(
                    dialogContext,
                    'تعذر حفظ بيانات الدواء',
                  );
                }
              },
              child: const Text('حفظ'),
            ),
          ],
        );
      },
    );

    name.dispose();
    price.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth =
    context.read<AuthProvider>();

    final uid =
        auth.user!.uid;

    final pharmacyName =
        auth.profile?.name ?? '';

    final phone =
        auth.profile?.phone ?? '';

    return Scaffold(
      appBar: AppBar(
        title:
        const Text('مخزون الأدوية'),
      ),
      floatingActionButton:
      FloatingActionButton(
        onPressed: () {
          _showMedicineDialog(
            context,
            uid,
            pharmacyName,
            phone,
          );
        },
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<
          QuerySnapshot<Map<String, dynamic>>>(
        stream: db
            .collection('inventory')
            .where(
          'pharmacyId',
          isEqualTo: uid,
        )
            .snapshots(),
        builder: (
            context,
            snapshot,
            ) {
          if (snapshot.hasError) {
            return const EmptyState(
              'تعذر تحميل المخزون',
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child:
              CircularProgressIndicator(),
            );
          }

          if (snapshot.data!.docs.isEmpty) {
            return const EmptyState(
              'المخزون فارغ',
            );
          }

          return ListView(
            children:
            snapshot.data!.docs.map(
                  (doc) {
                final data =
                doc.data();

                final address =
                    data['address']
                        ?.toString()
                        .trim() ??
                        '';

                return Card(
                  child: ListTile(
                    title: Text(
                      data['name']
                          ?.toString() ??
                          '',
                    ),
                    subtitle: Text(
                      'السعر: ${data['price']?.toString() ?? '-'}'
                          '${address.isNotEmpty ? '\nالمكان: $address' : ''}',
                    ),
                    leading: Switch(
                      value:
                      data['available'] ==
                          true,
                      onChanged: (value) {
                        doc.reference.update({
                          'available':
                          value,
                        });
                      },
                    ),
                    trailing:
                    PopupMenuButton<
                        String>(
                      onSelected: (value) {
                        if (value ==
                            'edit') {
                          _showMedicineDialog(
                            context,
                            uid,
                            pharmacyName,
                            phone,
                            existing: doc,
                          );
                        } else if (value ==
                            'delete') {
                          doc.reference
                              .delete();
                        }
                      },
                      itemBuilder: (_) =>
                      const [
                        PopupMenuItem(
                          value: 'edit',
                          child:
                          Text('تعديل'),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child:
                          Text('حذف'),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ).toList(),
          );
        },
      ),
    );
  }
}

class JoinRequests extends StatelessWidget {
  const JoinRequests({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('طلبات الانضمام')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: db
            .collection('join_requests')
            .where('status', isEqualTo: 'pending')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const EmptyState('تعذر تحميل الطلبات');
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.data!.docs.isEmpty) {
            return const EmptyState('لا توجد طلبات معلقة');
          }

          return ListView(
            children: snapshot.data!.docs.map((doc) {
              final data = doc.data();
              final role = data['role'] == 'clinic' ? 'عيادة' : 'صيدلية';
              return Card(
                child: ListTile(
                  title: Text(data['name']?.toString() ?? ''),
                  subtitle: Text('$role • ${data['email']?.toString() ?? ''}'),
                  trailing: Wrap(
                    spacing: 4,
                    children: [
                      IconButton(
                        tooltip: 'قبول',
                        icon: const Icon(Icons.check),
                        onPressed: () async {
                          await FirebaseService().review(doc.id, true);
                          if (context.mounted) msg(context, 'تم قبول الطلب');
                        },
                      ),
                      IconButton(
                        tooltip: 'رفض',
                        icon: const Icon(Icons.close),
                        onPressed: () async {
                          await FirebaseService().review(doc.id, false);
                          if (context.mounted) msg(context, 'تم رفض الطلب');
                        },
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

class UsersManage extends StatelessWidget {
  const UsersManage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('المستخدمون')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: db.collection('users').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const EmptyState('تعذر تحميل المستخدمين');
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.data!.docs.isEmpty) {
            return const EmptyState('لا يوجد مستخدمون');
          }

          return ListView(
            children: snapshot.data!.docs.map((doc) {
              final data = doc.data();
              return Card(
                child: ListTile(
                  title: Text(data['name']?.toString() ?? ''),
                  subtitle: Text(
                    '${data['role']?.toString() ?? '-'} • '
                    '${data['status']?.toString() ?? '-'}',
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) => doc.reference.update({'status': value}),
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'active', child: Text('تفعيل')),
                      PopupMenuItem(value: 'suspended', child: Text('تعليق')),
                    ],
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  Future<List<int>> _loadCounts() async {
    final collections = ['users', 'appointments', 'prescriptions', 'inventory'];
    final result = <int>[];
    for (final collection in collections) {
      final snapshot = await db.collection(collection).count().get();
      result.add(snapshot.count ?? 0);
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    const names = ['المستخدمون', 'المواعيد', 'الوصفات', 'سجلات الأدوية'];
    return Scaffold(
      appBar: AppBar(title: const Text('إحصاءات المنصة')),
      body: FutureBuilder<List<int>>(
        future: _loadCounts(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const EmptyState('تعذر تحميل الإحصاءات');
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return GridView.count(
            crossAxisCount: MediaQuery.sizeOf(context).width > 600 ? 4 : 2,
            padding: const EdgeInsets.all(16),
            children: [
              for (var i = 0; i < names.length; i++)
                Card(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${snapshot.data![i]}',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(names[i]),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
