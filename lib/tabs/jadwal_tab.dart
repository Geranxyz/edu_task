import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

class JadwalTab extends StatefulWidget {
  const JadwalTab({super.key});

  @override
  State<JadwalTab> createState() => JadwalTabState();
}

class JadwalTabState extends State<JadwalTab> {
  final _supabase = Supabase.instance.client;
  List<dynamic> _schedules = [];
  bool _isLoading = true;
  Timer? _statusTimer;

  @override
  void initState() {
    super.initState();
    _readSchedules();
    
    // 🔄 Update status visual & deteksi waktu setiap 1 menit secara real-time
    _statusTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    super.dispose();
  }

  Future<void> refreshData() async {
    await _readSchedules();
  }

  Future<void> _readSchedules() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final response = await _supabase
          .from('schedules')
          .select('*')
          .eq('user_id', userId)
          .order('start_time', ascending: true); // Urutkan berdasarkan jam masuk

      if (mounted) {
        setState(() {
          _schedules = response as List<dynamic>;
          _isLoading = false;
        });
        _checkUrgentDeadlines();
      }
    } catch (e) {
      _showSnackBar('Gagal memuat jadwal: $e', Colors.red);
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 🚨 FUNGSI POP-UP ALERT TENGGAT < 30 MENIT
  void _checkUrgentDeadlines() {
    final now = DateTime.now();
    final currentDay = _getIndonesianDayName(now.weekday);

    for (var sched in _schedules) {
      if (sched['day'] == currentDay) {
        final startTimeStr = sched['start_time'] ?? '00:00';
        final parts = startTimeStr.split(':');
        if (parts.length >= 2) {
          final hour = int.parse(parts[0]);
          final minute = int.parse(parts[1]);
          
          final classTime = DateTime(now.year, now.month, now.day, hour, minute);
          final difference = classTime.difference(now).inMinutes;

          if (difference > 0 && difference <= 30) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _showUrgentDialog(sched['course_name'], startTimeStr, difference);
            });
          }
        }
      }
    }
  }

  void _showUrgentDialog(String courseName, String time, int minutesLeft) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.red[50], shape: BoxShape.circle),
              child: const Icon(Icons.alarm_on_rounded, color: Colors.red, size: 28),
            ),
            const SizedBox(width: 12),
            const Text('Kelas Segera Mulai!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: RichText(
          text: TextSpan(
            style: const TextStyle(color: Colors.black87, fontSize: 14, height: 1.5),
            children: [
              const TextSpan(text: 'Mata kuliah '),
              TextSpan(text: courseName, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange)),
              const TextSpan(text: ' akan dimulai pada jam '),
              TextSpan(text: '$time ', style: const TextStyle(fontWeight: FontWeight.bold)),
              TextSpan(text: '($minutesLeft menit lagi). Jangan sampai terlambat!'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Siap, Paham', style: TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  String _getClassStatus(String targetDay, String startTimeStr, String endTimeStr) {
    final now = DateTime.now();
    if (_getIndonesianDayName(now.weekday) != targetDay) return 'NORMAL';

    try {
      final startParts = startTimeStr.split(':');
      final endParts = endTimeStr.split(':');
      
      final startClass = DateTime(now.year, now.month, now.day, int.parse(startParts[0]), int.parse(startParts[1]));
      final endClass = DateTime(now.year, now.month, now.day, int.parse(endParts[0]), int.parse(endParts[1]));

      if (now.isAfter(startClass) && now.isBefore(endClass)) {
        return 'BERLANGSUNG';
      } else if (startClass.difference(now).inMinutes > 0 && startClass.difference(now).inMinutes <= 30) {
        return 'TENGGAT';
      }
    } catch (_) {}
    return 'NORMAL';
  }

  String _getIndonesianDayName(int weekday) {
    switch (weekday) {
      case 1: return 'Senin';
      case 2: return 'Selasa';
      case 3: return 'Rabu';
      case 4: return 'Kamis';
      case 5: return 'Jumat';
      case 6: return 'Sabtu';
      case 7: return 'Minggu';
      default: return 'Senin';
    }
  }

  Future<void> _createSchedule(String courseName, String day, String start, String end, String room, String lecturer) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      await _supabase.from('schedules').insert({
        'user_id': userId,
        'course_name': courseName,
        'day': day,
        'start_time': start,
        'end_time': end,
        'room': room.isEmpty ? 'Online / TBD' : room,
        'lecturer': lecturer.isEmpty ? 'Dosen' : lecturer,
      });

      _readSchedules();
      _showSnackBar('📅 Jadwal kuliah berhasil disimpan!', Colors.green);
    } catch (e) {
      _showSnackBar('Gagal menyimpan: $e', Colors.red);
    }
  }

  Future<void> _deleteSchedule(dynamic id) async {
    try {
      await _supabase.from('schedules').delete().eq('id', id);
      _readSchedules();
      _showSnackBar('Jadwal berhasil dihapus', Colors.black87);
    } catch (e) {
      _showSnackBar('Gagal menghapus: $e', Colors.red);
    }
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color, behavior: SnackBarBehavior.floating),
    );
  }

  // 🚀 FITUR TAMBAH JADWAL: MODAL SHEET DENGAN DESAIN BARU & UI INTERAKTIF
  void _showScheduleFormSheet() {
    final nameCtrl = TextEditingController();
    final roomCtrl = TextEditingController();
    final lecturerCtrl = TextEditingController();
    String selectedDay = 'Senin';
    TimeOfDay startTime = const TimeOfDay(hour: 08, minute: 00);
    TimeOfDay endTime = const TimeOfDay(hour: 09, minute: 40);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent, // Membuat latar belakang melengkung sempurna
      builder: (ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                top: 16,
                left: 20,
                right: 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 5,
                        decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Row(
                      children: [
                        Icon(Icons.add_task_rounded, color: Colors.deepOrange, size: 24),
                        SizedBox(width: 8),
                        Text('Tambah Jadwal Kuliah', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2D3142))),
                      ],
                    ),
                    const SizedBox(height: 20),
                    
                    // Input Nama Matkul
                    TextField(
                      controller: nameCtrl,
                      decoration: InputDecoration(
                        labelText: 'Nama Mata Kuliah',
                        hintText: 'Contoh: Pemrograman Mobile',
                        prefixIcon: const Icon(Icons.book_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.deepOrange, width: 2), borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Dropdown Hari kustom yang minimalis
                    DropdownButtonFormField<String>(
                      value: selectedDay,
                      decoration: InputDecoration(
                        labelText: 'Hari Kuliah',
                        prefixIcon: const Icon(Icons.calendar_month_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      items: ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu']
                          .map((day) => DropdownMenuItem(value: day, child: Text(day)))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setModalState(() => selectedDay = val);
                      },
                    ),
                    const SizedBox(height: 14),

                    // Baris Input Waktu (Sangat Visual dan Indah)
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final time = await showTimePicker(context: ctx, initialTime: startTime);
                              if (time != null) setModalState(() => startTime = time);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey[400]!),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.access_time, color: Colors.grey),
                                  const SizedBox(width: 8),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Jam Mulai', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                      Text(startTime.format(ctx), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final time = await showTimePicker(context: ctx, initialTime: endTime);
                              if (time != null) setModalState(() => endTime = time);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey[400]!),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.access_time_filled_outlined, color: Colors.grey),
                                  const SizedBox(width: 8),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Jam Selesai', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                      Text(endTime.format(ctx), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Baris Input Ruangan & Dosen
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: roomCtrl,
                            decoration: InputDecoration(
                              labelText: 'Ruangan (Opsional)',
                              hintText: 'Lab 302',
                              prefixIcon: const Icon(Icons.meeting_room_outlined),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: lecturerCtrl,
                            decoration: InputDecoration(
                              labelText: 'Dosen (Opsional)',
                              hintText: 'Nama Dosen',
                              prefixIcon: const Icon(Icons.person_outline_rounded),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Tombol Simpan Premium
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepOrange,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 2,
                        ),
                        onPressed: () {
                          if (nameCtrl.text.trim().isEmpty) {
                            _showSnackBar('Nama mata kuliah wajib diisi!', Colors.amber);
                            return;
                          }
                          String startStr = "${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}";
                          String endStr = "${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}";
                          
                          _createSchedule(
                            nameCtrl.text.trim(), 
                            selectedDay, 
                            startStr, 
                            endStr,
                            roomCtrl.text.trim(),
                            lecturerCtrl.text.trim()
                          );
                          Navigator.pop(ctx);
                        },
                        child: const Text('Simpan ke Jadwal', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: Colors.deepOrange));

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9), // Latar belakang abu-abu pudar estetik
      body: RefreshIndicator(
        onRefresh: _readSchedules,
        color: Colors.deepOrange,
        child: _schedules.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 180),
                  Center(child: Icon(Icons.calendar_today_outlined, size: 60, color: Colors.grey)),
                  SizedBox(height: 12),
                  Center(child: Text('Belum ada jadwal kuliah.', style: TextStyle(color: Colors.grey, fontSize: 16))),
                ],
              )
            : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                itemCount: _schedules.length,
                itemBuilder: (context, index) {
                  final sched = _schedules[index];
                  final statusWaktu = _getClassStatus(
                    sched['day'] ?? 'Senin', 
                    sched['start_time'] ?? '00:00', 
                    sched['end_time'] ?? '00:00'
                  );

                  // Set skema warna adaptif premium
                  Color sideColor = Colors.blueAccent;
                  Color boxCheckColor = Colors.grey[400]!;
                  Color cardBg = Colors.white;

                  if (statusWaktu == 'BERLANGSUNG') {
                    sideColor = Colors.green;
                    boxCheckColor = Colors.green;
                  } else if (statusWaktu == 'TENGGAT') {
                    sideColor = Colors.redAccent;
                    boxCheckColor = Colors.redAccent;
                  }

                  return Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: IntrinsicHeight( // Menyelaraskan tinggi pembatas kiri dengan isi konten secara otomatis
                      child: Row(
                        children: [
                          Container(width: 6, color: sideColor),
                          
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // 1. KOTAK CEK (Sama Seperti Halaman Misi Anda)
                                  Icon(
                                    statusWaktu == 'BERLANGSUNG' 
                                        ? Icons.check_box_rounded 
                                        : Icons.check_box_outline_blank_rounded, 
                                    color: boxCheckColor, 
                                    size: 24
                                  ),
                                  const SizedBox(width: 14),

                                  // 2. KONTEN UTAMA (Sangat Terstruktur)
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          sched['course_name'] ?? 'Tanpa Nama',
                                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E2229)),
                                        ),
                                        const SizedBox(height: 6),
                                        
                                        // Row Informasi Tambahan (Ruangan & Dosen)
                                        Row(
                                          children: [
                                            Icon(Icons.room_outlined, size: 13, color: Colors.grey[600]),
                                            const SizedBox(width: 3),
                                            Text(sched['room'] ?? 'TBD', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                                            const SizedBox(width: 12),
                                            Icon(Icons.person_rounded, size: 13, color: Colors.grey[600]),
                                            const SizedBox(width: 3),
                                            Expanded(
                                              child: Text(
                                                sched['lecturer'] ?? 'Dosen', 
                                                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        
                                        // Barisan Badge Bawah
                                        SingleChildScrollView(
                                          scrollDirection: Axis.horizontal,
                                          child: Row(
                                            children: [
                                              // Badge "Kuliah" Oranye Khas Misi
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFFF5722),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: const Text(
                                                  'Kuliah',
                                                  style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              
                                              // Info Jam & Hari
                                              Icon(Icons.schedule_rounded, size: 14, color: Colors.grey[500]),
                                              const SizedBox(width: 4),
                                              Text(
                                                '${sched['day']}, ${sched['start_time']} - ${sched['end_time']}',
                                                style: TextStyle(color: Colors.grey[700], fontSize: 12, fontWeight: FontWeight.w600),
                                              ),
                                              
                                              // Status Dinamis
                                              if (statusWaktu == 'BERLANGSUNG') ...[
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                  decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(6)),
                                                  child: const Text('🔴 Live', style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
                                                ),
                                              ] else if (statusWaktu == 'TENGGAT') ...[
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                  decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(6)),
                                                  child: const Text('⏰ Segera Mulai', style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                                                ),
                                              ]
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // 3. TOMBOL HAPUS MINIMALIS
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 22),
                                    onPressed: () => _deleteSchedule(sched['id']),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showScheduleFormSheet,
        backgroundColor: Colors.deepOrange,
        elevation: 3,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Jadwal Baru', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}