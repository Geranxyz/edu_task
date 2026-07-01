import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'tabs/misi_tab.dart';
import 'tabs/jadwal_tab.dart';
import 'tabs/rapor_tab.dart';
import 'login_page.dart'; // 💡 Diperlukan kembali agar class LoginPage() bisa terbaca langsung

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  final _supabase = Supabase.instance.client;

  // GlobalKeys untuk kontrol state tab
  final GlobalKey<JadwalTabState> _jadwalKey = GlobalKey<JadwalTabState>();
  final GlobalKey<RaporTabState> _raporKey = GlobalKey<RaporTabState>();

  void _onTabTapped(int index) {
    setState(() => _currentIndex = index);

    // Gunakan postFrameCallback untuk memastikan state sudah terpasang
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (index == 1) {
        _jadwalKey.currentState?.refreshData();
      } else if (index == 2) {
        _raporKey.currentState?.refreshData();
      }
    });
  }

  // 📝 Fungsi Dialog Keluar (Fokus memaksa pembersihan sisa tumpukan navigator)
  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: const Text('Keluar Aplikasi 🚪', style: TextStyle(fontWeight: FontWeight.bold)),
          content: const Text('Apakah Anda yakin ingin keluar dari akun Edu Task RPG?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx), // Menutup dialog jika batal
              child: const Text('Batal', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                // Ambil rujukan navigator sebelum menutup dialog (mencegah async gap eror)
                final navigator = Navigator.of(context);
                Navigator.pop(ctx); // Tutup dialog konfirmasi
                
                try {
                  // 1. Hapus token sesi aktif di server Supabase
                  await _supabase.auth.signOut();
                  
                  // 2. Paksa bersihkan seluruh riwayat tumpukan halaman dan arahkan ke LoginPage
                  navigator.pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const LoginPage()),
                    (route) => false,
                  );
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Gagal keluar: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              child: const Text('Keluar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Edu Task RPG 🎓', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.black87),
            onPressed: _showLogoutDialog, // Memanggil fungsi dialog konfirmasi logout
          )
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          const MisiTab(),
          JadwalTab(key: _jadwalKey),
          RaporTab(key: _raporKey),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
        selectedItemColor: Colors.deepOrange,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.rocket_launch), label: 'Misi'),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_month), label: 'Jadwal'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Rapor'),
        ],
      ),
    );
  }
}