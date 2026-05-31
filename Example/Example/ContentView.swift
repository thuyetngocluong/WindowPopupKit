//
//  ContentView.swift
//  Example
//
//  A tour of WindowPopupKit: toasts, loading, await-for-result popups,
//  sheets, full-screen modals and custom configurations.
//

import SwiftUI
import WindowPopupKit

struct ContentView: View {

    @State private var lastResult = "—"

    var body: some View {
        NavigationStack {
            List {
                toastSection
                loadingSection
                awaitSection
                sheetSection
                customSection
                uikitSection
            }
            .navigationTitle("WindowPopupKit")
        }
    }

    // MARK: - Toast

    private var toastSection: some View {
        Section {
            row("Success", "checkmark.circle.fill", .green) {
                WPToast.show(.success, message: "Saved successfully!")
            }
            row("Error", "xmark.circle.fill", .red) {
                WPToast.show(.error, message: "Something went wrong.")
            }
            row("Warning", "exclamationmark.triangle.fill", .orange) {
                WPToast.show(.warning, message: "Battery is running low.")
            }
            row("Info", "info.circle.fill", .blue) {
                WPToast.show(.info, message: "A new version is available.")
            }
            row("Network", "wifi.exclamationmark", .gray) {
                WPToast.show(.network, message: "No internet connection.")
            }
        } header: {
            Text("Toast")
        } footer: {
            Text("Auto-dismissing banners shown from anywhere — even a view model.")
        }
    }

    // MARK: - Loading

    private var loadingSection: some View {
        Section("Loading") {
            row("Blocking spinner (2s)", "arrow.triangle.2.circlepath", .indigo) {
                WPLoading.showLoading()
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(2))
                    WPLoading.dismissLoading()
                }
            }
        }
    }

    // MARK: - Await for a result

    private var awaitSection: some View {
        Section {
            row("Confirm delete", "trash", .red) {
                Task { @MainActor in
                    let result = await WPPopup.shared.popup { ConfirmDeleteView() }
                    lastResult = (result as? String) ?? "dismissed"
                }
            }
            LabeledContent("Last result", value: lastResult)
        } header: {
            Text("Popup that returns a value")
        } footer: {
            Text("`let choice = await WPPopup.shared.popup { … }` — dismiss with a value from inside the content.")
        }
    }

    // MARK: - Sheet & full screen

    private var sheetSection: some View {
        Section {
            row("Bottom sheet", "rectangle.portrait.bottomhalf.inset.filled", .teal) {
                Task { @MainActor in await WPPopup.shared.sheet { DemoSheetView() } }
            }
            row("Scrollable sheet (bottom)", "list.bullet.rectangle", .teal) {
                // Bottom-anchored, ~70%-tall scrollable sheet — the classic coordination:
                // the sheet drags down to dismiss only once the list is scrolled to its top.
                var config = WPPopupConfiguration.defaultSheet
                config.positionConstraints.height = .ratio(0.7)
                Task { @MainActor in
                    await WPPopup.shared.sheet(configuration: config) { ScrollableSheetView() }
                }
            }
            row("Full screen", "rectangle.inset.filled", .purple) {
                Task { @MainActor in await WPPopup.shared.fullScreen { DemoFullScreenView() } }
            }
        } header: {
            Text("Sheet & Full Screen")
        } footer: {
            Text("The scrollable sheet shows drag-to-dismiss coordinating with an inner scroll view — drag the handle to dismiss any time, or drag the list down once it's at the top.")
        }
    }

    // MARK: - Custom configuration

    private var customSection: some View {
        Section {
            row("Top card + haptic + scale", "wand.and.stars", .pink) {
                var config = WPPopupConfiguration.defaultPopup
                config.position = .top
                config.hapticFeedback = .medium
                config.entranceAnimation = .scaleAndFade
                config.displayDuration = .seconds(2)
                Task { @MainActor in
                    await WPPopup.shared.show(configuration: config) { DemoCardView() }
                }
            }
            row("Popup at a screen point", "scope", .pink) {
                // Anchor a popup at an absolute screen coordinate — its center sits at
                // the given point — via the `defaultPopup(at:)` preset.
                let point = CGPoint(x: 110, y: 190)
                Task { @MainActor in
                    await WPPopup.shared.popup(configuration: .defaultPopup(at: point)) {
                        DemoPointView(point: point)
                    }
                }
            }
        } header: {
            Text("Custom configuration")
        } footer: {
            Text("Start from a preset, then tweak position, haptics, animation, duration, and more.")
        }
    }

    // MARK: - UIKit content

    private var uikitSection: some View {
        Section {
            row("Dismiss from a UIView", "square.dashed", .orange) {
                // A plain UIView presented through the same engine; it dismisses
                // itself by calling `wpPopupDismiss` on the view.
                WPPopup.shared.showPopup(view: DemoUIKitPopupView(), configuration: .defaultPopup)
            }
        } header: {
            Text("UIKit content")
        } footer: {
            Text("A UIView (not SwiftUI) shown through WindowPopupKit, dismissing itself via view.wpPopupDismiss.")
        }
    }

    // MARK: - Row helper

    private func row(
        _ title: String,
        _ systemImage: String,
        _ tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .tint(.primary)
        }
        .listRowSeparatorTint(tint.opacity(0.3))
    }
}

