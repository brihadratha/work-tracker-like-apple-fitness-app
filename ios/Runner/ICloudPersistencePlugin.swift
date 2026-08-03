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
          let value = try self.read(from: fileURL)
          DispatchQueue.main.async { result(value) }
        case "write":
          guard let contents = arguments["contents"] as? String else {
            throw CloudFileError.invalidContents
          }
          try self.write(contents, to: fileURL)
          DispatchQueue.main.async { result(nil) }
        default:
          DispatchQueue.main.async { result(FlutterMethodNotImplemented) }
        }
      } catch {
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

  private func read(from url: URL) throws -> String? {
    guard FileManager.default.fileExists(atPath: url.path) else { return nil }
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
    if let error = coordinationError ?? readError as NSError? { throw error }
    return contents
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

  var errorDescription: String? {
    switch self {
    case .containerUnavailable:
      return "iCloud Drive is unavailable. Check that iCloud Drive is enabled."
    case .invalidContents:
      return "The cloud document contents are missing."
    }
  }
}
