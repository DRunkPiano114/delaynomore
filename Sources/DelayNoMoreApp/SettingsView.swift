import SwiftUI
import AVFoundation
import DelayNoMoreCore

final class SettingsStore: ObservableObject {
    @Published var config: AppConfig
    @Published var isCheckingForUpdates = false

    init(config: AppConfig) {
        self.config = config
    }
}

struct SettingsView: View {
    @ObservedObject var store: SettingsStore
    let onChange: (AppConfig) -> Void
    let onDismiss: () -> Void
    let onCheckForUpdates: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("settings.title", bundle: .module)
                .font(.system(size: 20, weight: .semibold))

            mediaSection
            durationsSection
            footerSection
        }
        .padding(24)
        .frame(width: 500)
    }

    private var mediaSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(LocalizedStringKey("settings.section.media"), icon: "play.rectangle.fill")

            let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(availableBuiltIns, id: \.id) { builtIn in
                    builtInTile(builtIn)
                }
                customTile
            }
        }
        .sectionStyle()
    }

    private var availableBuiltIns: [BuiltInReminderMedia] {
        ReminderMediaLibrary.builtIns.filter {
            ReminderMediaLibrary.isAvailable(.builtIn(id: $0.id))
        }
    }

    private func builtInTile(_ builtIn: BuiltInReminderMedia) -> some View {
        let media = ReminderMedia.builtIn(id: builtIn.id)
        let selected = store.config.reminder?.kind == .builtIn && store.config.reminder?.identifier == builtIn.id
        return MediaTile(
            title: builtIn.title,
            image: ReminderMediaLibrary.previewImage(for: media),
            videoURL: ReminderMediaLibrary.videoURL(for: media),
            isSelected: selected
        ) {
            store.config.reminder = .builtIn(id: builtIn.id)
            onChange(store.config)
        }
    }

    private var customTile: some View {
        let isCustom = store.config.reminder?.kind == .customImage || store.config.reminder?.kind == .customVideo

        return MediaTile(
            title: isCustom ? ReminderMediaLibrary.title(for: store.config.reminder) : L10n.string("settings.media.custom"),
            image: isCustom ? ReminderMediaLibrary.previewImage(for: store.config.reminder) : nil,
            videoURL: isCustom ? ReminderMediaLibrary.videoURL(for: store.config.reminder) : nil,
            isSelected: isCustom
        ) {
            chooseMedia()
        }
    }

    private var durationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(LocalizedStringKey("settings.section.timer"), icon: "clock.fill")

            VStack(spacing: 10) {
                DurationCard(
                    title: LocalizedStringKey("settings.timer.work"),
                    subtitle: LocalizedStringKey("settings.timer.work.subtitle"),
                    symbolName: "deskclock",
                    color: .blue,
                    seconds: Binding(
                        get: { store.config.workSeconds },
                        set: { applyWorkSeconds($0) }
                    ),
                    range: AppConfig.workSecondRange
                )

                DurationCard(
                    title: LocalizedStringKey("settings.timer.break"),
                    subtitle: LocalizedStringKey("settings.timer.break.subtitle"),
                    symbolName: "cup.and.saucer",
                    color: .green,
                    seconds: Binding(
                        get: { store.config.breakSeconds },
                        set: { applyBreakSeconds($0) }
                    ),
                    range: AppConfig.breakSecondRange
                )

                repeatToggleRow
            }
        }
        .padding(.horizontal, 14)
    }

    private var repeatToggleRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "repeat")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(Color.purple.gradient, in: RoundedRectangle(cornerRadius: 7))

            VStack(alignment: .leading, spacing: 1) {
                Text("settings.timer.repeat", bundle: .module)
                    .font(.system(size: 13, weight: .medium))
                Text("settings.timer.repeat.subtitle", bundle: .module)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Toggle(
                "",
                isOn: Binding(
                    get: { store.config.repeats },
                    set: { applyRepeats($0) }
                )
            )
            .labelsHidden()
            .controlSize(.small)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.controlBackgroundColor).opacity(0.7))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color(.separatorColor).opacity(0.55), lineWidth: 0.5)
        )
    }

    private var footerSection: some View {
        HStack(spacing: 8) {
            Button {
                onCheckForUpdates()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 10))
                    Text(
                        store.isCheckingForUpdates
                            ? LocalizedStringKey("settings.checking")
                            : LocalizedStringKey("settings.checkForUpdates"),
                        bundle: .module
                    )
                    .font(.system(size: 12))
                }
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
            .disabled(store.isCheckingForUpdates)

            Text("v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0")")
                .font(.system(size: 11))
                .foregroundColor(Color(.quaternaryLabelColor))

            Spacer()

            Button(action: onDismiss) {
                Text("settings.done", bundle: .module)
            }
            .controlSize(.regular)
        }
        .padding(.top, 4)
    }

    private func sectionHeader(_ title: LocalizedStringKey, icon: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            Text(title, bundle: .module)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)
        }
    }

    private func applyWorkSeconds(_ seconds: Int) {
        store.config.workSeconds = min(max(seconds, AppConfig.workSecondRange.lowerBound), AppConfig.workSecondRange.upperBound)
        onChange(store.config)
    }

    private func applyBreakSeconds(_ seconds: Int) {
        store.config.breakSeconds = min(max(seconds, AppConfig.breakSecondRange.lowerBound), AppConfig.breakSecondRange.upperBound)
        onChange(store.config)
    }

    private func applyRepeats(_ repeats: Bool) {
        store.config.repeats = repeats
        onChange(store.config)
    }

    private func chooseMedia() {
        let panel = NSOpenPanel()
        panel.title = L10n.string("panel.chooseMedia.title")
        panel.message = L10n.string("panel.chooseMedia.message")
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = ReminderMediaLibrary.allowedContentTypes

        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard let reminder = ReminderMediaLibrary.media(for: url) else { return }

        store.config.reminder = reminder
        onChange(store.config)
    }
}

