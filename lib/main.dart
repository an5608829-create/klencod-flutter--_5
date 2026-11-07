import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const TwistApp());
}

// ================= اسم المطور =================
const String developerName = "Mahmoud";
const String developerUsername = "@Mahmoud";

// ================= الألوان =================
class C {
  static const bg = Color(0xFF0F0F1A);
  static const card = Color(0xFF1A1A2E);
  static const primary = Color(0xFF6C63FF);
  static const accent = Color(0xFFFF6B9D);
  static const success = Color(0xFF00D68F);
  static const danger = Color(0xFFFF4757);
  static const warning = Color(0xFFFFC048);
  static const info = Color(0xFF48DBFB);
  static const text = Color(0xFFF5F5F7);
  static const dim = Color(0xFF8B8BA7);
}

// ================= App =================
class TwistApp extends StatelessWidget {
  const TwistApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Twist Music',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: C.bg,
        primaryColor: C.primary,
        colorScheme: const ColorScheme.dark(primary: C.primary, secondary: C.accent),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: C.card,
          hintStyle: const TextStyle(color: C.dim),
          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: C.primary.withOpacity(0.3)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: C.primary, width: 1.5),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: C.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      ),
      home: const LoginScreen(),
    );
  }
}

// ================= API =================
class TwistAPI {
  static const base = 'https://api.twistmena.com/music';
  String device = 'AP3A.240905.015.A2';
  String session = _uuid();
  String? token;
  String? accessToken;
  String? tgToken;
  String? phone;
  int balance = 0;
  int used = 0;

  static String _uuid() {
    final r = Random();
    String h(int n) => List.generate(n, (_) => r.nextInt(16).toRadixString(16)).join();
    return '${h(8)}-${h(4)}-${h(4)}-${h(4)}-${h(12)}';
  }

  Map<String, String> _headers() {
    final m = {
      'user-agent': 'Twist-Mobile/11.2.10 (Android; 15; Infinix X6885; music; ar-EG)',
      'app_version': '11.2.10',
      'channel': 'mobileapp',
      'platform': 'android',
      'accept': 'application/json',
      'accept-language': 'ar',
      'content-type': 'application/json',
      'device_id': device,
      'sessionid': session,
    };
    if (token != null) m['Authorization'] = 'Bearer $token';
    if (accessToken != null) m['access-token'] = accessToken!;
    if (tgToken != null) m['tg-token'] = tgToken!;
    return m;
  }

  String _fixPhone(String p) {
    p = p.trim().replaceAll(' ', '').replaceAll('+', '');
    if (p.startsWith('0')) return '20${p.substring(1)}';
    if (p.startsWith('20')) return p;
    return '20$p';
  }

