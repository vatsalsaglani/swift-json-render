// Owner: jr-2 (wave 2). Registered in `GalleryPages.all` by the coordinator.
import Foundation
import JSONRenderCore
import JSONRenderSwiftUI
import SwiftUI

/// Replays a stream fixture at a chosen rate, with Pause and Cancel, the journal, and the
/// coalescer's publish and drop counts. The replay renders plan rows as plain text until
/// the default `JSONRenderStreamView` initialiser (with `JSONRenderView`) exists.
struct StreamingReplayPage: View {
    static let title = "Streaming replay"

    @State private var replay = StreamReplay()

    init() {}

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            StreamReplayControls(replay: replay)
            Divider()
            HStack(alignment: .top, spacing: 16) {
                JSONRenderStreamView(model: replay.model) { snapshot, _ in
                    StreamReplayPlanList(snapshot: snapshot)
                }
                .frame(
                    minWidth: 280, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity,
                    alignment: .top)
                StreamReplayJournal(replay: replay)
                    .frame(width: 260)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

/// The transcript picker, the rate, and the Start, Pause and Cancel buttons.
private struct StreamReplayControls: View {
    @Bindable var replay: StreamReplay

    var body: some View {
        HStack(spacing: 12) {
            Picker("Transcript", selection: $replay.selected) {
                ForEach(replay.transcripts) { transcript in
                    Text(transcript.name).tag(transcript.id)
                }
            }
            .frame(maxWidth: 340)
            Picker("Rate", selection: $replay.linesPerSecond) {
                ForEach(StreamReplay.rates, id: \.self) { rate in
                    Text("\(rate) lines/s").tag(rate)
                }
            }
            .frame(maxWidth: 180)
            Button("Start") { replay.start() }
                .keyboardShortcut(.return, modifiers: .command)
            Button(replay.isPaused ? "Resume" : "Pause") { replay.togglePause() }
                .disabled(!replay.isRunning)
            Button("Cancel", role: .cancel) { replay.cancel() }
                .disabled(!replay.isRunning)
            Spacer()
            Text(replay.status)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
    }
}

/// The plan in visit order; a dangling id shows as a placeholder row while streaming.
private struct StreamReplayPlanList: View {
    let snapshot: SpecSnapshot
    @Environment(\.jrStreamPhase) private var phase

    var body: some View {
        List {
            Section("Phase: \(String(describing: phase)) · version \(snapshot.version)") {
                if snapshot.plan.rootID == nil {
                    Text("Waiting for the root element…").foregroundStyle(.secondary)
                }
                ForEach(snapshot.plan.order, id: \.self) { id in
                    if let node = snapshot.plan.nodes[id] {
                        Text("\(node.type)  \(id)")
                            .padding(.leading, CGFloat(node.depth) * 14)
                            .jrStreamReveal()
                    }
                }
                ForEach(snapshot.dangling.sorted(), id: \.self) { id in
                    Text("… \(id)")
                        .foregroundStyle(.tertiary)
                        .accessibilityLabel("Element \(id) has not arrived")
                }
            }
        }
    }
}

/// The journal: indexes, operations, paths and reasons, never values.
private struct StreamReplayJournal: View {
    let replay: StreamReplay

    var body: some View {
        List {
            Section("Journal (\(replay.model.journal.count))") {
                ForEach(Array(replay.model.journal.enumerated()), id: \.offset) { _, error in
                    Text(String(describing: error))
                        .font(.caption.monospaced())
                }
            }
        }
    }
}

/// One replayable transcript.
struct StreamTranscript: Identifiable, Hashable {
    let id: String
    let name: String
    let url: URL?
    let mode: SpecStreamDecoder.Mode
}

/// Owns the model and the feeder task of the replay page.
@MainActor @Observable
final class StreamReplay {
    static let rates = [1, 10, 100, 1_000]

    let model = StreamModel(catalog: Catalog())
    let transcripts: [StreamTranscript]
    var selected: String
    var linesPerSecond = 10
    private(set) var isRunning = false
    private(set) var isPaused = false

    @ObservationIgnored private var lines: [String] = []
    @ObservationIgnored private var nextLine = 0
    @ObservationIgnored private var input: AsyncThrowingStream<String, any Error>.Continuation?
    @ObservationIgnored private var feeder: Task<Void, Never>?
    @ObservationIgnored private var runner: Task<Void, Never>?

    init() {
        transcripts = StreamReplay.findTranscripts()
        selected = transcripts.first?.id ?? StreamReplay.builtIn.id
    }

    var status: String {
        let stats = model.frameStats
        return "published \(stats.published) · dropped \(stats.dropped)"
    }

    func start() {
        cancel()
        let transcript = transcripts.first { $0.id == selected } ?? StreamReplay.builtIn
        let text =
            transcript.url.flatMap { try? String(contentsOf: $0, encoding: .utf8) }
            ?? StreamReplay.builtInText
        lines = text.split(separator: "\n", omittingEmptySubsequences: false).map { $0 + "\n" }
        nextLine = 0
        let (stream, input) = AsyncThrowingStream.makeStream(of: String.self)
        self.input = input
        isRunning = true
        isPaused = false
        let previous = runner
        runner = Task { [model] in
            await previous?.value  // the cancelled run ends first
            await model.run(stream, mode: transcript.mode)
            self.isRunning = false
        }
        feed()
    }

    func togglePause() {
        if isPaused {
            isPaused = false
            feed()
        } else {
            isPaused = true
            feeder?.cancel()
        }
    }

    func cancel() {
        feeder?.cancel()
        input?.finish()
        input = nil
        model.cancel()
        isPaused = false
    }

    private func feed() {
        feeder?.cancel()
        let interval = Duration.seconds(1) / linesPerSecond
        feeder = Task {
            let clock = ContinuousClock()
            while nextLine < lines.count {
                do { try await clock.sleep(for: interval) } catch { return }
                input?.yield(lines[nextLine])
                nextLine += 1
            }
            input?.finish()
        }
    }

    static let builtIn = StreamTranscript(
        id: "built-in", name: "Built-in sample", url: nil, mode: .jsonl)

    static let builtInText = """
        {"op":"add","path":"/root","value":"main"}
        {"op":"add","path":"/elements/main","value":{"type":"Card","props":{"title":"Hello"},"children":["t1","t2"]}}
        {"op":"add","path":"/elements/t1","value":{"type":"Text","props":{"content":"First"}}}
        {"op":"add","path":"/elements/t2","value":{"type":"Text","props":{"content":"Second"}}}
        """

    /// The upstream and own stream fixtures, found from this file's path (works with
    /// `swift run` from a source checkout; otherwise only the built-in sample is offered).
    static func findTranscripts() -> [StreamTranscript] {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // Streaming
            .deletingLastPathComponent()  // Gallery
            .deletingLastPathComponent()  // Sources
            .deletingLastPathComponent()  // Gallery
            .deletingLastPathComponent()  // Examples
            .appendingPathComponent("Tests/ParityFixtures")
        let folders: [(String, String, SpecStreamDecoder.Mode)] = [
            ("upstream/streams", "jsonl", .jsonl),
            ("upstream/streams/mixed", "txt", .mixed),
            ("streams", "jsonl", .jsonl),
        ]
        var found: [StreamTranscript] = []
        for (folder, ext, mode) in folders {
            let directory = root.appendingPathComponent(folder)
            let names =
                (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
            for name in names.sorted() where name.hasSuffix("." + ext) {
                found.append(
                    StreamTranscript(
                        id: folder + "/" + name, name: folder + "/" + name,
                        url: directory.appendingPathComponent(name), mode: mode))
            }
        }
        return [builtIn] + found
    }
}
