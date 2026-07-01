import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RaporTab extends StatefulWidget {
  const RaporTab({super.key});

  @override
  State<RaporTab> createState() => RaporTabState();
}

class RaporTabState extends State<RaporTab> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;

  int _totalTasks = 0;
  int _completedTasks = 0;
  int _activeSchedules = 0;
  
  // Variabel RPG Elemen
  int _currentLevel = 1;
  int _currentXP = 0;
  int _xpNeededForNextLevel = 100;
  double _xpProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _readStats();
  }

  // Fungsi publik yang dipanggil oleh HomePage untuk menyegarkan data otomatis
  void refreshData() {
    _readStats();
  }

  Future<void> _readStats() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      // 1. Ambil data Tugas untuk menghitung statistik & XP
      final tasksResponse = await _supabase
          .from('tasks')
          .select('is_completed')
          .eq('user_id', userId);

      // 2. Ambil data Jadwal untuk menghitung beban kuliah aktif
      final schedulesResponse = await _supabase
          .from('schedules')
          .select('id')
          .eq('user_id', userId);

      if (mounted) {
        final tasks = tasksResponse as List<dynamic>;
        final total = tasks.length;
        final completed = tasks.where((t) => t['is_completed'] == true).length;
        final schedulesCount = (schedulesResponse as List<dynamic>).length;

        // Hitung Logika RPG: Misal 1 tugas selesai = 25 XP
        int totalXP = completed * 25;
        int level = (totalXP ~/ _xpNeededForNextLevel) + 1;
        int currentXP = totalXP % _xpNeededForNextLevel;
        double progress = currentXP / _xpNeededForNextLevel;

        setState(() {
          _totalTasks = total;
          _completedTasks = completed;
          _activeSchedules = schedulesCount;
          _currentLevel = level;
          _currentXP = currentXP;
          _xpProgress = progress;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Gagal mengambil statistik rapor: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    double completionRate = _totalTasks > 0 ? (_completedTasks / _totalTasks) * 100 : 0.0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: _readStats,
        color: Colors.deepOrange,
        child: ListView(
          padding: const EdgeInsets.all(16),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            // --- KARTU STATUS RPG KARAKTER ---
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  gradient: LinearGradient(
                    colors: [Colors.deepOrange, Colors.orangeAccent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: Colors.white,
                          child: Text(
                            'Lv.$_currentLevel',
                            style: const TextStyle(
                              fontSize: 18, 
                              fontWeight: FontWeight.bold, 
                              color: Colors.deepOrange
                            ),
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _supabase.auth.currentUser?.email?.split('@')[0].toUpperCase() ?? 'MAHASISWA HERO',
                                style: const TextStyle(
                                  fontSize: 18, 
                                  fontWeight: FontWeight.bold, 
                                  color: Colors.white
                                ),
                              ),
                              const Text(
                                'Kelas Akademik Tingkat Tinggi',
                                style: TextStyle(color: Colors.white70, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
  // UBAH DI SINI: dari .between menjadi .spaceBetween
  mainAxisAlignment: MainAxisAlignment.spaceBetween,
  children: [
    const Text('Progress XP Misi', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
    Text('$_currentXP / $_xpNeededForNextLevel XP', style: const TextStyle(color: Colors.white)),
  ],
),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: _xpProgress,
                        backgroundColor: Colors.white24,
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                        minHeight: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // --- GRID STATISTIK AKADEMIK ---
            const Text(
              'Statistik Petualangan Kuliah 📊',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildStatCard(
                  icon: Icons.assignment_turned_in_outlined,
                  title: 'Misi Selesai',
                  value: '$_completedTasks / $_totalTasks',
                  color: Colors.green,
                ),
                _buildStatCard(
                  icon: Icons.percent_outlined,
                  title: 'Rasio Sukses',
                  value: '${completionRate.toStringAsFixed(1)}%',
                  color: Colors.blue,
                ),
                _buildStatCard(
                  icon: Icons.calendar_today_outlined,
                  title: 'Kelas Mingguan',
                  value: '$_activeSchedules MK',
                  color: Colors.purple,
                ),
                _buildStatCard(
                  icon: Icons.hourglass_empty_outlined,
                  title: 'Misi Aktif',
                  value: '${_totalTasks - _completedTasks} Tugas',
                  color: Colors.amber[800]!,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon, 
    required String title, 
    required String value, 
    required Color color
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.1),
              radius: 20,
              child: Icon(icon, color: color),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(color: Colors.grey[600], fontSize: 13, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
          ],
        ),
      ),
    );
  }
}