  Future<bool> sendCode(String phoneInput) async {
    phone = _fixPhone(phoneInput);
    try {
      final r = await http.post(
        Uri.parse('$base/Dlogin/sendCode'),
        headers: _headers(),
        body: jsonEncode({'dial': phone}),
      );
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> verify(String code) async {
    try {
      final r = await http.post(
        Uri.parse('$base/Dlogin/verify'),
        headers: _headers(),
        body: jsonEncode({
          'dial': phone,
          'verifyCode': code,
          'socialServiceName': '',
          'socialServiceToken': '',
        }),
      );
      if (r.statusCode == 200) {
        final d = jsonDecode(r.body);
        token = d['token'];
        accessToken = d['accessToken'];
        tgToken = d['tgToken'];
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<int> getBalance({int retries = 3}) async {
    for (var i = 0; i < retries; i++) {
      try {
        final r = await http.get(
          Uri.parse('$base/user/loyalty/balance/details'),
          headers: _headers(),
        );
        if (r.statusCode == 200) {
          balance = (jsonDecode(r.body)['balance'] ?? 0) as int;
          return balance;
        }
      } catch (_) {}
      await Future.delayed(const Duration(seconds: 1));
    }
    return balance;
  }

  Future<List<Task>> fetchTasks() async {
    try {
      final r = await http.get(
        Uri.parse('$base/user/loyalty/achievements/v2'),
        headers: _headers(),
      );
      if (r.statusCode != 200) return [];
      final d = jsonDecode(r.body);
      final badges = (d['badges'] ?? []) as List;
      final out = <Task>[];
      for (final cat in badges) {
        final catName = (cat['name'] ?? cat['title'] ?? 'قسم').toString();
        for (final t in (cat['badges'] ?? []) as List) {
          out.add(Task.fromJson(t as Map<String, dynamic>, catName));
        }
      }
      return out;
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, dynamic>> claimTask(String id) async {
    try {
      final r = await http.post(
        Uri.parse('$base/loyalty/action/$id'),
        headers: _headers(),
      );
      return {'ok': r.statusCode == 200, 'msg': 'HTTP ${r.statusCode}'};
    } catch (e) {
      return {'ok': false, 'msg': e.toString()};
    }
  }

  Future<Map<String, dynamic>> redeem(String pid) async {
    const pkgs = {
      '1': 'EAND_50_UNITS_ID_9',
      '2': 'EAND_100_UNITS_ID_10',
      '3': 'EAND_150_UNITS_ID_11',
      '4': 'EAND_300_UNITS_ID_12',
      '5': 'EAND_500_UNITS_ID_13',
      '6': 'EAND_750_UNITS_ID_14',
      '7': 'EAND_1000_UNITS_ID_15',
    };
    const costs = {'1': 100, '2': 200, '3': 300, '4': 600, '5': 1000, '6': 1500, '7': 2000};
    const units = {'1': 50, '2': 100, '3': 150, '4': 300, '5': 500, '6': 750, '7': 1000};

    if (!pkgs.containsKey(pid)) {
      return {'ok': false, 'msg': 'باقة غير معروفة', 'before': balance, 'after': balance};
    }
    if (used + units[pid]! > 2000) {
      return {'ok': false, 'msg': 'تجاوزت الحد الشهري', 'before': balance, 'after': balance};
    }
    if (balance < costs[pid]!) {
      return {
        'ok': false,
        'msg': 'رصيدك مش كفاية. محتاج ${costs[pid]} وعندك $balance',
        'before': balance,
        'after': balance,
      };
    }

    final before = await getBalance();
    try {
      final r = await http.post(
        Uri.parse('$base/loyalty/redeem/${pkgs[pid]}'),
        headers: _headers(),
      );
      if (r.statusCode == 200) {
        used += units[pid]!;
        await Future.delayed(const Duration(seconds: 1));
        final after = await getBalance();
        return {'ok': true, 'msg': 'تم استبدال ${units[pid]} وحدة', 'before': before, 'after': after};
      }
      return {'ok': false, 'msg': 'فشل الاستبدال', 'before': before, 'after': before};
    } catch (e) {
      return {'ok': false, 'msg': e.toString(), 'before': before, 'after': before};
    }
  }
}

class Task {
  final String id;
  final String name;
  final String desc;
  final int points;
  final bool rewarded;
  final String category;

  Task({
    required this.id,
    required this.name,
    required this.desc,
    required this.points,
    required this.rewarded,
    required this.category,
  });

  factory Task.fromJson(Map<String, dynamic> j, String cat) {
    return Task(
      id: (j['id'] ?? '').toString(),
      name: (j['name'] ?? j['title'] ?? 'مهمة').toString(),
      desc: (j['description'] ?? '').toString(),
      points: (j['reward']?['points'] ?? 0) as int,
      rewarded: j['rewarded'] == true,
      category: cat,
    );
  }
}

class TaskResult {
  final Task task;
  final bool success;
  final int gain;
  final int newBalance;
  final String error;
  TaskResult({
    required this.task,
    required this.success,
    required this.gain,
    required this.newBalance,
    this.error = '',
  });
}

final api = TwistAPI();

// ================= شاشة الدخول =================
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phone = TextEditingController();
  final _code = TextEditingController();
  bool _sent = false;
  bool _loading = false;
  String? _err;

  Future<void> _send() async {
    setState(() {
      _loading = true;
      _err = null;
    });
    final ok = await api.sendCode(_phone.text);
    setState(() {
      _loading = false;
      _sent = ok;
      if (!ok) _err = 'فشل إرسال الكود، تأكد من الرقم والإنترنت';
    });
    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ تم إرسال الكود على ${api.phone}'),
          backgroundColor: C.success,
        ),
      );
    }
  }

  Future<void> _verify() async {
    setState(() {
      _loading = true;
      _err = null;
    });
    final ok = await api.verify(_code.text);
    if (!ok) {
      setState(() {
        _loading = false;
        _err = 'الكود غلط أو حصلت مشكلة';
      });
      return;
    }
    await api.getBalance();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const TasksScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(colors: [C.primary, C.accent]),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.music_note, size: 48, color: Colors.white),
                ),
                const SizedBox(height: 20),
                const Text('🎵 Twist Music',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('تسجيل الدخول',
                    style: TextStyle(color: C.dim, fontSize: 16)),
                const SizedBox(height: 10),
                // 👇 اسم المطور
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: C.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: C.primary.withOpacity(0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.person, size: 14, color: C.primary),
                      SizedBox(width: 6),
                      Text(
                        'المطور: $developerName',
                        style: TextStyle(
                          color: C.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: C.card,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: C.primary.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      TextField(
                        controller: _phone,
                        keyboardType: TextInputType.phone,
                        enabled: !_sent,
                        style: const TextStyle(color: C.text),
                        decoration: const InputDecoration(
                          hintText: '01123456789',
                          labelText: 'رقم الهاتف',
                          labelStyle: TextStyle(color: C.dim),
                          prefixIcon: Icon(Icons.phone, color: C.primary),
                        ),
                      ),
                      if (_sent) ...[
                        const SizedBox(height: 16),
                        TextField(
                          controller: _code,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          style: const TextStyle(color: C.text),
                          decoration: const InputDecoration(
                            hintText: '123456',
                            labelText: 'كود التحقق',
                            labelStyle: TextStyle(color: C.dim),
                            prefixIcon: Icon(Icons.lock, color: C.primary),
                            counterText: '',
                          ),
                        ),
                      ],
                      if (_err != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: C.danger.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: C.danger.withOpacity(0.5)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error, color: C.danger, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(_err!,
                                    style: const TextStyle(color: C.danger)),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _loading ? null : (_sent ? _verify : _send),
                          child: _loading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2),
                                )
                              : Text(_sent ? '🔐 تحقق' : '📱 إرسال الكود'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ================= شاشة المهام =================
class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});
  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  int before = 0;
  int after = 0;
  List<TaskResult> results = [];
  bool _loading = true;
  String _status = 'جاري التحضير...';

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    setState(() {
      _loading = true;
      results = [];
      _status = 'جاري قراءة الرصيد...';
    });

    before = await api.getBalance();

    setState(() => _status = 'جاري جلب المهام...');
    final tasks = await api.fetchTasks();
    final pending = tasks.where((t) => !t.rewarded).toList();

    if (pending.isEmpty) {
      after = api.balance;
      setState(() {
        _loading = false;
        _status = 'مفيش مهام متاحة';
      });
      return;
    }

    int acc = 0;
    for (int i = 0; i < pending.length; i++) {
      final t = pending[i];
      setState(() => _status = 'تنفيذ ${i + 1}/${pending.length}...');
      final res = await api.claimTask(t.id);
      if (res['ok'] == true) {
        await Future.delayed(const Duration(milliseconds: 500));
        final nb = await api.getBalance();
        int gain = nb - (before + acc);
        if (gain < 0) gain = 0;
        acc += gain;
        setState(() {
          results.add(TaskResult(task: t, success: true, gain: gain, newBalance: nb));
        });
      } else {
        setState(() {
          results.add(TaskResult(
            task: t,
            success: false,
            gain: 0,
            newBalance: api.balance,
            error: res['msg']?.toString() ?? '',
          ));
        });
      }
    }

    after = await api.getBalance();
    setState(() {
      _loading = false;
      _status = 'تم';
    });
  }

  int get total => results.where((r) => r.success).fold(0, (s, r) => s + r.gain);
  int get okCount => results.where((r) => r.success).length;
  int get failCount => results.where((r) => !r.success).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📋 تشغيل المهام'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Center(
              child: Text(
                developerName,
                style: const TextStyle(
                  color: C.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _run,
          ),
        ],
      ),
      body: SafeArea(
        child: _loading && results.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: C.primary),
                    const SizedBox(height: 20),
                    Text(_status, style: const TextStyle(color: C.dim)),
                  ],
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _balanceCard('💰 الرصيد قبل المهام', before, C.warning),
                    const SizedBox(height: 16),
                    ...results.map(_taskCard),
                    if (!_loading && results.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _summary(),
                    ],
                    if (!_loading) ...[
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.arrow_forward),
                        label: const Text('متابعة'),
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (_) => const ActionScreen()),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }

  Widget _balanceCard(String title, int v, Color color) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.25), C.card],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Icon(Icons.account_balance_wallet, color: color, size: 32),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: C.dim, fontSize: 13)),
              const SizedBox(height: 4),
              Text('$v كوينز',
                  style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _taskCard(TaskResult r) {
    final t = r.task;
    final color = r.success ? C.success : C.danger;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: C.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.5), width: 1.5),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.15), blurRadius: 14, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(17)),
            ),
            child: Row(
              children: [
                Icon(r.success ? Icons.check_circle : Icons.cancel,
                    color: color, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(t.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15, color: C.text)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: color, borderRadius: BorderRadius.circular(20)),
                  child: Text(
                    r.success ? '+${r.gain}' : 'فشلت',
                    style: const TextStyle(
                        color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.category, size: 16, color: C.dim),
                  const SizedBox(width: 6),
                  Text(t.category,
                      style: const TextStyle(color: C.dim, fontSize: 13)),
                ]),
                if (t.desc.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(t.desc, style: const TextStyle(color: C.dim, fontSize: 13)),
                ],
                const SizedBox(height: 10),
                Row(children: [
                  const Icon(Icons.card_giftcard, size: 16, color: C.warning),
                  const SizedBox(width: 6),
                  Text('المكافأة المتوقعة: +${t.points}',
                      style: const TextStyle(color: C.warning, fontSize: 13)),
                ]),
                if (r.success) ...[
                  const SizedBox(height: 6),
                  Row(children: [
                    const Icon(Icons.account_balance_wallet, size: 16, color: C.info),
                    const SizedBox(width: 6),
                    Text('رصيدك الآن: ${r.newBalance}',
                        style: const TextStyle(color: C.info, fontSize: 13)),
                  ]),
                ] else if (r.error.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(r.error, style: const TextStyle(color: C.danger, fontSize: 12)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summary() {
    final diff = after - before;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [C.primary.withOpacity(0.25), C.card],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: C.primary.withOpacity(0.6), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.summarize, color: C.primary),
            SizedBox(width: 10),
            Text('📊 ملخص النتائج',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: C.text)),
          ]),
          const SizedBox(height: 14),
          _row('✅ نجحت', '$okCount مهمة', C.success),
          _row('❌ فشلت', '$failCount مهمة', C.danger),
          _row('🎁 مجموع النقاط', '+$total كوينز', C.warning),
          const Divider(height: 24, color: C.dim),
          _row('💰 قبل المهام', '$before كوينز', C.warning),
          _row('💰 بعد المهام', '$after كوينز', C.info),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: (diff >= 0 ? C.success : C.danger).withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: (diff >= 0 ? C.success : C.danger).withOpacity(0.6)),
            ),
            child: Center(
              child: Text(
                diff >= 0 ? '📈 الفرق: +$diff كوينز' : '📉 الفرق: $diff كوينز',
                style: TextStyle(
                  color: diff >= 0 ? C.success : C.danger,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String l, String v, Color c) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(l, style: const TextStyle(color: C.dim)),
          Text(v, style: TextStyle(color: c, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

// ================= شاشة الخيارات =================
class ActionScreen extends StatefulWidget {
  const ActionScreen({super.key});
  @override
  State<ActionScreen> createState() => _ActionScreenState();
}

class _ActionScreenState extends State<ActionScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🎵 عايز تعمل إيه؟'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [C.primary, C.accent]),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(children: [
                  const Icon(Icons.account_balance_wallet,
                      color: Colors.white, size: 40),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('رصيدك الحالي',
                          style: TextStyle(color: Colors.white70, fontSize: 13)),
                      Text('${api.balance} كوينز',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ]),
              ),
              const SizedBox(height: 30),
              _btn(
                icon: Icons.card_giftcard,
                title: 'سحب',
                sub: 'استبدال الكوينز بوحدات',
                color: C.success,
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const RedeemScreen()),
                  );
                  setState(() {});
                },
              ),
              const SizedBox(height: 16),
              _btn(
                icon: Icons.refresh,
                title: 'إنجاز مهام مرة أخرى',
                sub: 'تنفيذ المهام المتاحة من جديد',
                color: C.info,
                onTap: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const TasksScreen()),
                  );
                },
              ),
              const Spacer(),
              // 👇 اسم المطور
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: C.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: C.primary.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.code, color: C.primary, size: 18),
                    SizedBox(width: 8),
                    Text('تطوير: ',
                        style: TextStyle(color: C.dim, fontSize: 13)),
                    Text(developerName,
                        style: TextStyle(
                            color: C.primary,
                            fontSize: 15,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (_) => false,
                  );
                },
                icon: const Icon(Icons.logout, color: C.danger),
                label: const Text('خروج', style: TextStyle(color: C.danger)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _btn({
    required IconData icon,
    required String title,
    required String sub,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: C.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.5), width: 1.5),
          boxShadow: [
            BoxShadow(color: color.withOpacity(0.2), blurRadius: 16, offset: const Offset(0, 6)),
          ],
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 30),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: C.text)),
                const SizedBox(height: 4),
                Text(sub, style: const TextStyle(color: C.dim, fontSize: 13)),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_ios, color: color, size: 18),
        ]),
      ),
    );
  }
}

