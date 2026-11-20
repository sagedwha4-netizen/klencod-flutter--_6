imprt 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(DhikriApp(prefs: prefs));
}

class DhikriApp extends StatelessWidget {
  const DhikriApp({super.key, required this.prefs});
  final SharedPreferences prefs;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'ذكري | Dhikri',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4F8C78)),
      scaffoldBackgroundColor: const Color(0xFFEAF2EE),
    ),
    home: Directionality(textDirection: TextDirection.rtl, child: DhikriHome(prefs: prefs)),
  );
}

class Dhikr { const Dhikr(this.name, this.target); final String name; final int target; }
const dhikrs = [
  Dhikr('سبحان الله', 33), Dhikr('الحمد لله', 33), Dhikr('الله أكبر', 34),
  Dhikr('أستغفر الله', 100), Dhikr('لا إله إلا الله', 100),
  Dhikr('اللهم صلِّ على محمد', 100),
];

class DhikriHome extends StatefulWidget {
  const DhikriHome({super.key, required this.prefs});
  final SharedPreferences prefs;
  @override
  State<DhikriHome> createState() => _DhikriHomeState();
}

class _DhikriHomeState extends State<DhikriHome> with SingleTickerProviderStateMixin {
  int tab = 0, selected = 0, count = 0, today = 0, total = 0, sessions = 0;
  bool haptics = true;
  late final AnimationController pulse = AnimationController(
    vsync: this, duration: const Duration(milliseconds: 130), lowerBound: 0, upperBound: .06);
  late final Animation<double> scale = Tween(begin: 1.0, end: 1.06)
      .animate(CurvedAnimation(parent: pulse, curve: Curves.easeOut));

