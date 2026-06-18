import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  SupabaseClient get client => Supabase.instance.client;

  String? get currentUserId => client.auth.currentUser?.id;
  String? get currentUserEmail => client.auth.currentUser?.email;
}