// ================= شاشة السحب =================
class RedeemScreen extends StatefulWidget {
  const RedeemScreen({super.key});
  @override
  State<RedeemScreen> createState() => _RedeemScreenState();
}

class _RedeemScreenState extends State<RedeemScreen> {
  static const pkgs = [
    {'id': '1', 'u': 50, 'c': 100},
    {'id': '2', 'u': 100, 'c': 200},
    {'id': '3', 'u': 150, 'c': 300},
    {'id': '4', 'u': 300, 'c': 600},
    {'id': '5', 'u': 500, 'c': 1000},
    {'id': '6', 'u': 750, 'c': 1500},
    {'id': '7', 'u': 1000, 'c': 2000},
  ];

  bool _loading = false;

  Future<void> _do(String id) async {
    setState(() => _loading = true);
    final res = await api.redeem(id);
    setState(() => _loading = false);
    if (!mounted) return;

    final ok = res['ok'] == true;
    final b = res['before'] as int;
    final a = res['after'] as int;
    final diff = a - b;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: C.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Icon(ok ? Icons.check_circle : Icons.error,
              color: ok ? C.success : C.danger),
          const SizedBox(width: 10),
          Text(ok ? 'تم السحب' : 'فشل السحب',
              style: const TextStyle(color: C.text)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(res['msg']?.toString() ?? '',
                style: const TextStyle(color: C.text)),
            if (ok) ...[
              const SizedBox(height: 14),
              _r('💰 قبل السحب', '$b كوينز', C.warning),
              _r('💰 بعد السحب', '$a كوينز', C.info),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                decoration: BoxDecoration(
                  color: (diff < 0 ? C.danger : C.success).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  diff < 0 ? '📉 اتخصم: $diff كوينز' : '📈 الفرق: +$diff',
                  style: TextStyle(
                    color: diff < 0 ? C.danger : C.success,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('حسناً', style: TextStyle(color: C.primary)),
          ),
        ],
      ),
    ).then((_) => setState(() {}));
  }

