// Actions only: capture this application's own window, then read its visible language.
import Foundation
import CoreGraphics
import Vision
if CommandLine.arguments[1] == "window" {
    let pid = Int(CommandLine.arguments[2])!
    let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as! [[String: Any]]
    let app = windows.filter { ($0[kCGWindowOwnerPID as String] as? Int) == pid && ($0[kCGWindowLayer as String] as? Int) == 0 }
    guard let window = app.max(by: { (($0[kCGWindowBounds as String] as? [String: Any])?["Width"] as? Double ?? 0) < (($1[kCGWindowBounds as String] as? [String: Any])?["Width"] as? Double ?? 0) }), let id = window[kCGWindowNumber as String] as? Int else { exit(2) }
    print(id)
} else {
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    request.recognitionLanguages = ["zh-Hans", "en-US"]
    request.usesLanguageCorrection = false
    try VNImageRequestHandler(url: URL(fileURLWithPath: CommandLine.arguments[2]), options: [:]).perform([request])
    print((request.results ?? []).compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n"))
}
