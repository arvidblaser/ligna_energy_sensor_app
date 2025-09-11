import 'package:supabase_flutter/supabase_flutter.dart';
import 'sensor_reading.dart';

class DatabaseService {
  final SupabaseClient supabase;

  DatabaseService(this.supabase);

  Future<void> signIn() async {
    await supabase.auth.signInWithPassword(
      email: 'arvidblaser@outlook.com',
      password: 'secretpassword',
    );
  }

  Future<void> signOut() async {
    await supabase.auth.signOut();
  }

  Future<void> addToDatabase(SensorReading sr, String name, String mac) async {
    await signIn();
    await supabase.from('SensorData').insert({
      "mac": mac,
      "temperature": sr.temperature,
      "humidity": sr.humidity,
      "co2": sr.ppm,
      "battery": sr.voltage,
      "name": name,
    });
    await signOut();
  }
}