// MARK: - Confirm Delete (returns a value)

private struct ConfirmDeleteView: View {

    @Environment(\.wpPopupDismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "trash.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(.red)

            Text("Delete this item?")
                .font(.headline)

            Text("This action cannot be undone.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 12) {
                Button("Cancel") { dismiss("cancel") }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)

                Button("Delete", role: .destructive) { dismiss("delete") }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(24)
        .frame(maxWidth: 320)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal, 32)
    }
}

// MARK: - Bottom Sheet

private struct DemoSheetView: View {

    @Environment(\.wpPopupDismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Capsule()
                .fill(.secondary.opacity(0.4))
                .frame(width: 40, height: 5)
                .padding(.top, 8)

            Text("Bottom Sheet")
                .font(.title2.bold())

            Text("Drag down to dismiss, or tap the button.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button("Done") { dismiss() }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
        }
        .padding(24)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
    }
}

// MARK: - Scrollable Sheet

private struct ScrollableSheetView: View {

    @Environment(\.wpPopupDismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Fixed header — dragging here always moves the sheet (it's outside the
            // scroll view, so `panStartedInsideScroll` is false).
            VStack(spacing: 10) {
                Capsule()
                    .fill(.secondary.opacity(0.4))
                    .frame(width: 40, height: 5)

                HStack {
                    Text("Scrollable Sheet")
                        .font(.title3.bold())
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding()

            Divider()

            // Inner scroll view — this is what `findScrollView(in:)` locates.
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(1...30, id: \.self) { index in
                        HStack(spacing: 12) {
                            Image(systemName: "\(index).circle.fill")
                                .foregroundStyle(.teal)
                            Text("List item \(index)")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.footnote)
                                .foregroundStyle(.tertiary)
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 16)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

// MARK: - Full Screen

private struct DemoFullScreenView: View {

    @Environment(\.wpPopupDismiss) private var dismiss

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.purple, .indigo],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack {
                // Close button stays inside the safe area.
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundStyle(.white.opacity(0.9))
                    }
                }
                .padding()

                Spacer()

                VStack(spacing: 12) {
                    Image(systemName: "rectangle.inset.filled")
                        .font(.system(size: 56))
                    Text("Full Screen")
                        .font(.largeTitle.bold())
                    Text("Presented in its own pass-through window,\nabove any navigation hierarchy.")
                        .multilineTextAlignment(.center)
                        .opacity(0.85)
                }
                .foregroundStyle(.white)

                Spacer()
            }
        }
    }
}

// MARK: - Custom Card

private struct DemoCardView: View {

    @Environment(\.wpPopupDismiss) private var dismiss

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "wand.and.stars")
                .foregroundStyle(.white)
            Text("Custom top card")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(.pink.gradient, in: RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 16)
    }
}

// MARK: - Popup at a Point

private struct DemoPointView: View {

    let point: CGPoint
    @Environment(\.wpPopupDismiss) private var dismiss

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "mappin.circle.fill")
                .font(.title2)
                .foregroundStyle(.pink)
            Text("Anchored here")
                .font(.subheadline.weight(.semibold))
            Text("Centered at (\(Int(point.x)), \(Int(point.y)))")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .onTapGesture { dismiss() }
    }
}

// MARK: - UIView Content (dismiss from UIKit)

private final class DemoUIKitPopupView: UIView {

    init() {
        super.init(frame: .zero)
        backgroundColor = .clear

        let card = UIView()
        card.backgroundColor = .secondarySystemBackground
        card.layer.cornerRadius = 16
        card.translatesAutoresizingMaskIntoConstraints = false

        let icon = UIImageView(
            image: UIImage(systemName: "square.dashed",
                           withConfiguration: UIImage.SymbolConfiguration(pointSize: 30, weight: .semibold))
        )
        icon.tintColor = .systemOrange
        icon.contentMode = .scaleAspectFit

        let title = UILabel()
        title.text = "Plain UIView"
        title.font = .preferredFont(forTextStyle: .headline)

        let subtitle = UILabel()
        subtitle.text = "Dismissed from UIKit via\nview.wpPopupDismiss"
        subtitle.font = .preferredFont(forTextStyle: .subheadline)
        subtitle.textColor = .secondaryLabel
        subtitle.numberOfLines = 0
        subtitle.textAlignment = .center

        let button = UIButton(configuration: .borderedProminent())
        button.setTitle("Dismiss", for: .normal)
        button.addTarget(self, action: #selector(dismissTapped), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [icon, title, subtitle, button])
        stack.axis = .vertical
        stack.spacing = 12
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(card)
        card.addSubview(stack)
        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: topAnchor),
            card.bottomAnchor.constraint(equalTo: bottomAnchor),
            card.centerXAnchor.constraint(equalTo: centerXAnchor),
            card.widthAnchor.constraint(equalToConstant: 260),
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 24),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -24)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func dismissTapped() {
        // Dismiss the popup straight from the UIView.
        wpPopupDismiss?()
    }
}

#Preview {
    ContentView()
}
