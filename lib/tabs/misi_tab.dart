import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class MisiTab extends StatefulWidget {
  const MisiTab({super.key});

  @override
  State<MisiTab> createState() => MisiTabState();
}

class MisiTabState extends State<MisiTab> {
  final _supabase = Supabase.instance.client;
  List<dynamic> _tasks = [];
  bool _isLoading = true;
  
  // 📜 Variabel untuk melacak tab mana yang sedang aktif
  bool _showHistoryTab = false; 

  @override
  void initState() {
    super.initState();
    _readTasks();
  }

  void refreshData() {
    _readTasks();
  }

  // --- DATABASE OPERATIONS ---

  Future<void> _readTasks() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final response = await _supabase
          .from('tasks')
          .select()
          .eq('user_id', userId)
          .order('deadline', ascending: true);

      if (mounted) {
        setState(() {
          _tasks = response;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Gagal mengambil tugas: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _createTask(String title, String description, DateTime deadline, String category) async {
    try {
      await _supabase.from('tasks').insert({
        'user_id': _supabase.auth.currentUser!.id,
        'title': title,
        'description': description,
        'deadline': deadline.toIso8601String(),
        'category': category,
        'is_completed': false,
        'progress': 0, // ✨ Inisialisasi progres 0%
      });

      _readTasks();
      _showSnackBar('🚀 Misi baru berhasil ditambahkan!', Colors.green);
    } catch (e) {
      _showSnackBar('Gagal menambahkan misi: $e', Colors.red);
    }
  }

  Future<void> _updateTask(int id, String title, String description, DateTime deadline, String category, int progress) async {
    try {
      // Jika progres diubah manual jadi 100%, otomatis set is_completed = true
      bool completedStatus = progress >= 100;

      await _supabase.from('tasks').update({
        'title': title,
        'description': description,
        'deadline': deadline.toIso8601String(),
        'category': category,
        'progress': progress,
        'is_completed': completedStatus,
      }).eq('id', id);

      _readTasks();
      _showSnackBar('✏️ Misi berhasil diperbarui!', Colors.blue);
    } catch (e) {
      _showSnackBar('Gagal memperbarui misi: $e', Colors.red);
    }
  }

  // ✨ Mengubah nilai progres secara cepat dari kartu langsung
  Future<void> _updateProgressDirectly(dynamic id) async {
  // 1. Cari indeks tugas di dalam list lokal _tasks
  final taskIndex = _tasks.indexWhere((t) => t['id'] == id);
  if (taskIndex == -1) return;

  // 2. Ambil progres terakhir dari state lokal (bukan dari UI lama)
  int currentProgress = _tasks[taskIndex]['progress'] ?? 0;
  int newProgress = (currentProgress + 25).clamp(0, 100);
  bool isNowCompleted = newProgress >= 100;

  // 3. OPTIMISTIC UPDATE: Ubah data lokal secara instan agar klik cepat berikutnya langsung membaca nilai baru
  setState(() {
    // Duplikasi map agar terhindar dari error 'unmodifiable map' dari Supabase
    final updatedTask = Map<String, dynamic>.from(_tasks[taskIndex]);
    updatedTask['progress'] = newProgress;
    updatedTask['is_completed'] = isNowCompleted;
    
    _tasks[taskIndex] = updatedTask;
  });

  // 4. Kirim pembaruan ke Supabase di latar belakang
  try {
    await _supabase.from('tasks').update({
      'progress': newProgress,
      'is_completed': isNowCompleted,
    }).eq('id', id);

    // 5. Jika menyentuh 100%, panggil _readTasks untuk sinkronisasi ulang database & hilangkan kartu dari tab aktif
    if (isNowCompleted) {
      _showSnackBar('🎉 Misi 100% Selesai! Masuk ke Histori Jurnal +XP', Colors.green);
      _readTasks(); 
    } else {
      _showSnackBar('📈 Progres diperbarui menjadi $newProgress%', Colors.blue);
    }
  } catch (e) {
    // Jika gagal ke server, lakukan rollback (tarik ulang data asli dari database)
    _showSnackBar('Gagal memperbarui ke server: $e', Colors.red);
    _readTasks();
  }
}

  Future<void> _toggleTaskCompletion(int id, bool currentStatus) async {
    try {
      bool newStatus = !currentStatus;
      await _supabase
          .from('tasks')
          .update({
            'is_completed': newStatus,
            'progress': newStatus ? 100 : 0 // Jk dicentang langsung 100%, jk dibuka lagi reset 0%
          })
          .eq('id', id);
      
      _readTasks();
      _showSnackBar(newStatus ? '🎉 Misi diselesaikan! Masuk Histori' : 'Misi dibuka kembali', Colors.orange);
    } catch (e) {
      _showSnackBar('Gagal memperbarui status: $e', Colors.red);
    }
  }

  Future<void> _deleteTask(int id) async {
    try {
      await _supabase.from('tasks').delete().eq('id', id);
      _readTasks();
      _showSnackBar('🗑️ Misi telah dihapus', Colors.blueGrey);
    } catch (e) {
      _showSnackBar('Gagal menghapus misi: $e', Colors.red);
    }
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color, duration: const Duration(seconds: 2)),
    );
  }

  // --- UI FORM SHEET ---

  void _showTaskFormSheet({Map<String, dynamic>? taskData}) {
    final bool isEditing = taskData != null;

    final titleCtrl = TextEditingController(text: isEditing ? taskData['title'] : '');
    final descCtrl = TextEditingController(text: isEditing ? taskData['description'] : '');
    int currentProgress = isEditing ? (taskData['progress'] ?? 0) : 0;
    
    DateTime selectedDate = isEditing 
        ? DateTime.parse(taskData['deadline']) 
        : DateTime.now().add(const Duration(days: 1));
        
    String selectedCategory = isEditing ? taskData['category'] : 'Tugas';
    final List<String> categories = ['Tugas', 'Proyek', 'Kuis', 'Praktikum', 'Umum'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) { // ✅ Diubah menjadi modalCtx agar tidak tumpang tindih
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
              left: 20, right: 20, top: 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  isEditing ? 'Edit Detail Misi ✏️' : 'Tambah Misi Baru 📝',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: titleCtrl, 
                  decoration: const InputDecoration(labelText: 'Nama Tugas / Judul Misi', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl, 
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Deskripsi Detail Pengerjaan', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (val) => setModalState(() => selectedCategory = val!),
                  decoration: const InputDecoration(labelText: 'Kategori', border: OutlineInputBorder()),
                ),
                
                // Slider Progres di dalam Form Edit
                if (isEditing) ...[
                  const SizedBox(height: 15),
                  Text('Progres Misi: $currentProgress%', style: const TextStyle(fontWeight: FontWeight.bold)),
                  Slider(
                    value: currentProgress.toDouble(),
                    min: 0, max: 100, divisions: 4,
                    activeColor: Colors.deepOrange,
                    label: '$currentProgress%',
                    onChanged: (value) => setModalState(() => currentProgress = value.toInt()),
                  ),
                ],
                
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Text('Tenggat Waktu: ', style: TextStyle(fontWeight: FontWeight.bold)),
                    Expanded(
                      child: TextButton.icon(
                        icon: const Icon(Icons.calendar_today, color: Colors.deepOrange),
                        label: Text(DateFormat('dd MMM yyyy').format(selectedDate)),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime.now().subtract(const Duration(days: 30)),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (picked != null) setModalState(() => selectedDate = picked);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepOrange,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () {
                    if (titleCtrl.text.trim().isEmpty) {
                      _showSnackBar('Judul tidak boleh kosong!', Colors.amber);
                      return;
                    }
                    if (isEditing) {
                      _updateTask(taskData['id'], titleCtrl.text, descCtrl.text, selectedDate, selectedCategory, currentProgress);
                    } else {
                      _createTask(titleCtrl.text, descCtrl.text, selectedDate, selectedCategory);
                    }
                    Navigator.pop(ctx);
                  },
                  child: Text(isEditing ? 'Simpan Perubahan' : 'Terima Misi', style: const TextStyle(color: Colors.white)),
                ),
                const SizedBox(height: 25),
              ],
            ),
          );
        },
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Proyek': return Colors.blue.shade700;
      case 'Kuis': return Colors.purple.shade700;
      case 'Praktikum': return Colors.teal.shade700;
      case 'Tugas': return Colors.orange.shade800;
      default: return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    // 🛠️ FILTER DATA: Memisahkan misi aktif dengan yang sudah masuk histori (is_completed)
    final filteredTasks = _tasks.where((task) => task['is_completed'] == _showHistoryTab).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          // --- SEGMENTED HEADER NAVIGATION (Misi Aktif vs Histori) ---
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.shield, size: 18), // ✅ Diubah dari Icons.crossed_swords
                    label: const Text('Misi Aktif'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: !_showHistoryTab ? Colors.deepOrange : Colors.grey.shade200,
                      foregroundColor: !_showHistoryTab ? Colors.white : Colors.black87,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => setState(() => _showHistoryTab = false),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.auto_stories, size: 18), 
                    label: const Text('Histori Jurnal'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _showHistoryTab ? Colors.green.shade700 : Colors.grey.shade200,
                      foregroundColor: _showHistoryTab ? Colors.white : Colors.black87,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => setState(() => _showHistoryTab = true),
                  ),
                ),
              ],
            ),
          ),

          // --- MAIN LIST VIEW ---
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _readTasks,
                    child: filteredTasks.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              const SizedBox(height: 80),
                              Center(
                                child: Text(
                                  _showHistoryTab 
                                      ? 'Belum ada riwayat misi yang diselesaikan. 🛡️' 
                                      : 'Semua misi aktif selesai! Silakan bersantai. 🎉',
                                  textAlign: TextAlign.center, // ✅ Diubah dari CenterTextAlign.center
                                  style: const TextStyle(color: Colors.grey),
                                ),
                              ),
                            ],
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: filteredTasks.length,
                            itemBuilder: (context, index) {
                              final task = filteredTasks[index];
                              final bool isDone = task['is_completed'];
                              final int currentProgress = task['progress'] ?? 0;
                              final DateTime deadline = DateTime.parse(task['deadline']);
                              final bool isOverdue = DateTime.now().isAfter(deadline) && !isDone;

                              return Card(
                                margin: const EdgeInsets.only(bottom: 16),
                                elevation: isDone ? 1 : 3,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: BorderSide(color: isDone ? Colors.green.shade200 : Colors.grey.shade200, width: 1),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Kategori & Status Badge
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: _getCategoryColor(task['category']),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              '🛡️ ${task["category"].toString().toUpperCase()}',
                                              style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: isDone ? Colors.green.shade100 : (isOverdue ? Colors.red.shade100 : Colors.amber.shade100),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              isDone ? '🏆 BERHASIL' : (isOverdue ? '⚠️ OVERDUE' : '⚔️ DALAM PROSES'),
                                              style: TextStyle(fontSize: 10, color: isDone ? Colors.green.shade900 : (isOverdue ? Colors.red.shade900 : Colors.amber.shade900), fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const Divider(height: 20),

                                      // Nama Tugas
                                      const Text('NAMA TUGAS / MISI', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                                      const SizedBox(height: 2),
                                      Text(
                                        task['title'],
                                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDone ? Colors.grey : Colors.black87),
                                      ),
                                      const SizedBox(height: 10),

                                      // Deskripsi Tugas
                                      const Text('DESKRIPSI PENGERJAAN', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                                      const SizedBox(height: 4),
                                      Text(
                                        task['description'] ?? 'Tidak ada deskripsi detail.',
                                        style: TextStyle(fontSize: 13, color: isDone ? Colors.grey : Colors.black54),
                                      ),
                                      const SizedBox(height: 14),

                                      // --- 📊 SISTEM PROGRES BAR ---
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text('PROGRES CAPAIAN:', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                                          Text('$currentProgress%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDone ? Colors.green : Colors.deepOrange)),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: LinearProgressIndicator(
                                          value: currentProgress / 100,
                                          backgroundColor: Colors.grey.shade200,
                                          valueColor: AlwaysStoppedAnimation<Color>(isDone ? Colors.green : Colors.deepOrange),
                                          minHeight: 8,
                                        ),
                                      ),
                                      
                                      // Tombol Pengubah Progres Cepat (Hanya muncul jika di Tab Misi Aktif)
                                      if (!isDone) ...[
                                        const SizedBox(height: 8),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          children: [
                                            // Cari kode TextButton +25% Progres Anda di bagian bawah, lalu ubah menjadi seperti ini:
                                        TextButton(
                                          onPressed: () => _updateProgressDirectly(task['id']), // Cukup kirim id saja
                                            child: const Text(
                                              '+25% Progres 📈', 
                                              style: TextStyle(fontSize: 11, color: Colors.deepOrange, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                                                                    ],
                                        ),
                                      ],

                                      const Divider(height: 20),

                                      // Batas Waktu & Kontrol Tombol Aksi
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text('DEADLINE JADWAL:', style: TextStyle(fontSize: 9, color: Colors.grey)),
                                              Text(
                                                DateFormat('dd MMM yyyy').format(deadline),
                                                style: TextStyle(fontSize: 12, color: isOverdue ? Colors.red : Colors.black87, fontWeight: FontWeight.bold),
                                              ),
                                            ],
                                          ),
                                          Row(
                                            children: [
                                              // Tombol Selesai Cepat (Centang langsung 100%)
                                              IconButton(
                                                icon: Icon(isDone ? Icons.check_circle : Icons.radio_button_unchecked, color: isDone ? Colors.green : Colors.grey),
                                                onPressed: () => _toggleTaskCompletion(task['id'], isDone),
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.edit_note, color: Colors.blue),
                                                onPressed: () => _showTaskFormSheet(taskData: task),
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.delete_sweep_outlined, color: Colors.redAccent),
                                                onPressed: () {
                                                  showDialog(
                                                    context: context,
                                                    builder: (ctx) => AlertDialog(
                                                      title: const Text('Hapus Permanen?'),
                                                      content: const Text('Hapus data misi ini dari database?'),
                                                      actions: [
                                                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
                                                        TextButton(
                                                          onPressed: () {
                                                            Navigator.pop(ctx);
                                                            _deleteTask(task['id']);
                                                          },
                                                          child: const Text('Hapus', style: TextStyle(color: Colors.red)),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                },
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showTaskFormSheet(),
        backgroundColor: Colors.deepOrange,
        icon: const Icon(Icons.add_moderator, color: Colors.white),
        label: const Text('TERIMA MISI BARU', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}