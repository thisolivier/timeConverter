import SwiftUI
import TimeConverterUI

/// The bottom of the Clocks tab: the readout over the endless dial
/// (`ClockOffsetDial`). The stepper and the bounded slider of build 20 are
/// gone — the dial has no ends, so there is nothing for a stepper to do.
struct ClockOffsetControls: View {
    let readout: String
    let offsetDescription: String?
    @Binding var offset: ClockOffset

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(readout)
                    .font(PosterTypography.mono(size: 16))
                    .foregroundStyle(PosterPalette.ink)
                Spacer()
                Text(offsetDescription ?? "Now")
                    .font(PosterTypography.mono(size: 12, weight: .regular))
                    .foregroundStyle(PosterPalette.quietInk)
            }
            .padding(.horizontal, 20)

            ClockOffsetDial(offset: $offset)
        }
        .padding(.vertical, 12)
        .background(PosterPalette.paper)
    }
}