private enum TimeComponent: Hashable {
    case hour
    case minute
    case second

    var next: TimeComponent? {
        switch self {
        case .hour:
            return .minute
        case .minute:
            return .second
        case .second:
            return nil
        }
    }
}

private struct DurationCard: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    let symbolName: String
    let color: Color
    @Binding var seconds: Int
    let range: ClosedRange<Int>

    @FocusState private var focusedComponent: TimeComponent?

    private var hours: Int { seconds / 3600 }
    private var minutes: Int { (seconds % 3600) / 60 }
    private var secondsComponent: Int { seconds % 60 }
    private var hourRange: ClosedRange<Int> { 0...(range.upperBound / 3600) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            timeEditor
                .frame(maxWidth: .infinity, alignment: .center)

            HStack(spacing: 10) {
                Image(systemName: symbolName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 28, height: 28)
                    .background(color.gradient, in: RoundedRectangle(cornerRadius: 7))

                VStack(alignment: .leading, spacing: 1) {
                    Text(title, bundle: .module)
                        .font(.system(size: 13, weight: .medium))
                    Text(subtitle, bundle: .module)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.controlBackgroundColor).opacity(0.82))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color(.separatorColor).opacity(0.65), lineWidth: 0.5)
        )
    }

    private var timeEditor: some View {
        HStack(alignment: .bottom, spacing: 7) {
            segment(
                component: .hour,
                unit: LocalizedStringKey("settings.timer.hourUnit"),
                value: hours,
                range: hourRange
            ) { set(.hour, to: $0) }

            separator

            segment(
                component: .minute,
                unit: LocalizedStringKey("settings.timer.minuteUnit"),
                value: minutes,
                range: 0...59
            ) { set(.minute, to: $0) }

            separator

            segment(
                component: .second,
                unit: LocalizedStringKey("settings.timer.secondUnit"),
                value: secondsComponent,
                range: 0...59
            ) { set(.second, to: $0) }
        }
    }

    private var separator: some View {
        Text(":")
            .font(.system(size: 42, weight: .light, design: .monospaced))
            .foregroundColor(Color(.secondaryLabelColor))
            .padding(.bottom, 1)
            .frame(width: 10)
    }

    private func segment(
        component: TimeComponent,
        unit: LocalizedStringKey,
        value: Int,
        range: ClosedRange<Int>,
        onCommit: @escaping (Int) -> Int
    ) -> some View {
        VStack(spacing: 4) {
            Text(unit, bundle: .module)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Color(.secondaryLabelColor))

            TimeSegmentField(
                component: component,
                value: value,
                range: range,
                focusedComponent: $focusedComponent,
                onCommit: onCommit
            ) {
                focusedComponent = component.next
            }
        }
        .frame(width: 70)
    }

    private func set(_ component: TimeComponent, to value: Int) -> Int {
        let nextHours: Int
        let nextMinutes: Int
        let nextSeconds: Int

        switch component {
        case .hour:
            nextHours = clamp(value, to: hourRange)
            nextMinutes = minutes
            nextSeconds = secondsComponent
        case .minute:
            nextHours = hours
            nextMinutes = clamp(value, to: 0...59)
            nextSeconds = secondsComponent
        case .second:
            nextHours = hours
            nextMinutes = minutes
            nextSeconds = clamp(value, to: 0...59)
        }

        let nextTotal = nextHours * 3600 + nextMinutes * 60 + nextSeconds
        let clampedTotal = clamp(nextTotal, to: range)
        seconds = clampedTotal

        return componentValue(of: component, in: clampedTotal)
    }

    private func componentValue(of component: TimeComponent, in totalSeconds: Int) -> Int {
        switch component {
        case .hour:
            return totalSeconds / 3600
        case .minute:
            return (totalSeconds % 3600) / 60
        case .second:
            return totalSeconds % 60
        }
    }

    private func clamp(_ value: Int, to range: ClosedRange<Int>) -> Int {
        min(max(value, range.lowerBound), range.upperBound)
    }
}