  Widget _r(String l, String v, Color c) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(l, style: const TextStyle(color: C.dim)),
          Text(v, style: TextStyle(color: c, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🎁 سحب / استبدال'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [C.primary, C.accent]),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(children: [
                  const Icon(Icons.account_balance_wallet,
                      color: Colors.white, size: 32),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('رصيدك الحالي',
                          style: TextStyle(color: Colors.white70, fontSize: 13)),
                      Text('${api.balance} كوينز',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ]),
              ),
              const SizedBox(height: 20),
              ...pkgs.map((p) {
                final canAfford = api.balance >= (p['c'] as int);
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: C.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: canAfford
                          ? C.success.withOpacity(0.4)
                          : C.dim.withOpacity(0.2),
                    ),
                  ),
                  child: ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: (canAfford ? C.success : C.dim).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.card_giftcard,
                        color: canAfford ? C.success : C.dim,
                      ),
                    ),
                    title: Text(
                      '${p['u']} وحدة',
                      style: TextStyle(
                        color: canAfford ? C.text : C.dim,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      '${p['c']} كوينز',
                      style: TextStyle(
                        color: canAfford ? C.warning : C.dim,
                      ),
                    ),
                    trailing: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: C.primary),
                          )
                        : Icon(Icons.arrow_forward_ios,
                            color: canAfford ? C.primary : C.dim, size: 18),
                    onTap: (_loading || !canAfford) ? null : () => _do(p['id'] as String),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}