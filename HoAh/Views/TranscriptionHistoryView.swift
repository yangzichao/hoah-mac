import SwiftUI
import SwiftData

struct TranscriptionHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var selectedRange: HistoryTimeRange
    @Environment(\.theme) private var theme
    @State private var selectedDurationRange: AudioDurationRange = .all
    @State private var searchText = ""
    @State private var expandedTranscription: Transcription?
    @State private var selectedTranscriptions: Set<Transcription> = []
    @State private var showDeleteConfirmation = false
    @State private var isViewCurrentlyVisible = false
    
    private let exportService = HoAhCSVExportService()
    private let markdownExportService = HoAhMarkdownExportService()
    
    enum ExportFormat {
        case csv
        case markdown
    }
    
    // Pagination states
    @State private var displayedTranscriptions: [Transcription] = []
    @State private var isLoading = false
    @State private var hasMoreContent = true
    
    // Cursor-based pagination - track the last timestamp
    @State private var lastTimestamp: Date?
    private let pageSize = 20
    
    @Query(Self.createLatestTranscriptionIndicatorDescriptor()) private var latestTranscriptionIndicator: [Transcription]

    init(selectedRange: Binding<HistoryTimeRange>) {
        self._selectedRange = selectedRange
    }
    
    // Static function to create the FetchDescriptor for the latest transcription indicator
    private static func createLatestTranscriptionIndicatorDescriptor() -> FetchDescriptor<Transcription> {
        var descriptor = FetchDescriptor<Transcription>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return descriptor
    }

    
    // Cursor-based query descriptor
    private func cursorQueryDescriptor(after timestamp: Date? = nil) -> FetchDescriptor<Transcription> {
        var descriptor = FetchDescriptor<Transcription>(
            sortBy: [SortDescriptor(\Transcription.timestamp, order: .reverse)]
        )
        
        // Build the predicate based on search text, time range, and cursor
        descriptor.predicate = makePredicate(timestamp: timestamp)
        
        descriptor.fetchLimit = pageSize
        return descriptor
    }
    
    private func makePredicate(timestamp: Date?) -> Predicate<Transcription>? {
        let hasSearch = !searchText.isEmpty
        let cutoff = selectedRange.cutoffDate
        let minDur = selectedDurationRange.minDuration
        let maxDur = selectedDurationRange.maxDuration

        if !hasSearch, timestamp == nil, cutoff == nil, minDur == nil, maxDur == nil {
            return nil
        }

        let useTimestamp = timestamp != nil
        let timestampValue = timestamp ?? .distantFuture
        let useCutoff = cutoff != nil
        let cutoffValue = cutoff ?? .distantPast
        let useMinDuration = minDur != nil
        let minDurationValue = minDur ?? 0
        let useMaxDuration = maxDur != nil
        let maxDurationValue = maxDur ?? .greatestFiniteMagnitude

        return #Predicate<Transcription> { t in
            (!hasSearch ||
             t.text.localizedStandardContains(searchText) ||
             (t.enhancedText?.localizedStandardContains(searchText) ?? false)) &&
            (!useTimestamp || t.timestamp < timestampValue) &&
            (!useCutoff || t.timestamp >= cutoffValue) &&
            (!useMinDuration || t.duration >= minDurationValue) &&
            (!useMaxDuration || t.duration < maxDurationValue)
        }
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                searchBar
                
                // Auto Export Settings (collapsible)
                AutoExportSettingsView()
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                
                if displayedTranscriptions.isEmpty && !isLoading {
                    emptyStateView
                } else {
                    historyList
                }
            }
            .background(theme.controlBackground)
            
            // Selection toolbar as an overlay
            if !selectedTranscriptions.isEmpty {
                selectionToolbar
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.easeInOut(duration: 0.3), value: !selectedTranscriptions.isEmpty)
            }
        }
        .alert("Delete Selected Items?", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                deleteSelectedTranscriptions()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            let pluralSuffix = selectedTranscriptions.count == 1 ? "" : "s"
            Text(String(format: NSLocalizedString("This action cannot be undone. Are you sure you want to delete %lld item%@?", comment: ""), selectedTranscriptions.count, pluralSuffix))
        }
        .onAppear {
            isViewCurrentlyVisible = true
            Task {
                await loadInitialContent()
            }
        }
        .onDisappear {
            isViewCurrentlyVisible = false
        }
        .onChange(of: searchText) { _, _ in
            Task {
                await resetPagination()
                await loadInitialContent()
            }
        }
        .onChange(of: selectedRange) { _, _ in
            Task {
                await resetPagination()
                await loadInitialContent()
            }
        }
        .onChange(of: selectedDurationRange) { _, _ in
            Task {
                await resetPagination()
                await loadInitialContent()
            }
        }
        // Improved change detection for new transcriptions
        .onChange(of: latestTranscriptionIndicator.first?.id) { oldId, newId in
            guard isViewCurrentlyVisible else { return } // Only proceed if the view is visible

            // Check if a new transcription was added or the latest one changed
            if newId != oldId {
                // Only refresh if we're on the first page (no pagination cursor set)
                // or if the view is active and new content is relevant.
                if lastTimestamp == nil {
                    Task {
                        await resetPagination()
                        await loadInitialContent()
                    }
                } else {
                    // Reset pagination to show the latest content
                    Task {
                        await resetPagination()
                        await loadInitialContent()
                    }
                }
            }
        }
    }

    private var historyList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(displayedTranscriptions, id: \.id) { transcription in
                        transcriptionRow(transcription)
                    }

                    if hasMoreContent {
                        loadMoreButton
                    }
                }
                .padding(24)
                .padding(.bottom, !selectedTranscriptions.isEmpty ? 60 : 0)
            }
            .padding(.vertical, 16)
            .onChange(of: expandedTranscription) { old, new in
                if let transcription = new {
                    proxy.scrollTo(transcription.id, anchor: nil)
                }
            }
        }
    }

    private func transcriptionRow(_ transcription: Transcription) -> some View {
        TranscriptionCard(
            transcription: transcription,
            isExpanded: expandedTranscription == transcription,
            isSelected: selectedTranscriptions.contains(transcription),
            onDelete: { deleteTranscription(transcription) },
            onToggleSelection: { toggleSelection(transcription) }
        )
        .id(transcription.id)
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.25)) {
                if expandedTranscription == transcription {
                    expandedTranscription = nil
                } else {
                    expandedTranscription = transcription
                }
            }
        }
    }

    private var loadMoreButton: some View {
        Button(action: {
            Task {
                await loadMoreContent()
            }
        }) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                }
                Text(isLoading
                     ? String(localized: "Loading...")
                     : String(localized: "Load More"))
                    .font(theme.typography.subheadline)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(CardBackground(isSelected: false))
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
        .padding(.top, 12)
    }
    
    private var searchBar: some View {
        HStack(spacing: 12) {
            // Search Input
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(theme.textSecondary)
                    .font(.system(size: 14))
                
                TextField("Search transcriptions", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(theme.typography.subheadline)
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(theme.textSecondary)
                            .font(.system(size: 14))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background {
                RoundedRectangle(cornerRadius: 8)
                    .fill(theme.controlBackground)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(theme.panelBorder, lineWidth: 1)
            )
            
            Spacer()

            // Time Range Filter
            Menu {
                ForEach(HistoryTimeRange.allCases) { range in
                    Button {
                        selectedRange = range
                    } label: {
                        HStack {
                            Text(range.titleKey)
                            Spacer()
                            if selectedRange == range {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .foregroundColor(theme.textSecondary)
                        .font(.system(size: 12))
                    Text(selectedRange.titleKey)
                        .font(theme.typography.caption)
                        .foregroundColor(theme.textPrimary)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(theme.textSecondary.opacity(0.7))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(theme.controlBackground)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(theme.panelBorder, lineWidth: 1)
                )
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            // Duration Filter
            Menu {
                ForEach(AudioDurationRange.allCases) { range in
                    Button {
                        selectedDurationRange = range
                    } label: {
                        HStack {
                            Text(range.titleKey)
                            Spacer()
                            if selectedDurationRange == range {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "waveform")
                        .foregroundColor(theme.textSecondary)
                        .font(.system(size: 12))
                    Text(selectedDurationRange.titleKey)
                        .font(theme.typography.caption)
                        .foregroundColor(theme.textPrimary)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(theme.textSecondary.opacity(0.7))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(theme.controlBackground)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(theme.panelBorder, lineWidth: 1)
                )
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            
            // Export Button
            Menu {
                Button(action: {
                    Task {
                        await exportAllHistory(format: .csv)
                    }
                }) {
                    Label("Export CSV (Single File)", systemImage: "tablecells")
                }
                
                Button(action: {
                    Task {
                        await exportAllHistory(format: .markdown)
                    }
                }) {
                    Label("Export Daily Markdown (Folder)", systemImage: "doc.text")
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(theme.textSecondary)
                        .font(.system(size: 12))
                    Text("Export")
                        .font(theme.typography.caption)
                        .foregroundColor(theme.textPrimary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(theme.controlBackground)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(theme.panelBorder, lineWidth: 1)
                )
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(CardBackground(isSelected: false))
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 50))
                .foregroundColor(theme.textSecondary)
            Text("No transcriptions found")
                .font(theme.typography.title2)
                .fontWeight(.semibold)
            Text("Your history will appear here")
                .font(theme.typography.subheadline)
                .foregroundColor(theme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(CardBackground(isSelected: false))
        .padding(24)
    }
    
    private var selectionToolbar: some View {
        HStack(spacing: 12) {
            Text("\(selectedTranscriptions.count) selected")
                .foregroundColor(theme.textSecondary)
                .font(theme.typography.subheadline)
            
            Spacer()
            
            Button(action: {
                exportService.exportTranscriptionsToCSV(
                    transcriptions: Array(selectedTranscriptions),
                    suggestedName: exportFileName(scope: "selection")
                )
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "square.and.arrow.up")
                    Text("Export")
                }
            }
            .buttonStyle(.borderless)
            
            Button(action: {
                showDeleteConfirmation = true
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "trash")
                    Text("Delete")
                }
            }
            .buttonStyle(.borderless)
            
            if selectedTranscriptions.count < displayedTranscriptions.count {
                Button("Select All") {
                    Task {
                        await selectAllTranscriptions()
                    }
                }
                .buttonStyle(.borderless)
            } else {
                Button("Deselect All") {
                    selectedTranscriptions.removeAll()
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(
            theme.windowBackground
                .shadow(color: theme.shadowColor.opacity(0.1), radius: 3, y: -2)
        )
    }
    
    @MainActor
    private func loadInitialContent() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Reset cursor
            lastTimestamp = nil
            
            // Fetch initial page without a cursor
            let items = try modelContext.fetch(cursorQueryDescriptor())
            
            displayedTranscriptions = items
            // Update cursor to the timestamp of the last item
            lastTimestamp = items.last?.timestamp
            // If we got fewer items than the page size, there are no more items
            hasMoreContent = items.count == pageSize
        } catch {
            print("Error loading transcriptions: \(error)")
        }
    }
    
    @MainActor
    private func loadMoreContent() async {
        guard !isLoading, hasMoreContent, let lastTimestamp = lastTimestamp else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Fetch next page using the cursor
            let newItems = try modelContext.fetch(cursorQueryDescriptor(after: lastTimestamp))
            
            // Append new items to the displayed list
            displayedTranscriptions.append(contentsOf: newItems)
            // Update cursor to the timestamp of the last new item
            self.lastTimestamp = newItems.last?.timestamp
            // If we got fewer items than the page size, there are no more items
            hasMoreContent = newItems.count == pageSize
        } catch {
            print("Error loading more transcriptions: \(error)")
        }
    }
    
    @MainActor
    private func resetPagination() {
        displayedTranscriptions = []
        lastTimestamp = nil
        hasMoreContent = true
        isLoading = false
    }
    
    private func deleteTranscription(_ transcription: Transcription) {
        // First delete the audio file if it exists
        if let urlString = transcription.audioFileURL,
           let url = URL(string: urlString) {
            try? FileManager.default.removeItem(at: url)
        }
        
        modelContext.delete(transcription)
        if expandedTranscription == transcription {
            expandedTranscription = nil
        }
        
        // Remove from selection if selected
        selectedTranscriptions.remove(transcription)
        
        // Refresh the view
        Task {
            try? await modelContext.save()
            await loadInitialContent()
        }
    }
    
    private func deleteSelectedTranscriptions() {
        // Delete audio files and transcriptions
        for transcription in selectedTranscriptions {
            if let urlString = transcription.audioFileURL,
               let url = URL(string: urlString) {
                try? FileManager.default.removeItem(at: url)
            }
            modelContext.delete(transcription)
            if expandedTranscription == transcription {
                expandedTranscription = nil
            }
        }
        
        // Clear selection
        selectedTranscriptions.removeAll()
        
        // Save changes and refresh
        Task {
            try? await modelContext.save()
            await loadInitialContent()
        }
    }
    
    private func toggleSelection(_ transcription: Transcription) {
        if selectedTranscriptions.contains(transcription) {
            selectedTranscriptions.remove(transcription)
        } else {
            selectedTranscriptions.insert(transcription)
        }
    }
    
    // Modified function to select all transcriptions in the database
    private func selectAllTranscriptions() async {
        do {
            // Create a descriptor without pagination limits to get all IDs
            var allDescriptor = FetchDescriptor<Transcription>()
            allDescriptor.predicate = makePredicate(timestamp: nil)
            
            // For better performance, only fetch the IDs
            allDescriptor.propertiesToFetch = [\.id]
            
            // Fetch all matching transcriptions
            let allTranscriptions = try modelContext.fetch(allDescriptor)
            
            // Create a set of all visible transcriptions for quick lookup
            let visibleIds = Set(displayedTranscriptions.map { $0.id })
            
            // Add all transcriptions to the selection
            await MainActor.run {
                // First add all visible transcriptions directly
                selectedTranscriptions = Set(displayedTranscriptions)
                
                // Then add any non-visible transcriptions by ID
                for transcription in allTranscriptions {
                    if !visibleIds.contains(transcription.id) {
                        selectedTranscriptions.insert(transcription)
                    }
                }
            }
        } catch {
            print("Error selecting all transcriptions: \(error)")
        }
    }
    
    private func exportAllHistory(format: ExportFormat) async {
        do {
            // Create a descriptor to fetch all transcriptions
            var allDescriptor = FetchDescriptor<Transcription>(
                sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
            )
            
            allDescriptor.predicate = makePredicate(timestamp: nil)
            
            // Fetch all matching transcriptions
            let allTranscriptions = try modelContext.fetch(allDescriptor)
            
            // Export on main actor
            await MainActor.run {
                switch format {
                case .csv:
                    exportService.exportTranscriptionsToCSV(
                        transcriptions: allTranscriptions,
                        suggestedName: exportFileName(scope: "all")
                    )
                case .markdown:
                    markdownExportService.exportTranscriptionsToDailyMarkdown(transcriptions: allTranscriptions)
                }
            }
        } catch {
            print("Error exporting all transcriptions: \(error)")
        }
    }

    private func exportFileName(scope: String) -> String {
        let end = Date()
        if let start = selectedRange.cutoffDate {
            return "HoAh-history-\(formattedHour(start))_to_\(formattedHour(end))-\(scope).csv"
        } else {
            return "HoAh-history-all-time-\(formattedHour(end))-\(scope).csv"
        }
    }

    private func formattedHour(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HH"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: date)
    }
}

struct CircularCheckboxStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button(action: {
            configuration.isOn.toggle()
        }) {
            Image(systemName: configuration.isOn ? "checkmark.circle.fill" : "circle")
                .symbolRenderingMode(.hierarchical)
                .foregroundColor(configuration.isOn ? .blue : .gray)
                .font(.system(size: 18))
        }
        .buttonStyle(.plain)
    }
}