  String get dateKey {
    final d = DateTime.now();
    return '${d.year}-${d.month}-${d.day}';
  }

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    final p = widget.prefs;
    final newDay = p.getString('date') != dateKey;
    if (newDay) { await p.setInt('today', 0); await p.setString('date', dateKey); }
    if (!mounted) return;
    setState(() {
      count = p.getInt('count') ?? 0;
      selected = (p.getInt('selected') ?? 0).clamp(0, dhikrs.length - 1).toInt();
      today = newDay ? 0 : (p.getInt('today') ?? 0);
      total = p.getInt('total') ?? 0;
      sessions = p.getInt('sessions') ?? 0;
      haptics = p.getBool('haptics') ?? true;
    });
  }

  Future<void> save() async {
    final p = widget.prefs;
    await p.setInt('count', count); await p.setInt('selected', selected);
    await p.setInt('today', today); await p.setInt('total', total);
    await p.setInt('sessions', sessions); await p.setBool('haptics', haptics);
    await p.setString('date', dateKey);
  }

  void increment() {
    if (count >= dhikrs[selected].target) return;
    setState(() { count++; today++; total++; });
    pulse.forward(from: 0).then((_) { if (mounted) pulse.reverse(); });
    if (haptics) HapticFeedback.selectionClick();
    save();
    if (count == dhikrs[selected].target) {
      setState(() => sessions++);
      save();
      Future.delayed(const Duration(milliseconds: 180), () { if (mounted) completionDialog(); });
    }
  }

  void completionDialog() {
    showDialog<void>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('أحسنت! اكتمل الذكر', textAlign: TextAlign.center),
      content: const Text('تقبّل الله منك، وبارك لك في ذكرك.', textAlign: TextAlign.center),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق')),
        FilledButton(onPressed: () { Navigator.pop(ctx); setState(() => count = 0); save(); },
          child: const Text('ذكر جديد')),
      ],
    ));
  }

  void reset() {
    showDialog<void>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('إعادة العداد؟'),
      content: const Text('سيتم تصفير العداد الحالي فقط، ولن تُحذف الإحصائيات.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
        FilledButton(onPressed: () { Navigator.pop(ctx); setState(() => count = 0); save(); },
          child: const Text('إعادة')),
      ],
    ));
  }

  @override
  void dispose() { pulse.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final pages = [tasbeehPage(), achievementsPage(), statsPage(), settingsPage()];
    return Scaffold(
      body: Stack(children: [
        const SoftBackground(),
        SafeArea(child: Column(children: [
          header(),
          Expanded(child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 240),
            child: KeyedSubtree(key: ValueKey(tab), child: pages[tab]))),
          navigation(),
        ])),
      ]),
    );
  }

  Widget header() => Padding(
    padding: const EdgeInsets.fromLTRB(22, 12, 22, 8),
    child: Row(children: [
      Container(width: 45, height: 45, decoration: BoxDecoration(
        color: Colors.white.withOpacity(.7), borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.spa_rounded, color: Color(0xFF4F8C78))),
      const SizedBox(width: 12),
      const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('ذكري', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
        Text('Dhikri • ذكرٌ وطمأنينة', style: TextStyle(fontSize: 11, color: Color(0xFF71867D))),
      ])),
      const Icon(Icons.wb_sunny_outlined, color: Color(0xFF78978A)),
    ]),
  );

  Widget tasbeehPage() {
    final item = dhikrs[selected];
    final progress = (count / item.target).clamp(0.0, 1.0);
    return ListView(padding: const EdgeInsets.fromLTRB(20, 12, 20, 18), children: [
      Glass(child: Column(children: [
        const Text('ذِكرُك الآن', style: TextStyle(color: Color(0xFF71867D))),
        DropdownButton<int>(
          value: selected, isExpanded: true, alignment: Alignment.center,
          underline: const SizedBox(), borderRadius: BorderRadius.circular(16),
          items: List.generate(dhikrs.length, (i) => DropdownMenuItem(
            value: i, child: Center(child: Text(dhikrs[i].name,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))))),
          onChanged: (v) { if (v != null) setState(() { selected = v; count = 0; }); save(); },
        ),
        Text('الهدف: ${item.target} مرة', style: const TextStyle(fontSize: 12, color: Color(0xFF82958D))),
      ])),
      const SizedBox(height: 24),
      Center(child: GestureDetector(onTap: increment, child: ScaleTransition(scale: scale,
        child: SizedBox(width: 252, height: 252, child: Stack(alignment: Alignment.center, children: [
          SizedBox.expand(child: CircularProgressIndicator(value: progress, strokeWidth: 7,
            strokeCap: StrokeCap.round, backgroundColor: Colors.white.withOpacity(.7),
            valueColor: const AlwaysStoppedAnimation(Color(0xFF4F8C78)))),
          Container(width: 224, height: 224, decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [Colors.white.withOpacity(.92), const Color(0xFFDCEBE3).withOpacity(.82)]),
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [BoxShadow(color: const Color(0xFF719A87).withOpacity(.17),
              blurRadius: 26, offset: const Offset(0, 10))]),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Text('عدد التسبيحات', style: TextStyle(color: Color(0xFF789087))),
              Text('$count', style: const TextStyle(fontSize: 64, fontWeight: FontWeight.w800,
                color: Color(0xFF315F50), height: 1.15)),
              Text('من ${item.target}', style: const TextStyle(color: Color(0xFF82958D))),
              const SizedBox(height: 7),
              const Text('اضغط للتسبيح', style: TextStyle(fontSize: 12, color: Color(0xFF4F8C78))),
            ])),
          if (count >= item.target) const Positioned(top: 22,
            child: Icon(Icons.check_circle, color: Color(0xFFC59B52), size: 30)),
        ]))))),
      const SizedBox(height: 22),
      Row(children: [
        Expanded(child: statCard('إنجاز اليوم', '$today', Icons.today_rounded)),
        const SizedBox(width: 10),
        Expanded(child: statCard('جلسات مكتملة', '$sessions', Icons.verified_rounded)),
      ]),
      const SizedBox(height: 17),
      Row(children: [
        Expanded(child: OutlinedButton.icon(onPressed: reset, icon: const Icon(Icons.refresh),
          label: const Text('إعادة العداد'), style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF527B6B), padding: const EdgeInsets.symmetric(vertical: 13)))),
        const SizedBox(width: 10),
        Expanded(child: FilledButton.icon(onPressed: increment, icon: const Icon(Icons.touch_app),
          label: const Text('سبّح الآن'), style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF4F8C78), padding: const EdgeInsets.symmetric(vertical: 13)))),
      ]),
      const SizedBox(height: 10),
      const Text('تُحفظ أعدادك على هذا الجهاز تلقائيًا',
        textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: Color(0xFF879A91))),
    ]);
  }

  Widget statCard(String title, String value, IconData icon) => Glass(child: Row(children: [
    Icon(icon, color: const Color(0xFF67917F)), const SizedBox(width: 8),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontSize: 10, color: Color(0xFF81948B))),
      Text(value, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
    ])),
  ]));

  Widget achievementsPage() {
    final achievements = [
      Achievement('أول خطوة', 'أكمل أول جلسة ذكر', Icons.spa_rounded, sessions >= 1),
      Achievement('مواظب', 'أكمل 5 جلسات ذكر', Icons.local_fire_department, sessions >= 5),
      Achievement('صاحب الهمة', 'أكمل 10 جلسات ذكر', Icons.auto_awesome, sessions >= 10),
      Achievement('ألف ذكر', 'اجمع 1000 تسبيحة', Icons.star_rounded, total >= 1000),
      Achievement('خمسة آلاف', 'اجمع 5000 تسبيحة', Icons.workspace_premium, total >= 5000),
    ];
    final unlocked = achievements.where((a) => a.done).length;
    return ListView(padding: const EdgeInsets.all(20), children: [
      const Text('إنجازاتك', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800)),
      const SizedBox(height: 5),
      Text('إنجازاتك المحققة: $unlocked من ${achievements.length}',
        style: const TextStyle(color: Color(0xFF71867D))),
      const SizedBox(height: 16),
      ClipRRect(borderRadius: BorderRadius.circular(20), child: LinearProgressIndicator(
        value: unlocked / achievements.length, minHeight: 9, backgroundColor: Colors.white,
        color: const Color(0xFF4F8C78))),
      const SizedBox(height: 18),
      ...achievements.map((a) => Padding(padding: const EdgeInsets.only(bottom: 12),
        child: Glass(child: Row(children: [
          AnimatedContainer(duration: const Duration(milliseconds: 300), width: 50, height: 50,
            decoration: BoxDecoration(color: a.done ? const Color(0xFFE8DDBF) : Colors.white70,
              borderRadius: BorderRadius.circular(16)),
            child: Icon(a.icon, color: a.done ? const Color(0xFFAD8744) : Colors.grey)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(a.title, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(a.description, style: const TextStyle(fontSize: 12, color: Color(0xFF81948B))),
          ])),
          Icon(a.done ? Icons.check_circle : Icons.lock_outline,
            color: a.done ? const Color(0xFF4F8C78) : Colors.grey),
        ])))),
      const SizedBox(height: 8),
      const Text('الإنجازات تشجيع بصري داخل التطبيق، ولا تعبّر عن مقدار الثواب أو الأجر.',
        textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: Color(0xFF82958D))),
    ]);
  }

  Widget statsPage() => ListView(padding: const EdgeInsets.all(20), children: [
    const Text('إحصائياتي', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800)),
    const SizedBox(height: 8),
    const Text('ملخص نشاطك المحفوظ على هذا الجهاز',
      style: TextStyle(color: Color(0xFF71867D))),
    const SizedBox(height: 18),
    statLine('إجمالي التسبيحات', '$total', Icons.all_inclusive),
    const SizedBox(height: 12), statLine('تسبيحات اليوم', '$today', Icons.today),
    const SizedBox(height: 12), statLine('الجلسات المكتملة', '$sessions', Icons.task_alt),
    const SizedBox(height: 18),
    const Glass(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('تذكير لطيف', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
      SizedBox(height: 8),
      Text('القليل الدائم خير من الكثير المنقطع. اجعل لك وردًا يسيرًا تستطيع المحافظة عليه.',
        style: TextStyle(height: 1.7, color: Color(0xFF637A70))),
    ])),
  ]);

  Widget statLine(String title, String value, IconData icon) => Glass(child: Row(children: [
    Icon(icon, color: const Color(0xFF4F8C78), size: 28), const SizedBox(width: 13),
    Expanded(child: Text(title, style: const TextStyle(color: Color(0xFF71867D)))),
    Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
  ]));

  Widget settingsPage() => ListView(padding: const EdgeInsets.all(20), children: [
    const Text('الإعدادات', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800)),
    const SizedBox(height: 18),
    Glass(child: SwitchListTile(
      value: haptics, activeColor: const Color(0xFF4F8C78),
      title: const Text('اهتزاز خفيف عند التسبيح'),
      subtitle: const Text('يمكنك إيقافه لتجربة صامتة'),
      secondary: const Icon(Icons.vibration, color: Color(0xFF4F8C78)),
      onChanged: (v) { setState(() => haptics = v); save(); })),
    const SizedBox(height: 12),
    const Glass(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('عن ذكري', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
      SizedBox(height: 8),
      Text('ذكري مسبحة إلكترونية بسيطة تعمل دون حساب أو اتصال بالإنترنت. تحفظ بياناتك محليًا على جهازك.',
        style: TextStyle(height: 1.7, color: Color(0xFF637A70))),
      SizedBox(height: 8),
      Text('الإصدار 1.0.0', style: TextStyle(fontSize: 11, color: Color(0xFF82958D))),
    ])),
    const SizedBox(height: 12),
    OutlinedButton.icon(onPressed: () => showDialog<void>(context: context,
      builder: (ctx) => AlertDialog(title: const Text('حفظ البيانات'),
        content: const Text('لا يوجد حساب أو مزامنة سحابية. حذف التطبيق أو مسح بياناته قد يؤدي إلى فقدان الإحصائيات.'),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('حسنًا'))])),
      icon: const Icon(Icons.info_outline), label: const Text('معلومات حفظ البيانات')),
  ]);

  Widget navigation() {
    const labels = ['المسبحة', 'الإنجازات', 'إحصائياتي', 'الإعدادات'];
    const icons = [Icons.circle_outlined, Icons.emoji_events_outlined,
      Icons.bar_chart_rounded, Icons.tune_rounded];
    return Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Glass(padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 5),
        child: Row(children: List.generate(4, (i) => Expanded(child: InkWell(
          borderRadius: BorderRadius.circular(15), onTap: () => setState(() => tab = i),
          child: AnimatedContainer(duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(color: tab == i ? const Color(0xFF4F8C78).withOpacity(.13) : Colors.transparent,
              borderRadius: BorderRadius.circular(15)),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(icons[i], color: tab == i ? const Color(0xFF3F806B) : const Color(0xFF91A49A)),
              const SizedBox(height: 3),
              Text(labels[i], style: TextStyle(fontSize: 10,
                fontWeight: tab == i ? FontWeight.bold : FontWeight.normal,
                color: tab == i ? const Color(0xFF3F806B) : const Color(0xFF82958D))),
            ])))))),
  }
}

