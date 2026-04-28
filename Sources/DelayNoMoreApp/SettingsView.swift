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
        .frame(width: 440)
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

            VStack(spacing: 0) {
                durationRow(
                    title: LocalizedStringKey("settings.timer.work"),
                    subtitle: LocalizedStringKey("settings.timer.work.subtitle"),
                    symbolName: "deskclock",
                    color: .blue,
                    value: Binding(
                        get: { store.config.workMinutes },
                        set: { applyWorkMinutes($0) }
                    ),
                    range: AppConfig.workMinuteRange
                )

                Divider()
                    .padding(.leading, 46)

                durationRow(
                    title: LocalizedStringKey("settings.timer.break"),
                    subtitle: LocalizedStringKey("settings.timer.break.subtitle"),
                    symbolName: "cup.and.saucer",
                    color: .green,
                    value: Binding(
                        get: { store.config.breakMinutes },
                        set: { applyBreakMinutes($0) }
                    ),
                    range: AppConfig.breakMinuteRange
                )
            }
            .background(Color(.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color(.separatorColor), lineWidth: 0.5)
            )

        }
        .sectionStyle()
    }

    private func durationRow(
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey,
        symbolName: String,
        color: Color,
        value: Binding<Int>,
        range: ClosedRange<Int>
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbolName)
                .font(.system(size: 14))
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(color.gradient, in: RoundedRectangle(cornerRadius: 7))

            VStack(alignment: .leading, spacing: 1) {
                Text(title, bundle: .module)
                    .font(.system(size: 13))
                Text(subtitle, bundle: .module)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Spacer()

            HStack(spacing: 4) {
                TextField("", value: value, format: .number)
                    .frame(width: 48)
                    .multilineTextAlignment(.trailing)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13, design: .monospaced))

                Text("settings.timer.unit", bundle: .module)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)

                Stepper("", value: value, in: range)
                    .labelsHidden()
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
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

    private func applyWorkMinutes(_ minutes: Int) {
        store.config.workMinutes = min(max(minutes, AppConfig.workMinuteRange.lowerBound), AppConfig.workMinuteRange.upperBound)
        onChange(store.config)
    }

    private func applyBreakMinutes(_ minutes: Int) {
        store.config.breakMinutes = min(max(minutes, AppConfig.breakMinuteRange.lowerBound), AppConfig.breakMinuteRange.upperBound)
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
