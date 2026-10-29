import SwiftUI
import TimeConverterUI

/// The endless dial under the clocks: a strip of 15-minute ticks that slides
/// with the finger under a fixed centre pointer. No ends — a swipe moves the
/// time by up to twelve hours and the next swipe carries on from there
/// (`ClockOffset`). A tap, not a drag, resets to now.
///
/// Drawn in a `Canvas`, so the strip is one draw call however far out the
/// offset is: only the ticks inside the frame are computed. The ticks are
/// texture, not a scale — the readout above says where the dial is.
struct ClockOffsetDial: View {
    @Binding var offset: ClockOffset

    static let height: CGFloat = 56
    /// A drag has to travel this far before it is a drag; a shorter touch is
    /// the reset tap.
    static let dragMinimumDistance: CGFloat = 6

    var body: some View {
        GeometryReader { geometry in
            let trackWidth = geometry.size.width
            Canvas { context, size in
                drawTicks(in: &context, size: size)
                drawPointer(in: &context, size: size)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: Self.dragMinimumDistance)
                    .onChanged { value in
                        offset.drag(translationWidth: value.translation.width, trackWidth: trackWidth)
                    }
                    .onEnded { _ in offset.settleDrag() }
            )
            .onTapGesture { offset.reset() }
        }
        .frame(height: Self.height)
        .accessibilityElement()
        .accessibilityLabel("Shift time")
        .accessibilityHint("Swipe to move by up to twelve hours, again to keep going. Tap to return to now.")
        .accessibilityAdjustableAction { direction in
            offset.step(by: direction == .increment ? 1 : -1)
        }
    }

    /// Ticks every 15 minutes; taller on the hour, tallest every six hours.
    private func drawTicks(in context: inout GraphicsContext, size: CGSize) {
        let pointsPerMinute = size.width / ClockOffset.minutesPerTrackWidth
        let centreMinutes = offset.continuousMinutes
        let halfWindowMinutes = ClockOffset.minutesPerTrackWidth / 2
        let firstTick = ((centreMinutes - halfWindowMinutes) / ClockOffset.stepMinutes).rounded(.down)
        let lastTick = ((centreMinutes + halfWindowMinutes) / ClockOffset.stepMinutes).rounded(.up)
        var tick = firstTick
        while tick <= lastTick {
            let tickMinutes = tick * ClockOffset.stepMinutes
            let x = size.width / 2 + (tickMinutes - centreMinutes) * pointsPerMinute
            let isHour = tickMinutes.truncatingRemainder(dividingBy: 60) == 0
            let isSixHours = tickMinutes.truncatingRemainder(dividingBy: 360) == 0
            let tickHeight: CGFloat = isSixHours ? 28 : (isHour ? 18 : 9)
            var path = Path()
            path.move(to: CGPoint(x: x, y: size.height / 2 - tickHeight / 2))
            path.addLine(to: CGPoint(x: x, y: size.height / 2 + tickHeight / 2))
            context.stroke(
                path,
                with: .color(isHour ? PosterPalette.ink : PosterPalette.quietInk),
                lineWidth: isSixHours ? 2 : 1
            )
            tick += 1
        }
    }

    private func drawPointer(in context: inout GraphicsContext, size: CGSize) {
        var pointer = Path()
        pointer.move(to: CGPoint(x: size.width / 2, y: 0))
        pointer.addLine(to: CGPoint(x: size.width / 2, y: size.height))
        context.stroke(pointer, with: .color(PosterPalette.accent), lineWidth: 3)
    }
}
