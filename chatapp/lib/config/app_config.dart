class AppConfig {
  // Server Configuration
  static const String _serverHost = '10.0.2.2'; // For Android Emulator
  // static const String _serverHost = '192.168.1.3'; // For Physical Device on WiFi
  // static const String _serverHost = 'localhost'; // For Web/Desktop

  static const String _serverPort = '8000';

  
  static const String baseUrl = 'http://$_serverHost:$_serverPort';
  static const String apiUrl = '$baseUrl/api';
  static const String socketUrl = baseUrl;


  static const Map<String, dynamic> socketOptions = {
    'transports': ['websocket'],
    'autoConnect': false,
  };

  
  static const int connectionTimeout = 10000; 
  static const int receiveTimeout = 10000; 

 
  static const bool enableDebugLogs = true;

  
  static const String appName = 'University Chat App';
  static const String appVersion = '1.0.0';
}


class DevConfig extends AppConfig {
  static const String baseUrl = 'http://10.0.2.2:8000'; 
  static const String apiUrl = '$baseUrl/api';
}

class ProdConfig extends AppConfig {
  static const String baseUrl = 'http://your-production-server.com:8000';
  static const String apiUrl = '$baseUrl/api';
}


class Config {
  static const bool isDevelopment = true; 

  static String get baseUrl =>
      isDevelopment ? DevConfig.baseUrl : ProdConfig.baseUrl;
  static String get apiUrl =>
      isDevelopment ? DevConfig.apiUrl : ProdConfig.apiUrl;
  static String get socketUrl => baseUrl;
}
