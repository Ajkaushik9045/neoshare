import Flutter
import UIKit
import UniformTypeIdentifiers

@main
@objc class AppDelegate: FlutterAppDelegate, UIDocumentPickerDelegate {

    private var pendingPickCompletion: ((Result<[PickedFileInfo], Error>) -> Void)?
    private var flutterViewController: FlutterViewController?
    private let tag = "NeoShare[Pigeon]"

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        let controller = window?.rootViewController as! FlutterViewController
        self.flutterViewController = controller
        FileHostApiSetup.setUp(binaryMessenger: controller.binaryMessenger, api: self)
        NSLog("\(tag): FileHostApi registered on binary messenger")
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
        GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    }
}

// MARK: - FileHostApi

extension AppDelegate: FileHostApi {

    // ── pickFiles ──────────────────────────────────────────────────────────────

    func pickFiles(completion: @escaping (Result<[PickedFileInfo], Error>) -> Void) {
        NSLog("\(tag): pickFiles() called via Pigeon")
        pendingPickCompletion = completion
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.item], asCopy: true)
        picker.delegate = self
        picker.allowsMultipleSelection = true
        DispatchQueue.main.async { [weak self] in
            self?.flutterViewController?.present(picker, animated: true)
        }
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        NSLog("\(tag): documentPicker: \(urls.count) file(s) selected")
        let results: [PickedFileInfo] = urls.compactMap { url in
            guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path) else { return nil }
            let sizeBytes = (attrs[.size] as? NSNumber)?.int64Value ?? 0
            let mimeType = mimeTypeFor(url: url)
            NSLog("\(tag): Pigeon pickFiles: staged '\(url.lastPathComponent)' (\(sizeBytes) bytes, \(mimeType)) at \(url.path)")
            return PickedFileInfo(
                path: url.path,
                name: url.lastPathComponent,
                sizeBytes: sizeBytes,
                mimeType: mimeType
            )
        }
        pendingPickCompletion?(.success(results))
        pendingPickCompletion = nil
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        NSLog("\(tag): pickFiles: user cancelled")
        pendingPickCompletion?(.success([]))
        pendingPickCompletion = nil
    }

    private func mimeTypeFor(url: URL) -> String {
        if let utType = UTType(filenameExtension: url.pathExtension),
           let mimeType = utType.preferredMIMEType {
            return mimeType
        }
        return "application/octet-stream"
    }

    // ── saveToDownloads ────────────────────────────────────────────────────────

    func saveToDownloads(
        tempPath: String,
        mimeType: String,
        fileName: String,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        NSLog("\(tag): saveToDownloads() '\(fileName)' from '\(tempPath)'")
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dest = documents.appendingPathComponent(fileName)
        do {
            if FileManager.default.fileExists(atPath: dest.path) {
                try FileManager.default.removeItem(at: dest)
            }
            try FileManager.default.copyItem(at: URL(fileURLWithPath: tempPath), to: dest)
            NSLog("\(tag): saveToDownloads: '\(fileName)' → \(dest.path)")
            completion(.success(dest.path))
        } catch {
            NSLog("\(tag): saveToDownloads failed for '\(fileName)': \(error.localizedDescription)")
            completion(.failure(error))
        }
    }

    // ── getFreeSpace ───────────────────────────────────────────────────────────

    func getFreeSpace(completion: @escaping (Result<Int64, Error>) -> Void) {
        NSLog("\(tag): getFreeSpace() called via Pigeon")
        do {
            let attrs = try FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory())
            if let free = attrs[.systemFreeSize] as? NSNumber {
                NSLog("\(tag): getFreeSpace: \(free.int64Value / 1024 / 1024) MB available")
                completion(.success(free.int64Value))
            } else {
                completion(.failure(PigeonError(code: "-1", message: "Could not read free space", details: nil)))
            }
        } catch {
            completion(.failure(error))
        }
    }
}
