import 'package:package_info_plus/package_info_plus.dart';

Future<void> _getAppInfo() async {
  PackageInfo packageInfo = await PackageInfo.fromPlatform();

  String appName = packageInfo.appName; // Your app name
  String packageName =
      packageInfo.packageName; // Package name (com.example.app)
  String version = packageInfo.version; // e.g. "1.0.2"
  String buildNumber = packageInfo.buildNumber; // e.g. "10"

  print("App Name: $appName");
  print("Package Name: $packageName");
  print("App Version: $version");
  print("Build Number: $buildNumber");
}
