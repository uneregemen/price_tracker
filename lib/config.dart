import 'dart:io' show Platform;

class ApiConfig {
  // Cihazın Android mi yoksa iOS/Mac mi olduğunu otomatik anlayan zeki metod
  static String get baseUrl {
    if (Platform.isAndroid) {
      return "http://10.0.2.2:8080/api";
    } else {
      // iOS simülatörü, Mac masaüstü veya Web için
      return "http://localhost:8080/api";
    }
  }
}