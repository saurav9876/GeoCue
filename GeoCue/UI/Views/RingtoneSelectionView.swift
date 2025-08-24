import SwiftUI

struct RingtoneSelectionView: View {
    
    // MARK: - Properties
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: RingtoneSelectionViewModel
    @State private var showingErrorAlert = false
    @State private var previewingRingtone: RingtoneType?
    
    // MARK: - Initialization
    
    init(ringtoneService: RingtoneServiceProtocol = RingtoneService()) {
        self._viewModel = StateObject(wrappedValue: RingtoneSelectionViewModel(ringtoneService: ringtoneService))
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            contentView
                .navigationTitle("ringtone_settings_title")
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("done_button") {
                            dismiss()
                        }
                        .accessibilityIdentifier("doneButton")
                    }
                }
        }
        .disabled(viewModel.isLoading)
        .overlay(loadingOverlay)
        .alert("error_alert_title", isPresented: $showingErrorAlert) {
            Button("ok_button", role: .cancel) {
                viewModel.clearError()
            }
            Button("retry_button") {
                viewModel.retryLastOperation()
            }
        } message: {
            Text(viewModel.errorMessage)
        }
        .onReceive(viewModel.$lastError) { error in
            showingErrorAlert = error != nil
        }
        .onAppear {
            viewModel.onAppear()
        }
        .onDisappear {
            viewModel.onDisappear()
        }
    }
    
    // MARK: - Content Views
    
    @ViewBuilder
    private var contentView: some View {
        List {
            enabledToggleSection
            
            if viewModel.isRingtoneEnabled {
                ringtoneSelectionSections
            }
        }
        .listStyle(InsetGroupedListStyle())
    }
    
    private var enabledToggleSection: some View {
        Section {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("enable_notification_sounds")
                        .font(.body)
                        .foregroundColor(.primary)
                    
                    Text("enable_sounds_description")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Toggle("", isOn: $viewModel.isRingtoneEnabled)
                    .accessibilityLabel("enable_notification_sounds")
                    .accessibilityHint("toggle_sounds_hint")
                    .accessibilityIdentifier("enableSoundsToggle")
                    .onChange(of: viewModel.isRingtoneEnabled) { _, newValue in
                        viewModel.toggleRingtoneEnabled()
                    }
            }
            .padding(.vertical, 8)
        } header: {
            Text("sound_settings_header")
        } footer: {
            Text("sound_settings_footer")
        }
    }
    
    @ViewBuilder
    private var ringtoneSelectionSections: some View {
        ForEach(viewModel.ringtoneCategories, id: \.key) { category, ringtones in
            Section {
                ForEach(ringtones) { ringtone in
                    RingtoneRowView(
                        ringtone: ringtone,
                        isSelected: viewModel.selectedRingtone == ringtone,
                        isPlaying: previewingRingtone == ringtone,
                        onSelect: {
                            viewModel.selectRingtone(ringtone)
                        },
                        onPreview: {
                            handleRingtonePreview(ringtone)
                        }
                    )
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("ringtone_\(ringtone.rawValue)")
                }
            } header: {
                Text(LocalizedStringKey(category.rawValue.lowercased() + "_category"))
            }
        }
        
        Section {
            Text("ringtone_selection_footer")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    @ViewBuilder
    private var loadingOverlay: some View {
        if viewModel.isLoading {
            ZStack {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    
                    Text("loading_message")
                        .font(.body)
                        .foregroundColor(.white)
                }
                .padding(32)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.black.opacity(0.8))
                )
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("loading_message")
        }
    }
    
    // MARK: - Private Methods
    
    private func handleRingtonePreview(_ ringtone: RingtoneType) {
        if previewingRingtone == ringtone {
            // Stop current preview
            viewModel.stopPreview()
            previewingRingtone = nil
        } else {
            // Start new preview
            viewModel.previewRingtone(ringtone) { [ringtone] success in
                if success {
                    previewingRingtone = ringtone
                    
                    // Auto-stop preview after 2 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        if previewingRingtone == ringtone {
                            previewingRingtone = nil
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Ringtone Row View

struct RingtoneRowView: View {
    
    // MARK: - Properties
    
    let ringtone: RingtoneType
    let isSelected: Bool
    let isPlaying: Bool
    let onSelect: () -> Void
    let onPreview: () -> Void
    
    // MARK: - Body
    
    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(ringtone.displayName)
                    .font(.body)
                    .foregroundColor(.primary)
                
                if ringtone == .defaultSound {
                    Text("system_default_sound")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                Button(action: onPreview) {
                    Image(systemName: isPlaying ? "stop.circle.fill" : "play.circle.fill")
                        .font(.title2)
                        .foregroundColor(.accentColor)
                        .contentTransition(.symbolEffect(.replace))
                }
                .accessibilityLabel(isPlaying ? "stop_preview" : "play_preview")
                .accessibilityHint("preview_ringtone_hint")
                .accessibilityIdentifier("previewButton_\(ringtone.rawValue)")
                .buttonStyle(PlainButtonStyle())
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.accentColor)
                        .accessibilityLabel("selected_ringtone")
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(ringtone.displayName)\(isSelected ? ", selected" : "")")
        .accessibilityHint("double_tap_to_select")
        .animation(.easeInOut(duration: 0.2), value: isSelected)
        .animation(.easeInOut(duration: 0.2), value: isPlaying)
    }
}

// MARK: - Preview

#Preview {
    RingtoneSelectionView()
}