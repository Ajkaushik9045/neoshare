import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(PigeonOptions(
  dartOut: 'lib/core/platform/file_api.g.dart',
  dartOptions: DartOptions(),
  kotlinOut: 'android/app/src/main/kotlin/com/example/neoshare/FileApi.g.kt',
  kotlinOptions: KotlinOptions(package: 'com.example.neoshare'),
  swiftOut: 'ios/Runner/FileApi.g.swift',
  swiftOptions: SwiftOptions(),
))

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

  /// Save a file from [tempPath] to the public Downloads folder via MediaStore (Android)
  /// or the app's Documents directory (iOS). Returns the final saved path / content URI.
  @async
  String saveToDownloads(String tempPath, String mimeType, String fileName);

  /// Returns available storage space in bytes.
  @async
  int getFreeSpace();
}
