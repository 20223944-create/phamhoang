import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'dart:convert';

final FlutterLocalNotificationsPlugin notificationsPlugin =
    FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();

  const android = AndroidInitializationSettings('@mipmap/ic_launcher');
  const settings = InitializationSettings(android: android);

  await notificationsPlugin.initialize(settings);

  runApp(const MyApp());
}

// ================= MODEL =================
class CongViec {
  String tieuDe;
  String diaDiem;
  DateTime thoiGian;
  bool hoanThanh;

  CongViec({
    required this.tieuDe,
    required this.diaDiem,
    required this.thoiGian,
    this.hoanThanh = false,
  });

  Map<String, dynamic> toJson() => {
    'tieuDe': tieuDe,
    'diaDiem': diaDiem,
    'thoiGian': thoiGian.toIso8601String(),
    'hoanThanh': hoanThanh,
  };

  factory CongViec.fromJson(Map<String, dynamic> json) => CongViec(
    tieuDe: json['tieuDe'],
    diaDiem: json['diaDiem'],
    thoiGian: DateTime.parse(json['thoiGian']),
    hoanThanh: json['hoanThanh'],
  );
}

// ================= APP =================
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: const HomeScreen(),
    );
  }
}

// ================= HOME =================
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

enum Loc { tatCa, daXong, chuaXong }

class _HomeScreenState extends State<HomeScreen> {
  List<CongViec> danhSach = [];
  String timKiem = "";
  Loc boLoc = Loc.tatCa;

  @override
  void initState() {
    super.initState();
    taiDuLieu();
  }

  List<CongViec> get locDanhSach {
    return danhSach.where((cv) {
      final matchSearch = cv.tieuDe.toLowerCase().contains(
        timKiem.toLowerCase(),
      );

      final matchFilter = boLoc == Loc.tatCa
          ? true
          : boLoc == Loc.daXong
          ? cv.hoanThanh
          : !cv.hoanThanh;

      return matchSearch && matchFilter;
    }).toList();
  }

  Future luu() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setStringList(
      "tasks",
      danhSach.map((e) => jsonEncode(e.toJson())).toList(),
    );
  }

  Future taiDuLieu() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList("tasks");

    if (data != null) {
      setState(() {
        danhSach = data.map((e) => CongViec.fromJson(jsonDecode(e))).toList();
      });
    }
  }

  Future thongBao(CongViec cv) async {
    await notificationsPlugin.zonedSchedule(
      cv.hashCode,
      "📌 Nhắc việc",
      cv.tieuDe,
      tz.TZDateTime.from(cv.thoiGian, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'kenh',
          'Nhắc việc',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  void them(CongViec cv) {
    setState(() => danhSach.add(cv));
    luu();
    thongBao(cv);
  }

  void xoa(int i) {
    setState(() => danhSach.removeAt(i));
    luu();
  }

  String f(DateTime d) => DateFormat('dd/MM HH:mm').format(d);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(" Quản lý công việc"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
          ),
        ),
        child: Column(
          children: [
            const SizedBox(height: 100),

            // SEARCH
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: "Tìm kiếm...",
                  hintStyle: const TextStyle(color: Colors.white70),
                  prefixIcon: const Icon(Icons.search, color: Colors.white),
                  filled: true,
                  fillColor: Colors.white10,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (v) => setState(() => timKiem = v),
              ),
            ),

            // FILTER
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                chip("Tất cả", Loc.tatCa),
                chip("Đã xong", Loc.daXong),
                chip("Chưa xong", Loc.chuaXong),
              ],
            ),

            const SizedBox(height: 10),

            // LIST
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: locDanhSach.length,
                itemBuilder: (context, i) {
                  final cv = locDanhSach[i];
                  final treHan =
                      cv.thoiGian.isBefore(DateTime.now()) && !cv.hoanThanh;

                  return Dismissible(
                    key: Key(i.toString()),
                    onDismissed: (_) => xoa(i),
                    background: Container(
                      color: Colors.red,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: treHan
                              ? [Colors.red.shade400, Colors.red.shade200]
                              : [Colors.white, Colors.grey.shade100],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: ListTile(
                        leading: Checkbox(
                          value: cv.hoanThanh,
                          onChanged: (v) {
                            setState(() => cv.hoanThanh = v!);
                            luu();
                          },
                        ),
                        title: Text(
                          cv.tieuDe,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            decoration: cv.hoanThanh
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                        subtitle: Text("${f(cv.thoiGian)}\n📍 ${cv.diaDiem}"),
                        isThreeLine: true,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.orange,
        child: const Icon(Icons.add),
        onPressed: () async {
          final kq = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddScreen()),
          );

          if (!mounted) return;
          if (kq != null) them(kq);
        },
      ),
    );
  }

  Widget chip(String text, Loc l) {
    final selected = boLoc == l;

    return GestureDetector(
      onTap: () => setState(() => boLoc = l),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(colors: [Colors.orange, Colors.deepOrange])
              : null,
          color: selected ? null : Colors.white10,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(text, style: const TextStyle(color: Colors.white)),
      ),
    );
  }
}

// ================= ADD =================
class AddScreen extends StatefulWidget {
  const AddScreen({super.key});

  @override
  State<AddScreen> createState() => _AddScreenState();
}

class _AddScreenState extends State<AddScreen> {
  final tieuDe = TextEditingController();
  final diaDiem = TextEditingController();
  DateTime thoiGian = DateTime.now();

  Future pickDateTime() async {
    final d = await showDatePicker(
      context: context,
      initialDate: thoiGian,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (d != null) {
      final t = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(thoiGian),
      );

      if (t != null) {
        setState(() {
          thoiGian = DateTime(d.year, d.month, d.day, t.hour, t.minute);
        });
      }
    }
  }

  void save() {
    if (tieuDe.text.isEmpty) return;

    Navigator.pop(
      context,
      CongViec(tieuDe: tieuDe.text, diaDiem: diaDiem.text, thoiGian: thoiGian),
    );
  }

  String format(DateTime d) =>
      "${d.day}/${d.month}/${d.year} - ${d.hour}:${d.minute.toString().padLeft(2, '0')}";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("➕ Thêm công việc"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(25),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                children: [
                  // TITLE
                  TextField(
                    controller: tieuDe,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: "Tên công việc",
                      labelStyle: const TextStyle(color: Colors.white70),
                      prefixIcon: const Icon(Icons.task, color: Colors.white),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),

                  const SizedBox(height: 15),

                  // LOCATION
                  TextField(
                    controller: diaDiem,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: "Địa điểm",
                      labelStyle: const TextStyle(color: Colors.white70),
                      prefixIcon: const Icon(
                        Icons.location_on,
                        color: Colors.white,
                      ),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // DATE CARD
                  GestureDetector(
                    onTap: pickDateTime,
                    child: Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Colors.orange, Colors.deepOrange],
                        ),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Icon(Icons.calendar_month, color: Colors.white),
                          Text(
                            format(thoiGian),
                            style: const TextStyle(color: Colors.white),
                          ),
                          const Icon(Icons.edit, color: Colors.white),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 25),

                  // SAVE BUTTON
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: save,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        backgroundColor: Colors.green,
                      ),
                      child: const Text(
                        "LƯU CÔNG VIỆC",
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
