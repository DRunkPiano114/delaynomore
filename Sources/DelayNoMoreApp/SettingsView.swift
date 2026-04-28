import SwiftUI
import AVFoundation
import DelayNoMoreCore

private enum SettingsLayout {
    static let windowWidth: CGFloat = 580
    static let windowPadding: CGFloat = 22
    static let columnSpacing: CGFloat = 18
    static let mediaColumnWidth: CGFloat = 280
    static let timerColumnWidth: CGFloat = 238
}

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

    @FocusState private var focusedTimeField: FocusedTimeField?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("settings.title", bundle: .module)
                .font(.system(size: 22, weight: .semibold))
                .contentShape(Rectangle())
                .onTapGesture { clearTimeFocus() }

            HStack(alignment: .top, spacing: SettingsLayout.columnSpacing) {
                mediaSection
                    .frame(width: SettingsLayout.mediaColumnWidth)
                durationsSection
                    .frame(width: SettingsLayout.timerColumnWidth)
            }

            footerSection
        }
        .padding(SettingsLayout.windowPadding)
        .frame(width: SettingsLayout.windowWidth)
        .background {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { clearTimeFocus() }
        }
        .onAppear {
            DispatchQueue.main.async {
                clearTimeFocus()
            }
        }
    }

    private var mediaSection: some View {
        VStack(alignment: .leading, spacing: 13) {
            sectionHeader(LocalizedStringKey("settings.section.media"), icon: "play.rectangle.fill")

            let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 2)
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
            clearTimeFocus()
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
            clearTimeFocus()
            chooseMedia()
        }
    }

    private var durationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(LocalizedStringKey("settings.section.timer"), icon: "clock.fill")

            VStack(spacing: 10) {
                DurationCard(
                    kind: .work,
                    title: LocalizedStringKey("settings.timer.work"),
                    subtitle: LocalizedStringKey("settings.timer.work.subtitle"),
                    symbolName: "deskclock",
                    color: .blue,
                    seconds: Binding(
                        get: { store.config.workSeconds },
                        set: { applyWorkSeconds($0) }
                    ),
                    range: AppConfig.workSecondRange,
                    focusedField: $focusedTimeField
                )

                DurationCard(
                    kind: .break,
                    title: LocalizedStringKey("settings.timer.break"),
                    subtitle: LocalizedStringKey("settings.timer.break.subtitle"),
                    symbolName: "cup.and.saucer",
                    color: .green,
                    seconds: Binding(
                        get: { store.config.breakSeconds },
                        set: { applyBreakSeconds($0) }
                    ),
                    range: AppConfig.breakSecondRange,
                    focusedField: $focusedTimeField
                )

                repeatToggleRow
            }
        }
    }

    private var repeatToggleRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "repeat")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 30, height: 30)
                .background(Color.purple.gradient, in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 1) {
                Text("settings.timer.repeat", bundle: .module)
                    .font(.system(size: 14, weight: .medium))
                Text("settings.timer.repeat.subtitle", bundle: .module)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            Spacer()

            PillToggleButton(isOn: store.config.repeats) {
                clearTimeFocus()
                applyRepeats(!store.config.repeats)
            }
        }
        .padding(13)
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
                clearTimeFocus()
                onCheckForUpdates()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 11))
                    Text(
                        store.isCheckingForUpdates
                            ? LocalizedStringKey("settings.checking")
                            : LocalizedStringKey("settings.checkForUpdates"),
                        bundle: .module
                    )
                    .font(.system(size: 13))
                }
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
            .disabled(store.isCheckingForUpdates)

            Text("v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0")")
                .font(.system(size: 12))
                .foregroundColor(Color(.quaternaryLabelColor))

            Spacer()

            Button {
                clearTimeFocus()
                onDismiss()
            } label: {
                Text("settings.done", bundle: .module)
            }
            .controlSize(.regular)
        }
        .padding(.top, 4)
    }

    private func sectionHeader(_ title: LocalizedStringKey, icon: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            Text(title, bundle: .module)
                .font(.system(size: 13, weight: .medium))
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

    private func clearTimeFocus() {
        focusedTimeField = nil
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

private struct PillToggleButton: View {
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: isOn ? .trailing : .leading) {
                RoundedRectangle(cornerRadius: 16)
                    .fill(isOn ? Color.orange : Color(.tertiaryLabelColor).opacity(0.28))
                    .frame(width: 56, height: 30)

                Circle()
                    .fill(Color(.controlBackgroundColor))
                    .frame(width: 24, height: 24)
                    .padding(3)
                    .shadow(color: .black.opacity(0.12), radius: 2, y: 1)
            }
            .frame(width: 56, height: 30)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("settings.timer.repeat", bundle: .module))
        .accessibilityValue(isOn ? "On" : "Off")
        .animation(.easeOut(duration: 0.16), value: isOn)
    }
}

