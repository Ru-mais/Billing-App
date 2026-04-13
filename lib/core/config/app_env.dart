class AppEnv {
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://xkjyopaxfppqhufqsgyg.supabase.co',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_3PCOSTq7qaFy2wTjo6g6Aw_SpijUKHw',
  );

  static const String environment = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'dev',
  );
}
