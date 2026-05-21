//
//  PracticeView.swift
//  replay
//
//  Created by Vinayak Vikram on 5/20/26.
//

import SwiftUI

struct PracticeView: View {
    @StateObject private var audio = AudioEngine()

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                statusLabel

                levelMeter

                Spacer()

                mainButton

                if audio.lastRecordingURL != nil && audio.state == .idle {
                    playButton
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Replay")
            .task { await audio.requestPermission() }
            .alert("Error", isPresented: Binding(
                get: { audio.errorMessage != nil },
                set: { if !$0 { audio.errorMessage = nil } }
            )) {
                Button("OK") { audio.errorMessage = nil }
            } message: {
                Text(audio.errorMessage ?? "")
            }
        }
    }

    @ViewBuilder
    private var statusLabel: some View {
        Group {
            switch audio.state {
            case .idle:
                Text(audio.lastRecordingURL != nil ? "Ready" : "Tap to start recording")
                    .foregroundStyle(.secondary)
            case .recording:
                Text(audio.detectorArmed ? "Listening for pause…" : "Waiting for you to start playing…")
                    .foregroundStyle(.red)
            case .playing:
                Text("Playing back…")
                    .foregroundStyle(.blue)
            }
        }
        .font(.headline)
        .animation(.default, value: audio.state)
    }

    private var levelMeter: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(.quaternary)

                RoundedRectangle(cornerRadius: 6)
                    .fill(audio.state == .recording ? Color.red.opacity(0.8) : Color.blue.opacity(0.5))
                    .frame(height: geo.size.height * CGFloat(audio.inputLevel))
                    .animation(.linear(duration: 0.05), value: audio.inputLevel)
            }
        }
        .frame(width: 48, height: 200)
    }

    private var mainButton: some View {
        Button {
            switch audio.state {
            case .idle:
                audio.startRecording()
            case .recording:
                audio.stopRecording()
            case .playing:
                audio.stopPlayback()
            }
        } label: {
            ZStack {
                Circle()
                    .fill(buttonColor)
                    .frame(width: 80, height: 80)

                Image(systemName: buttonIcon)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
        .buttonStyle(.plain)
        .disabled(!audio.permissionGranted && audio.state == .idle)
        .animation(.spring(duration: 0.2), value: audio.state)
    }

    private var playButton: some View {
        Button {
            audio.startPlayback()
        } label: {
            Label("Play back", systemImage: "play.fill")
                .font(.body.weight(.medium))
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .background(.blue.opacity(0.15), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private var buttonColor: Color {
        switch audio.state {
        case .idle: return .red
        case .recording: return .gray
        case .playing: return .gray
        }
    }

    private var buttonIcon: String {
        switch audio.state {
        case .idle: return "mic.fill"
        case .recording: return "stop.fill"
        case .playing: return "stop.fill"
        }
    }
}

#Preview {
    PracticeView()
}
