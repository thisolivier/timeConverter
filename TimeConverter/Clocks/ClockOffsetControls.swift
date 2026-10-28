import SwiftUI
import TimeConverterUI

/// The bottom of the Clocks tab: the readout, the day stepper and the slider.
/// All stock controls; the rust tint comes from the tab view.
///
/// A **tap** on the slider resets both to zero ("back to now"). Two detectors,
/// because a stock `Slider` does not say whether it was tapped: a
/// simultaneous `TapGesture` (fails as soon as the finger moves, so a drag
/// never resets), and, as a fallback, a press on the thumb that lifts quickly
/// without changing the value (`ClockOffset.editingWasATap`).
struct ClockOffsetControls: View {
    let readout: String
    let offsetDescription: String?
    @Binding var offset: ClockOffset

    @State private var editingStartValue: Double = 0
    @State private var editingStartTime: Date = .distantPast

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(readout)
                        .font(PosterTypography.mono(size: 16))
                        .foregroundStyle(PosterPalette.ink)
                    Text(offsetDescription ?? "Now")
                        .font(PosterTypography.mono(size: 12, weight: .regular))
                        .foregroundStyle(PosterPalette.quietInk)
                }
                Spacer()
                Stepper("Days", onIncrement: { offset.days += 1 }, onDecrement: { offset.days -= 1 })
                    .labelsHidden()
                    .accessibilityLabel("Shift by days")
            }

            Slider(
                value: $offset.sliderMinutes,
                in: ClockOffset.sliderRangeMinutes,
                step: ClockOffset.sliderStepMinutes,
                onEditingChanged: sliderEditingChanged
            )
            .simultaneousGesture(TapGesture().onEnded { offset.reset() })
            .accessibilityLabel("Shift time")
            .accessibilityHint("Tap to return to now")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(PosterPalette.paper)
    }

    private func sliderEditingChanged(_ isEditing: Bool) {
        if isEditing {
            editingStartValue = offset.sliderMinutes
            editingStartTime = Date()
        } else if ClockOffset.editingWasATap(
            startValue: editingStartValue,
            endValue: offset.sliderMinutes,
            duration: Date().timeIntervalSince(editingStartTime)
        ) {
            offset.reset()
        }
    }
}
