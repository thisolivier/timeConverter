import SwiftUI
import TimeConverterCore
import TimeConverterUI

/// The sheet behind the Saved tab's `+` (item 37): type a place the way you
/// would on the Convert tab — `Tokyo`, `ET`, `Portland Oregon` — and save it.
///
/// It is the Convert tab's own resolution, not a lookalike: the same
/// `ConverterDisplayDriver`, so a bare place converts (item 22), an
/// ambiguous one prompts with the same chips (`Portland, Oregon` /
/// `Portland, Maine`) and a misspelt one gets the same did-you-mean. What
/// would be starred on the result band is what `Add` saves.
struct AddSavedPlaceSheet: View {
    @Environment(FavouritesStore.self) private var favouritesStore
    @Environment(\.dismiss) private var dismiss
    @State private var typedPlace: String
    @State private var displayDriver = ConverterDisplayDriver()
    @FocusState private var fieldIsFocused: Bool

    /// `initialText` is the DEBUG `-addPlace` prefill; empty in use.
    init(initialText: String = "") {
        _typedPlace = State(initialValue: initialText)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                Text("Place")
                    .posterLabel(size: 12)
                    .foregroundStyle(PosterPalette.ink)

                PosterBox {
                    TextField(
                        "",
                        text: $typedPlace,
                        prompt: Text("Tokyo, ET, Portland Oregon")
                            .foregroundColor(PosterPalette.quietInk)
                    )
                    .font(PosterTypography.mono(size: 21))
                    .foregroundStyle(PosterPalette.ink)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .focused($fieldIsFocused)
                    .submitLabel(.done)
                    .onSubmit { showWithoutWaiting() }
                    .accessibilityLabel("Place")
                }
                .padding(.top, 10)

                resolution
                    .padding(.top, 22)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 28)
            .padding(.top, 24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(PosterPalette.paper.ignoresSafeArea())
            .tint(PosterPalette.accent)
            .navigationTitle("Add a place")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .onAppear {
            fieldIsFocused = true
            if !typedPlace.isEmpty { showWithoutWaiting() }
        }
        .onChange(of: typedPlace) {
            displayDriver.inputDidChange(to: typedPlace, now: Date(), localZone: TimeZone.current)
        }
    }

    // MARK: - What the typed place resolves to

    @ViewBuilder
    private var resolution: some View {
        switch displayDriver.displayState {
        case .hint:
            Text("A city, a country or a zone code.")
                .font(PosterTypography.mono(size: 14, weight: .regular))
                .foregroundStyle(PosterPalette.quietInk)

        case let .converted(display):
            if let destination = display.favouritableTarget {
                resolvedPlace(display, destination: destination)
            } else {
                Text("That is your local time, which is always the first clock.")
                    .font(PosterTypography.mono(size: 14, weight: .regular))
                    .foregroundStyle(PosterPalette.quietInk)
                    .fixedSize(horizontal: false, vertical: true)
            }

        case let .problem(problem):
            VStack(alignment: .leading, spacing: 12) {
                Text(problem.message)
                    .font(PosterTypography.mono(size: 14, weight: .regular))
                    .foregroundStyle(PosterPalette.accentText)
                    .fixedSize(horizontal: false, vertical: true)
                if !problem.chips.isEmpty {
                    PromptChipRow(chips: problem.chips, onTap: apply)
                }
            }
        }
    }

    private func resolvedPlace(_ display: ConverterDisplay, destination: FavouriteDestination) -> some View {
        let alreadySaved = favouritesStore.isFavourite(destination)
        return VStack(alignment: .leading, spacing: 6) {
            Text(display.targetPlaceName)
                .posterLabel(size: 14)
                .foregroundStyle(PosterPalette.ink)
            if !display.targetZoneLine.isEmpty {
                Text(display.targetZoneLine)
                    .posterLabel(size: 11, em: 0.10)
                    .foregroundStyle(PosterPalette.quietInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Button {
                if !alreadySaved { favouritesStore.toggle(destination) }
                dismiss()
            } label: {
                Text(alreadySaved ? "Already saved" : "Add \(display.targetPlaceName)")
                    .font(PosterTypography.mono(size: 15))
                    .foregroundStyle(PosterPalette.paper)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(PosterPalette.accent)
            }
            .buttonStyle(.plain)
            .disabled(alreadySaved)
            .padding(.top, 10)
        }
    }

    // MARK: - Behaviour, as on the Convert tab

    private func showWithoutWaiting() {
        displayDriver.showWithoutWaiting(for: typedPlace, now: Date(), localZone: TimeZone.current)
    }

    private func apply(_ chip: ReplacementChip) {
        typedPlace = displayDriver.apply(chip, to: typedPlace, now: Date(), localZone: TimeZone.current)
    }
}
