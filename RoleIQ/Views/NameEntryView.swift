//
//  NameEntryView.swift
//  RoleEase
//
//  Created by Lakshman Ryali on 20/09/26.
//


//
//  Shown after sign-in when no name is stored (first run, or after Delete
//  Account). Also reachable for editing. Writes name + avatar color to
//  AuthViewModel, which everything else reads.
//

import SwiftUI

struct NameEntryView: View {
    @Environment(AuthViewModel.self) private var authViewModel
    var onContinue: () -> Void

    @State private var name = ""
    @State private var selectedHex = AvatarGenerator.palette[0]
    @State private var appear = false
    @FocusState private var fieldFocused: Bool

    private var trimmed: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var previewInitials: String {
        trimmed.isEmpty ? "?" : AvatarGenerator.initials(for: trimmed)
    }

    var body: some View {
        ZStack {
            AppTheme.screenGradient.ignoresSafeArea()

            // Close / Skip Button
            VStack {
                HStack {
                    Spacer()
                    Button {
                        Haptics.tap()
                        onContinue()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(AppTheme.textPrimary)
                            .frame(width: 34, height: 34)
                            .glassBackground(in: Circle())
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .zIndex(1)

            // Main Content
            VStack(spacing: 24) {
                Spacer()

                AvatarRingView(initials: previewInitials, colorHex: selectedHex, size: 96)
                    .animation(.easeInOut(duration: 0.2), value: selectedHex)

                VStack(spacing: 8) {
                    Text("What should we call you?")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                        .multilineTextAlignment(.center)

                    Text("This is how your name appears across the app.")
                        .font(.system(size: 14))
                        .foregroundStyle(AppTheme.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 32)

                TextField("Your name", text: $name)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(AppTheme.textPrimary)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.done)
                    .focused($fieldFocused)
                    .onSubmit { Haptics.tap(); save() }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 16)
                    .glassBackground(in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .padding(.horizontal, 28)

                colorPalette

                Spacer()

                Button {
                    Haptics.medium()
                    save()
                } label: {
                    Text("Continue")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(AppTheme.accentGradient)
                        )
                        .opacity(trimmed.isEmpty ? 0.5 : 1)
                }
                .disabled(trimmed.isEmpty)
                .padding(.horizontal, 28)
                .padding(.bottom, 20)
            }
            .opacity(appear ? 1 : 0)
            .offset(y: appear ? 0 : 12)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .contentShape(Rectangle())
        .onTapGesture {
            fieldFocused = false
        }
        .onAppear {
            name = authViewModel.userName ?? ""
            selectedHex = authViewModel.avatarColorHex ?? AvatarGenerator.palette[0]
            withAnimation(.easeOut(duration: 0.5)) { appear = true }
        }
    }

    // MARK: - Color palette + re-roll (matching NameEditSheet grid)

    private var colorPalette: some View {
        VStack(spacing: 12) {
            Text("AVATAR COLOR")
                .font(.system(size: 11, weight: .bold))
                .tracking(1.5)
                .foregroundStyle(.white.opacity(0.4))

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 6), spacing: 12) {
                ForEach(AvatarGenerator.palette, id: \.self) { hex in
                    Circle()
                        .fill(AvatarGenerator.color(hex: hex))
                        .frame(width: 32, height: 32)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: selectedHex == hex ? 2.5 : 0)
                        )
                        .onTapGesture {
                            Haptics.tap()
                            selectedHex = hex
                        }
                }

                Button {
                    Haptics.tap()
                    selectedHex = AvatarGenerator.palette.randomElement() ?? selectedHex
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppTheme.accentSoft)
                        .frame(width: 32, height: 32)
                        .background(Color.white.opacity(0.08), in: Circle())
                }
            }
            .padding(.horizontal, 28)
        }
    }

    private func save() {
        guard !trimmed.isEmpty else { return }
        authViewModel.updateName(trimmed)
        authViewModel.updateAvatarColor(selectedHex)
        onContinue()
    }
}





struct NameEditSheet: View {
    @Environment(AuthViewModel.self) private var authViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var selectedHex = AvatarGenerator.palette[0]
    @FocusState private var fieldFocused: Bool

    private var trimmed: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    private var previewInitials: String {
        trimmed.isEmpty ? "?" : AvatarGenerator.initials(for: trimmed)
    }

    var body: some View {
        ZStack {
            AppTheme.screenGradient.ignoresSafeArea()

            VStack {
                HStack {
                    Spacer()
                    Button {
                        Haptics.tap()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(AppTheme.textPrimary)
                            .frame(width: 34, height: 34)
                            .glassBackground(in: Circle())
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .zIndex(1)
            
            VStack(spacing: 22) {
                Capsule()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 40, height: 5)
                    .padding(.top, 14)

                Text("Edit profile")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .padding(.top, 6)
                    .padding(.bottom, 4)

                AvatarRingView(initials: previewInitials, colorHex: selectedHex, size: 84)
                    .animation(.easeInOut(duration: 0.2), value: selectedHex)
                    .padding(.top, 4)

                TextField("Your name", text: $name)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(AppTheme.textPrimary)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.done)
                    .focused($fieldFocused)
                    .onSubmit { save() }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 15)
                    .glassBackground(in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .padding(.horizontal, 24)

                colorPalette

                Spacer()

                Button {
                    Haptics.medium()
                    save()
                } label: {
                    Text("Save")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(AppTheme.accentGradient)
                        )
                        .opacity(trimmed.isEmpty ? 0.5 : 1)
                }
                .disabled(trimmed.isEmpty)
                .padding(.horizontal, 24)
                .padding(.bottom, 28)
            }
        }
        .presentationDetents([.large])
        .presentationBackground(.black)
        .preferredColorScheme(.dark)
        .onAppear {
            name = authViewModel.userName ?? ""
            selectedHex = authViewModel.avatarColorHex ?? AvatarGenerator.derivedHex(for: name)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { fieldFocused = true }
        }
    }

    private var colorPalette: some View {
        VStack(spacing: 10) {
            Text("AVATAR COLOR")
                .font(.system(size: 11, weight: .bold))
                .tracking(1.5)
                .foregroundStyle(.white.opacity(0.4))

            // Wrapping grid so it handles any number of colors without overflow.
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 6), spacing: 12) {
                ForEach(AvatarGenerator.palette, id: \.self) { hex in
                    Circle()
                        .fill(AvatarGenerator.color(hex: hex))
                        .frame(width: 32, height: 32)
                        .overlay(Circle().stroke(Color.white, lineWidth: selectedHex == hex ? 2.5 : 0))
                        .onTapGesture { Haptics.tap(); selectedHex = hex }
                }
                Button {
                    Haptics.tap()
                    selectedHex = AvatarGenerator.palette.randomElement() ?? selectedHex
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppTheme.accentSoft)
                        .frame(width: 32, height: 32)
                        .background(Color.white.opacity(0.08), in: Circle())
                }
            }
            .padding(.horizontal, 24)
        }
    }

    private func save() {
        guard !trimmed.isEmpty else { return }
        authViewModel.updateName(trimmed)
        authViewModel.updateAvatarColor(selectedHex)
        dismiss()
    }
}

#Preview {
    NameEditSheet()
        .environment(AuthViewModel())
}

