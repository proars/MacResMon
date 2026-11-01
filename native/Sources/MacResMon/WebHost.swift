import AppKit
import WebKit
import MonitorCore

/// Serves the bundled web UI (`dist/`) to the web view through an `app://` scheme.
/// A custom scheme (instead of file://) lets the ES-module bundle load with absolute /assets paths.
final class DistSchemeHandler: NSObject, WKURLSchemeHandler {
    private let root: URL
    init(root: URL) { self.root = root.standardizedFileURL }

    private static let mime = ["html": "text/html; charset=utf-8", "js": "text/javascript; charset=utf-8", "css": "text/css; charset=utf-8",
                               "svg": "image/svg+xml", "png": "image/png", "json": "application/json", "ico": "image/x-icon", "woff2": "font/woff2"]

    func webView(_ webView: WKWebView, start task: WKURLSchemeTask) {
        guard let url = task.request.url else { task.didFailWithError(URLError(.badURL)); return }
        var path = url.path.removingPercentEncoding ?? url.path
        if path.isEmpty || path == "/" { path = "/index.html" }
        let file = root.appendingPathComponent(path).standardizedFileURL
        // Never serve anything outside the dist folder.
        guard file.path.hasPrefix(root.path + "/"), let data = try? Data(contentsOf: file) else {
            let r = HTTPURLResponse(url: url, statusCode: 404, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "text/plain"])!
            task.didReceive(r); task.didReceive(Data("Not Found".utf8)); task.didFinish()
            return
        }
        let type = Self.mime[file.pathExtension.lowercased()] ?? "application/octet-stream"
        let r = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1",
                                headerFields: ["Content-Type": type, "Content-Length": "\(data.count)", "Cache-Control": "no-cache"])!
        task.didReceive(r); task.didReceive(data); task.didFinish()
    }

    func webView(_ webView: WKWebView, stop task: WKURLSchemeTask) {}
}

/// Where the built UI lives: inside the .app, or `../dist` when run from the package directory.
func distURL() -> URL? {
    let fm = FileManager.default
    let candidates = [
        ProcessInfo.processInfo.environment["MONITOR_DIST"].map { URL(fileURLWithPath: $0) },
        Bundle.main.resourceURL?.appendingPathComponent("dist"),
        URL(fileURLWithPath: fm.currentDirectoryPath).appendingPathComponent("../dist"),
    ].compactMap { $0 }
    return candidates.first { fm.fileExists(atPath: $0.appendingPathComponent("index.html").path) }
}

/// Injected before the page's scripts: a tiny hub the UI subscribes to instead of opening an EventSource.
/// Swift pushes `history` and `snapshot` events into it; late subscribers get the latest state replayed.
let hubScript = """
window.__nativeHub = (() => {
  const subs = new Set(); let history = null, snapshot = null;
  return {
    subscribe(fn) { subs.add(fn); if (history) fn('history', history); if (snapshot) fn('snapshot', snapshot); return () => subs.delete(fn); },
    emit(type, data) { if (type === 'history') history = data; else if (type === 'snapshot') snapshot = data; subs.forEach((f) => f(type, data)); },
  };
})();
// Page -> app: answers come back as a Promise of text (see ReportActions.handle).
window.__native = { request: (type, data) => window.webkit.messageHandlers.native.postMessage({ type, data: data || {} }) };
"""

final class WebHost: NSObject, WKNavigationDelegate, WKScriptMessageHandlerWithReply {
    let webView: WKWebView
    var onLoaded: (() -> Void)?
    /// A request from the page: (type, data, reply). Called on the main thread.
    var onRequest: ((String, [String: Any], @escaping (String) -> Void) -> Void)?

    override init() {
        let config = WKWebViewConfiguration()
        if let dist = distURL() { config.setURLSchemeHandler(DistSchemeHandler(root: dist), forURLScheme: "app") }
        webView = WKWebView(frame: .zero, configuration: config)
        super.init()
        installHub()
        config.userContentController.addScriptMessageHandler(self, contentWorld: .page, name: "native")
        webView.navigationDelegate = self
        if #available(macOS 13.3, *) { webView.isInspectable = true }
        webView.setValue(false, forKey: "drawsBackground") // no white flash before the page paints
    }

    /// UI choices the page remembers (theme, tab, report period): kept in UserDefaults and handed to the page before
    /// its scripts run as `window.__webState`, because WebKit's localStorage is not reliably kept for the app:// scheme.
    func installHub() {
        let state = jsonString(Preferences.shared.webState)
        let controller = webView.configuration.userContentController
        controller.removeAllUserScripts()
        controller.addUserScript(WKUserScript(source: hubScript + "\nwindow.__webState = \(state);", injectionTime: .atDocumentStart, forMainFrameOnly: true))
    }

    func load() {
        if distURL() == nil {
            webView.loadHTMLString("<body style='font:15px -apple-system;padding:40px'><h2>UI not found</h2><p>Run <code>npm run build</code> in the project root, or use native/build.sh.</p>", baseURL: nil)
        } else {
            webView.load(URLRequest(url: URL(string: "app://monitor/")!))
        }
    }

    /// Pushes an event into the page. The script is a constant and the data travels as an argument: building a
    /// new script string with the data inside it every second made WebKit's memory grow steadily.
    func emit(_ type: String, _ json: String) {
        webView.callAsyncJavaScript("window.__nativeHub && window.__nativeHub.emit(type, JSON.parse(json))",
                                    arguments: ["type": type, "json": json], in: nil, in: .page, completionHandler: nil)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { onLoaded?() }

    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage, replyHandler: @escaping (Any?, String?) -> Void) {
        guard let body = message.body as? [String: Any], let type = body["type"] as? String, let onRequest = onRequest else { replyHandler(nil, "bad request"); return }
        onRequest(type, body["data"] as? [String: Any] ?? [:]) { replyHandler($0, nil) }
    }

    /// Writes a PNG of the web view (used by `--screenshot <file>` for docs and checks).
    func snapshot(to path: String, done: @escaping () -> Void) {
        webView.takeSnapshot(with: nil) { image, _ in
            if let tiff = image?.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff), let png = rep.representation(using: .png, properties: [:]) {
                try? png.write(to: URL(fileURLWithPath: path))
            }
            done()
        }
    }
}