class Achievement {
  const Achievement(this.title, this.description, this.icon, this.done);
  final String title, description; final IconData icon; final bool done;
}

class Glass extends StatelessWidget {
  const Glass({super.key, required this.child, this.padding = const EdgeInsets.all(16)});
  final Widget child; final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(23),
    child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 13, sigmaY: 13),
      child: Container(padding: padding,
        decoration: BoxDecoration(color: Colors.white.withOpacity(.58),
          borderRadius: BorderRadius.circular(23),
          border: Border.all(color: Colors.white.withOpacity(.88), width: 1.2),
          boxShadow: [BoxShadow(color: const Color(0xFF789889).withOpacity(.07),
            blurRadius: 17, offset: const Offset(0, 6))]),
        child: child)),
  );
}

class SoftBackground extends StatelessWidget {
  const SoftBackground({super.key});
  @override
  Widget build(BuildContext context) => Positioned.fill(child: DecoratedBox(
    decoration: const BoxDecoration(gradient: LinearGradient(
      begin: Alignment.topRight, end: Alignment.bottomLeft,
      colors: [Color(0xFFE1EFE8), Color(0xFFF5F7F2), Color(0xFFE7F0ED)])),
    child: Stack(children: [
      Positioned(top: -80, right: -65, child: Container(width: 230, height: 230,
        decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFFB7D7C8).withOpacity(.45)))),
      Positioned(bottom: 100, left: -85, child: Container(width: 250, height: 250,
        decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFFC9DCE2).withOpacity(.48)))),
    ]),
  ));
}