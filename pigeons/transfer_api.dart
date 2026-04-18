import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(PigeonOptions(
  dartOut: 'lib/core/platform/transfer_api.g.dart',
  dartOptions: DartOptions(),
  kotlinOut:
      'android/app/src/main/kotlin/com/example/neoshare/TransferApi.g.kt',
  kotlinOptions: KotlinOptions(package: 'com.example.neoshare'),
  swiftOut: 'ios/Runner/TransferApi.g.swift',
  swiftOptions: SwiftOptions(),
))

// ─── File API ────────────────────────────────────────────────────────────────

/// Model returned by [FileHostApi.pickFiles] describing a natively-picked file.
class PickedFileInfo {
  PickedFileInfo({
    required this.path,
    required this.name,
    required this.sizeBytes,
    required this.mimeType,
  });
  String path;
  String name;
  int sizeBytes;
  String mimeType;
}

@HostApi()
abstract class FileHostApi {
  /// Open the native file picker (supports multi-select).
  /// Returns a list of [PickedFileInfo] objects for each selected file.
  @async
  List<PickedFileInfo> pickFiles();

  /// Save a file from [tempPath] to the public Downloads folder via MediaStore
  /// (Android) or the app's Documents directory (iOS).
  /// Returns the final saved path / content URI.
  @async
  String saveToDownloads(String tempPath, String mimeType, String fileName);

  /// Returns available storage space in bytes.
  @async
  int getFreeSpace();
}

// ─── Transfer Service API ─────────────────────────────────────────────────────

/// Flutter → Android: control the TransferForegroundService.
@HostApi()
abstract class TransferServiceHostApi {
  /// Start the foreground service for the given transfer.
  void startUploadService(String transferId);

  /// Stop the foreground service (upload finished or cancelled).
  void stopUploadService();

  /// Update the persistent notification progress (0–100).
  void updateProgress(int percent);
}

/// Android → Flutter: service lifecycle callbacks.
@FlutterApi()
abstract class TransferServiceFlutterApi {
  /// Called when the OS restarts the service after killing it under memory pressure.
  void onServiceRestarted(String transferId);
}
