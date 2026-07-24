import Foundation

/// Analytics for the chapterize CLI. The Chapterize app uses the PostHog SDK,
/// but the SDK queues events and flushes on a background timer, and a
/// short-lived CLI process exits before that timer fires. Instead the CLI
/// posts one event per run directly to PostHog's capture endpoint with a short
/// timeout: the event is confirmed sent before exit, and a slow or unreachable
/// network can never hang a run for more than a few seconds.
public enum CLIAnalytics {
    /// Same project as the Chapterize app (ChapterPod's Analytics.swift) so
    /// app and CLI usage land in one PostHog project.
    public static let projectToken = "phc_ttWntAQt5WmmZXDGPyxWzq6RPeDhgHxWouZ6ncxVnYVz"

    /// PostHog's single-event capture endpoint on the same host the app uses.
    public static let endpoint = URL(string: "https://us.i.posthog.com/i/v0/e/")!

    /// Event names sent to PostHog. Raw values are pinned by tests: renaming
    /// one breaks existing dashboards. The cli_ prefix keeps CLI usage
    /// separable from the app's events in the same project.
    public enum Action: String, CaseIterable {
        case filesLoaded = "cli_files_loaded"
        case appOpened = "cli_app_opened"
    }

    /// True when the user has opted out. CHAPTERIZE_NO_ANALYTICS is ours;
    /// DO_NOT_TRACK is the cross-tool convention (consoledonottrack.com).
    /// "0" and empty mean "not opted out" so `export DO_NOT_TRACK=0` behaves
    /// the way people expect.
    public static func isDisabled(environment: [String: String]) -> Bool {
        for key in ["CHAPTERIZE_NO_ANALYTICS", "DO_NOT_TRACK"] {
            if let value = environment[key], !value.isEmpty, value != "0" {
                return true
            }
        }
        return false
    }

    /// The full capture-API request body. Pure so tests can pin the privacy
    /// properties without touching the network.
    ///
    /// `$geoip_disable` stops PostHog resolving location server side, and a
    /// null `$ip` stops the address being recorded at ingestion at all.
    /// `$process_person_profile: false` sends the event as a cheap anonymous
    /// event; the CLI never sets person properties.
    public static func payload(
        action: Action,
        distinctID: String,
        metadata: [String: Any]
    ) -> [String: Any] {
        var properties: [String: Any] = metadata
        properties["platform"] = "cli"
        properties["cli_version"] = CLIInfo.version
        let os = ProcessInfo.processInfo.operatingSystemVersion
        properties["os_version"] = "macOS \(os.majorVersion).\(os.minorVersion).\(os.patchVersion)"
        // Privacy keys go in last so no metadata key can ever override them.
        properties["$geoip_disable"] = true
        properties["$ip"] = NSNull()
        properties["$process_person_profile"] = false
        return [
            "api_key": projectToken,
            "event": action.rawValue,
            "distinct_id": distinctID,
            "properties": properties,
        ]
    }

    /// A stable anonymous ID so PostHog can count distinct CLI users rather
    /// than one undifferentiated pile of events. A random UUID persisted in
    /// the CLI's own Application Support; it identifies nothing but "same
    /// machine as last time". If the file can't be read or written the event
    /// still goes out with a one-off ID, degrading uniqueness counts, not
    /// capture.
    public static func persistentDistinctID(
        directory: URL = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("chapterize", isDirectory: true)
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
    ) -> String {
        let fileURL = directory.appendingPathComponent("analytics-id")
        if let stored = try? String(contentsOf: fileURL, encoding: .utf8) {
            let trimmed = stored.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed
            }
        }
        let fresh = UUID().uuidString.lowercased()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? fresh.write(to: fileURL, atomically: true, encoding: .utf8)
        return fresh
    }

    /// Short timeouts on a dedicated session: a run's ping should cost at
    /// most a few seconds even on a broken network.
    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 3
        configuration.timeoutIntervalForResource = 5
        return URLSession(configuration: configuration)
    }()

    /// Send one event and wait for the result. Synchronous because the CLI's
    /// command runner is synchronous and about to exit; the session timeouts
    /// bound the wait. Failures are deliberately swallowed: analytics must
    /// never fail a run that otherwise succeeded. Returns whether the event
    /// was accepted, purely so callers can log.
    @discardableResult
    public static func send(
        _ action: Action,
        metadata: [String: Any] = [:],
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> Bool {
        guard !isDisabled(environment: environment) else { return false }

        let body = payload(
            action: action,
            distinctID: persistentDistinctID(),
            metadata: metadata
        )
        guard let data = try? JSONSerialization.data(withJSONObject: body) else { return false }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = data

        let semaphore = DispatchSemaphore(value: 0)
        nonisolated(unsafe) var accepted = false
        let task = session.dataTask(with: request) { _, response, _ in
            if let http = response as? HTTPURLResponse {
                accepted = (200..<300).contains(http.statusCode)
            }
            semaphore.signal()
        }
        task.resume()
        // Backstop just past the resource timeout so a hung task can never
        // block exit.
        _ = semaphore.wait(timeout: .now() + 6)
        return accepted
    }
}
