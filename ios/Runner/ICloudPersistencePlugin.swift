import Flutter
import Foundation

final class ICloudPersistencePlugin: NSObject, FlutterPlugin {
  private static let containerIdentifier = "iCloud.ai.atiq.workRings"

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "work_rings/icloud",
      binaryMessenger: registrar.messenger()
    )
    registrar.addMethodCallDelegate(ICloudPersistencePlugin(), channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard
      let arguments = call.arguments as? [String: Any],
      let fileName = arguments["fileName"] as? String,
      !fileName.isEmpty
    else {
      result(FlutterError(code: "invalid_arguments", message: "A file name is required.", details: nil))
      return
    }

    DispatchQueue.global(qos: .utility).async {
      do {
        let fileURL = try self.fileURL(named: fileName)
        switch call.method {
        case "read":
          let value = try self.read(fileName: fileName, preferredURL: fileURL)
          NSLog("Work Rings iCloud: read completed for %@", fileName)
          DispatchQueue.main.async { result(value) }
        case "write":
          guard let contents = arguments["contents"] as? String else {
            throw CloudFileError.invalidContents
          }
          try self.write(contents, to: fileURL)
          NSLog("Work Rings iCloud: write completed for %@", fileName)
          DispatchQueue.main.async { result(nil) }
        default:
          DispatchQueue.main.async { result(FlutterMethodNotImplemented) }
        }
      } catch {
        NSLog("Work Rings iCloud: %@ failed: %@", call.method, error.localizedDescription)
        DispatchQueue.main.async {
          result(FlutterError(code: "icloud_unavailable", message: error.localizedDescription, details: nil))
        }
      }
    }
  }

  private func fileURL(named fileName: String) throws -> URL {
    guard let container = FileManager.default.url(
      forUbiquityContainerIdentifier: Self.containerIdentifier
    ) else {
      throw CloudFileError.containerUnavailable
    }
    let documents = container.appendingPathComponent("Documents", isDirectory: true)
    try FileManager.default.createDirectory(at: documents, withIntermediateDirectories: true)
    return documents.appendingPathComponent(fileName, isDirectory: false)
  }

  private func read(fileName: String, preferredURL: URL) throws -> String? {
    let fileManager = FileManager.default
    let url: URL
    if fileManager.fileExists(atPath: preferredURL.path) {
      url = preferredURL
    } else if let discoveredURL = try discoverUbiquitousFile(named: fileName) {
      try fileManager.startDownloadingUbiquitousItem(at: discoveredURL)
      url = discoveredURL
    } else {
      return nil
    }

    var coordinationError: NSError?
    var readError: Error?
    var contents: String?
    NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordinationError) { coordinatedURL in
      do {
        contents = try String(contentsOf: coordinatedURL, encoding: .utf8)
      } catch {
        readError = error
      }
    }
    if let error = coordinationError { throw error }
    if let error = readError { throw error }
    return contents
  }

  /// A remote iCloud document may have synchronized metadata without having a
  /// local filesystem entry yet. Querying the ubiquitous Documents scope is
  /// therefore required before requesting its contents.
  private func discoverUbiquitousFile(named fileName: String) throws -> URL? {
    let query = NSMetadataQuery()
    query.operationQueue = .main
    query.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]
    query.predicate = NSPredicate(format: "%K == %@", NSMetadataItemFSNameKey, fileName)

    let finished = DispatchSemaphore(value: 0)
    let center = NotificationCenter.default
    let observer = center.addObserver(
      forName: .NSMetadataQueryDidFinishGathering,
      object: query,
      queue: .main
    ) { _ in
      query.disableUpdates()
      finished.signal()
    }
    defer {
      center.removeObserver(observer)
      DispatchQueue.main.sync { query.stop() }
    }

    let didStart = DispatchQueue.main.sync { query.start() }
    guard didStart else { throw CloudFileError.metadataQueryFailed }
    guard finished.wait(timeout: .now() + 15) == .success else {
      throw CloudFileError.metadataQueryTimedOut
    }
    guard
      query.resultCount > 0,
      let item = query.result(at: 0) as? NSMetadataItem,
      let url = item.value(forAttribute: NSMetadataItemURLKey) as? URL
    else {
      return nil
    }
    return url
  }

  private func write(_ contents: String, to url: URL) throws {
    var coordinationError: NSError?
    var writeError: Error?
    NSFileCoordinator().coordinate(writingItemAt: url, options: .forReplacing, error: &coordinationError) { coordinatedURL in
      do {
        try contents.write(to: coordinatedURL, atomically: true, encoding: .utf8)
      } catch {
        writeError = error
      }
    }
    if let error = coordinationError ?? writeError as NSError? { throw error }
  }
}

private enum CloudFileError: LocalizedError {
  case containerUnavailable
  case invalidContents
  case metadataQueryFailed
  case metadataQueryTimedOut

  var errorDescription: String? {
    switch self {
    case .containerUnavailable:
      return "iCloud Drive is unavailable. Check that iCloud Drive is enabled."
    case .invalidContents:
      return "The cloud document contents are missing."
    case .metadataQueryFailed:
      return "iCloud could not start searching for the cloud document."
    case .metadataQueryTimedOut:
      return "iCloud did not finish searching for the cloud document in time."
    }
  }
}
