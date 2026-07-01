import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'login_page.dart';
import 'home_page.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

// --- Tambahkan Class Service Ini ---
class NotificationService {
  // Wajib menggunakan argumen posisional (tanpa label id:, title:, body:)
  static Future<void> showNotification(int id, String title, String body) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'edutask_channel_id',
      'Notifikasi EduTask',
      importance: Importance.max,
      priority: Priority.high,
    );
    
    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
    );
        
    await flutterLocalNotificationsPlugin.show(
      id, 
      title, 
      body, 
      platformDetails,
    );
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Supabase.initialize(
    url: 'https://udxtlzimclufiqybfoek.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVkeHRsemltY2x1ZmlxeWJmb2VrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA5MjQ3NzYsImV4cCI6MjA5NjUwMDc3Nn0.cuZsgjUhHNYNWZwdbsK769k0fOGIK5fZQhUdqoqopyI',
  );

  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );

  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: (details) {
      debugPrint('Notification tapped: ${details.payload}');
    },
  );
  
  runApp(const EduTaskApp());
}

class EduTaskApp extends StatelessWidget {
  const EduTaskApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: StreamBuilder<AuthState>(
        stream: Supabase.instance.client.auth.onAuthStateChange,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          if (snapshot.hasData && snapshot.data?.session != null) {
            return const HomePage();
          }
          return const LoginPage();
        },
      ),
    );
  }
}