class VisionConfig {
  // TODO: Replace with your Google Cloud Vision API key
  // Secure this key using restricted API keys and do not commit real keys.
  static const String apiKey = 'AIzaSyCSe6v3uTPnl9aEEqd4MDFybiszHj_vO64';

  static String get endpoint => 'https://vision.googleapis.com/v1/images:annotate?key=$apiKey';
}


