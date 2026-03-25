
import Foundation
import AppKit
import SwiftData

class HoAhCSVExportService {
    
    func exportTranscriptionsToCSV(transcriptions: [Transcription], suggestedName: String = "HoAh-transcription.csv") {
        let csvString = generateCSV(for: transcriptions)
        
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.commaSeparatedText]
        savePanel.nameFieldStringValue = suggestedName
        
        savePanel.begin { result in
            if result == .OK, let url = savePanel.url {
                do {
                    try csvString.write(to: url, atomically: true, encoding: .utf8)
                } catch {
                    print("Error writing CSV file: \(error)")
                }
            }
        }
    }
    
    private func generateCSV(for transcriptions: [Transcription]) -> String {
        var csvString = "Date,Source,Original,AI Action Result,Dictation Model,AI Action Model,Action Name,Transcription Time,AI Action Time,Duration\n"

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        
        for transcription in transcriptions {
            let date = escapeCSVString(dateFormatter.string(from: transcription.timestamp))
            let source = escapeCSVString(sourceLabel(for: transcription))
            let originalText = escapeCSVString(transcription.text)
            let enhancedText = escapeCSVString(transcription.enhancedText ?? "")
            let transcriptionModel = escapeCSVString(transcription.transcriptionModelName ?? "")
            let enhancementModel = escapeCSVString(transcription.aiEnhancementModelName ?? "")
            let promptName = escapeCSVString(transcription.promptName ?? "")
            let transcriptionTime = transcription.transcriptionDuration ?? 0
            let enhancementTime = transcription.enhancementDuration ?? 0
            let duration = transcription.duration

            let row = "\(date),\(source),\(originalText),\(enhancedText),\(transcriptionModel),\(enhancementModel),\(promptName),\(transcriptionTime),\(enhancementTime),\(duration)\n"
            csvString.append(row)
        }

        return csvString
    }

    private func sourceLabel(for transcription: Transcription) -> String {
        switch transcription.sourceKind {
        case .dictation:
            return "Dictation"
        case .clipboardAction:
            return "Clipboard AI Action"
        }
    }

    private func escapeCSVString(_ string: String) -> String {
        let escapedString = string.replacingOccurrences(of: "\"", with: "\"\"")
        if escapedString.contains(",") || escapedString.contains("\n") {
            return "\"\(escapedString)\""
        }
        return escapedString
    }
}