private enum TimeComponent: Hashable {
    case hour
    case minute
    case second
}

private enum DurationKind: Hashable {
    case work
    case `break`
}

private struct FocusedTimeField: Hashable {
    let kind: DurationKind
    let component: TimeComponent
}

private struct DurationCard: View {
    let kind: DurationKind
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    let symbolName: String
    let color: Color
    @Binding var seconds: Int
    let range: ClosedRange<Int>
    let focusedField: FocusState<FocusedTimeField?>.Binding

    private var hours: Int { seconds / 3600 }
    private var minutes: Int { (seconds % 3600) / 60 }
    private var secondsComponent: Int { seconds % 60 }
    private var hourRange: ClosedRange<Int> { 0...(range.upperBound / 3600) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            timeEditor
                .frame(maxWidth: .infinity, alignment: .center)

            HStack(spacing: 10) {
                Image(systemName: symbolName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 30, height: 30)
                    .background(color.gradient, in: RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title, bundle: .module)
                        .font(.system(size: 14, weight: .medium))
                    Text(subtitle, bundle: .module)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .contentShape(Rectangle())
            .onTapGesture {
                focusedField.wrappedValue = nil
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
        HStack(alignment: .bottom, spacing: 4) {
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
            .font(.system(size: 40, weight: .light, design: .monospaced))
            .foregroundColor(Color(.secondaryLabelColor))
            .padding(.bottom, 1)
            .frame(width: 8)
    }

    private func segment(
        component: TimeComponent,
        unit: LocalizedStringKey,
        value: Int,
        range: ClosedRange<Int>,
        onCommit: @escaping (Int) -> Int
    ) -> some View {
        VStack(spacing: 5) {
            Text(unit, bundle: .module)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color(.secondaryLabelColor))

            TimeSegmentField(
                focus: FocusedTimeField(kind: kind, component: component),
                value: value,
                range: range,
                focusedField: focusedField,
                onCommit: onCommit
            )
        }
        .frame(width: 56)
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

        let clampedTotal = normalizedTotal(
            editing: component,
            hours: nextHours,
            minutes: nextMinutes,
            seconds: nextSeconds
        )
        seconds = clampedTotal

        return componentValue(of: component, in: clampedTotal)
    }

    private func normalizedTotal(editing component: TimeComponent, hours: Int, minutes: Int, seconds: Int) -> Int {
        let total = hours * 3600 + minutes * 60 + seconds

        if range.contains(total) {
            return total
        }

        if total < range.lowerBound {
            return range.lowerBound
        }

        // Preserve the segment being edited when the total duration must be capped.
        // Otherwise minute/second edits at the max hour appear to turn into 00.
        switch component {
        case .hour:
            return range.upperBound
        case .minute, .second:
            let lowerComponents = minutes * 60 + seconds
            guard lowerComponents <= range.upperBound else {
                return range.upperBound
            }

            let adjustedHours = min(hours, (range.upperBound - lowerComponents) / 3600)
            return max(range.lowerBound, adjustedHours * 3600 + lowerComponents)
        }
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
    let focus: FocusedTimeField
    let value: Int
    let range: ClosedRange<Int>
    let focusedField: FocusState<FocusedTimeField?>.Binding
    let onCommit: (Int) -> Int

    @State private var draft = ""

    var body: some View {
        TextField("", text: $draft)
            .font(.system(size: 40, weight: .light, design: .monospaced))
            .foregroundColor(Color(.labelColor))
            .multilineTextAlignment(.center)
            .textFieldStyle(.plain)
            .frame(width: 56, height: 50)
            .focused(focusedField, equals: focus)
            .onAppear {
                draft = formatted(value)
            }
            .onChange(of: value) { newValue in
                if focusedField.wrappedValue != focus {
                    draft = formatted(newValue)
                }
            }
            .onChange(of: focusedField.wrappedValue) { focused in
                if focused == focus {
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
            }
    }

    private func normalize(_ newValue: String) {
        guard focusedField.wrappedValue == focus else { return }

        let sanitized = String(newValue.filter(\.isNumber).prefix(2))
        guard sanitized == newValue else {
            draft = sanitized
            return
        }

        if sanitized != draft {
            draft = sanitized
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
                .font(.system(size: 13))
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