private struct TimeSegmentField: View {
    let component: TimeComponent
    let value: Int
    let range: ClosedRange<Int>
    let focusedComponent: FocusState<TimeComponent?>.Binding
    let onCommit: (Int) -> Int
    let onAdvance: () -> Void

    @State private var draft = ""

    var body: some View {
        TextField("", text: $draft)
            .font(.system(size: 44, weight: .light, design: .monospaced))
            .foregroundColor(Color(.labelColor))
            .multilineTextAlignment(.center)
            .textFieldStyle(.plain)
            .frame(width: 70, height: 52)
            .focused(focusedComponent, equals: component)
            .onAppear {
                draft = formatted(value)
            }
            .onChange(of: value) { newValue in
                if focusedComponent.wrappedValue != component {
                    draft = formatted(newValue)
                }
            }
            .onChange(of: focusedComponent.wrappedValue) { focused in
                if focused == component {
                    draft = ""
                } else {
                    commit()
                }
            }
            .onChange(of: draft) { newValue in
                normalize(newValue)
            }
            .onSubmit {
                commit()
                onAdvance()
            }
    }

    private func normalize(_ newValue: String) {
        guard focusedComponent.wrappedValue == component else { return }

        let sanitized = String(newValue.filter(\.isNumber).prefix(2))
        guard sanitized == newValue else {
            draft = sanitized
            return
        }

        if sanitized.count == 2 {
            commit()
            DispatchQueue.main.async {
                onAdvance()
            }
        }
    }

    private func commit() {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        let parsed = Int(trimmed) ?? value
        let clamped = min(max(parsed, range.lowerBound), range.upperBound)
        let normalized = onCommit(clamped)
        draft = formatted(normalized)
    }

    private func formatted(_ value: Int) -> String {
        String(format: "%02d", value)
    }
}

struct MediaTile: View {
    let title: String
    let image: NSImage?
    let videoURL: URL?
    let isSelected: Bool
    let onClick: () -> Void

    @State private var isHovering = false
    @State private var player: AVPlayer?
    @State private var loopObserver: NSObjectProtocol?

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                if let image {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Color(.controlBackgroundColor)
                    Image(systemName: "photo.badge.plus")
                        .font(.system(size: 16))
                        .foregroundColor(Color(.tertiaryLabelColor))
                }

                if isHovering, player != nil {
                    VideoPreviewView(player: player!)
                }
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(16.0 / 9.0, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(
                        isSelected ? Color.accentColor : Color(.separatorColor).opacity(0.5),
                        lineWidth: isSelected ? 2.5 : 1
                    )
            )
            .onHover { hovering in
                isHovering = hovering
                if hovering, let videoURL {
                    startPreview(url: videoURL)
                } else {
                    stopPreview()
                }
            }
            .onDisappear { stopPreview() }

            Text(title)
                .font(.system(size: NSFont.smallSystemFontSize))
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity)
        }
        .contentShape(Rectangle())
        .onTapGesture { onClick() }
        .cursor(.pointingHand)
    }

    private func startPreview(url: URL) {
        let p = AVPlayer(url: url)
        p.isMuted = true
        player = p
        p.play()

        loopObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: p.currentItem,
            queue: .main
        ) { _ in
            p.seek(to: .zero)
            p.play()
        }
    }

    private func stopPreview() {
        player?.pause()
        if let obs = loopObserver {
            NotificationCenter.default.removeObserver(obs)
            loopObserver = nil
        }
        player = nil
    }
}

struct VideoPreviewView: NSViewRepresentable {
    let player: AVPlayer

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.wantsLayer = true
        let layer = AVPlayerLayer(player: player)
        layer.videoGravity = .resizeAspectFill
        view.layer = layer
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if let layer = nsView.layer as? AVPlayerLayer {
            layer.player = player
        }
    }
}

private extension View {
    func sectionStyle() -> some View {
        self
            .padding(14)
            .background(Color(.controlBackgroundColor).opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color(.separatorColor).opacity(0.5), lineWidth: 0.5)
            )
    }

    func cursor(_ cursor: NSCursor) -> some View {
        onHover { inside in
            if inside { cursor.push() } else { NSCursor.pop() }
        }
    }
}
