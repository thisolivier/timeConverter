import Testing
import SwiftUI
import CoreGraphics
@testable import TimeConverterUI

/// What is worth testing in a design layer — backlog item 20, phase A.
///
/// Not the pixels: a `ConversionPairView` snapshot would assert that SF
/// Compressed renders the way it rendered on the day the baseline was taken,
/// which is a promise Apple never made. What *is* testable, and what actually
/// breaks, is the stuff underneath the drawing: a path transcribed from an SVG
/// by hand, two size steps that have to stay in proportion, and a style enum
/// whose whole job is to hand back different colours per case.
struct ArrowGeometryTests {
    /// The right arrow is transcribed from the design's own path,
    /// `M0 22h62V0l48 32-48 32V42H0z`, against a `0 0 110 64` viewBox. Those
    /// coordinates are the design's; everything below is the arithmetic that
    /// maps them onto a frame, which is exactly where a transcription goes
    /// wrong.
    @Test func theRightArrowFillsItsFrameEdgeToEdge() {
        let frame = CGRect(x: 0, y: 0, width: 110, height: 64)
        let bounds = PosterRightArrow().path(in: frame).boundingRect

        // The tip reaches the trailing edge and the shaft starts at the
        // leading one: an arrow inset from its own frame is the classic
        // symptom of a viewBox scaled with the wrong divisor.
        #expect(abs(bounds.minX - 0) < 0.01)
        #expect(abs(bounds.maxX - 110) < 0.01)
        // The head's points touch top and bottom; the shaft does not.
        #expect(abs(bounds.minY - 0) < 0.01)
        #expect(abs(bounds.maxY - 64) < 0.01)
    }

    /// The same path in a frame of a different size and origin. Shapes are
    /// handed whatever rect the layout gives them, so a hard-coded coordinate
    /// that survived the test above would fail here.
    @Test func theRightArrowScalesAndTranslatesWithItsFrame() {
        let frame = CGRect(x: 20, y: 7, width: 55, height: 32)
        let bounds = PosterRightArrow().path(in: frame).boundingRect

        #expect(abs(bounds.minX - 20) < 0.01)
        #expect(abs(bounds.maxX - 75) < 0.01)
        #expect(abs(bounds.minY - 7) < 0.01)
        #expect(abs(bounds.maxY - 39) < 0.01)
    }

    /// The design's arrow is a solid wedge whose head is twice the depth of
    /// its shaft — that ratio is what stops it reading as a chevron, and it is
    /// the first thing lost if anyone "simplifies" the path. The shaft spans
    /// y 22–42 of 64 (20 units); the head spans the full 64.
    @Test func theArrowHeadIsDeeperThanTheShaft() {
        let frame = CGRect(x: 0, y: 0, width: 110, height: 64)
        let path = PosterRightArrow().path(in: frame)

        // A point just inside the leading edge is in the shaft only, so it is
        // inside the path at mid-height and outside it near the top.
        #expect(path.contains(CGPoint(x: 5, y: 32)))
        #expect(!path.contains(CGPoint(x: 5, y: 5)))
        // The head, by contrast, occupies the full depth near its base.
        #expect(path.contains(CGPoint(x: 64, y: 5)))
    }

    /// The down arrow is unchanged from what the iPhone shipped — it moved
    /// modules in this phase and nothing else. It is a *stroked* open path, so
    /// its bounds are the design's `0 0 26 32` viewBox clipped to the ink:
    /// the stem starts at the top, the head bottoms out at y 28.
    @Test func theDownArrowKeepsItsShippedGeometry() {
        let frame = CGRect(x: 0, y: 0, width: 26, height: 32)
        let bounds = PosterArrow().path(in: frame).boundingRect

        #expect(abs(bounds.minX - 2) < 0.01)
        #expect(abs(bounds.maxX - 24) < 0.01)
        #expect(abs(bounds.minY - 0) < 0.01)
        #expect(abs(bounds.maxY - 28) < 0.01)
    }
}

/// The two size steps of the side-by-side pair.
struct ConversionPairScaleTests {
    /// Compact is a **step down**, not a different composition: every piece
    /// gets smaller, none grows, and nothing stays the same size while its
    /// neighbour shrinks — which is how a proportion turns into an accident.
    @Test func compactIsSmallerThanFullInEveryDimension() {
        let full = ConversionPairScale.full
        let compact = ConversionPairScale.compact

        #expect(compact.labelSize < full.labelSize)
        #expect(compact.placeSize < full.placeSize)
        #expect(compact.clockSize < full.clockSize)
        #expect(compact.meridiemSize < full.meridiemSize)
        #expect(compact.subLineSize < full.subLineSize)
        #expect(compact.arrowColumnWidth < full.arrowColumnWidth)
        #expect(compact.arrowSize.width < full.arrowSize.width)
        #expect(compact.arrowSize.height < full.arrowSize.height)
    }

    /// The design's own numbers, unmodified, at full scale — the values the
    /// glass panel's markup declares. A drift here is a drift away from the
    /// mockup.
    @Test func fullScaleIsTheDesignsOwnNumbers() {
        let full = ConversionPairScale.full
        #expect(full.labelSize == 12)
        #expect(full.placeSize == 40)
        #expect(full.clockSize == 124)
        #expect(full.meridiemSize == 38)
        #expect(full.subLineSize == 14)
        #expect(full.arrowColumnWidth == 96)
        #expect(full.arrowSize == CGSize(width: 72, height: 42))
    }

    /// The numerals must stay dramatically larger than the furniture around
    /// them at *both* steps. This is the composition the design is: a poster
    /// numeral beside a caption, not two sizes of label.
    @Test(arguments: ConversionPairScale.allCases)
    func theNumeralsDwarfTheLabelsAtEveryScale(scale: ConversionPairScale) {
        #expect(scale.clockSize > scale.placeSize * 2)
        #expect(scale.clockSize > scale.labelSize * 6)
        // The meridiem rides with the numerals rather than with the labels.
        #expect(scale.meridiemSize > scale.subLineSize)
        #expect(scale.meridiemSize < scale.clockSize)
    }

    /// The arrow has to fit the column it is centred in, at both steps —
    /// otherwise it overlaps the numerals beside it.
    @Test(arguments: ConversionPairScale.allCases)
    func theArrowFitsItsColumn(scale: ConversionPairScale) {
        #expect(scale.arrowSize.width < scale.arrowColumnWidth)
        #expect(scale.labeledArrowSize.width < scale.labeledArrowColumnWidth)
    }

    /// Page 4's gutter is wider than pages 2–3's, and that is not decoration:
    /// `4 hours behind` under a 96pt arrow does not fit, and a phrase that
    /// overruns its column lands on the numerals in the next one. This is the
    /// assertion that caught exactly that during phase A.
    @Test(arguments: ConversionPairScale.allCases)
    func theLabeledGutterIsWiderThanThePlainOne(scale: ConversionPairScale) {
        #expect(scale.labeledArrowColumnWidth > scale.arrowColumnWidth)
        #expect(scale.labeledArrowSize.width > scale.arrowSize.width)
        // Room for the longest phrase the formatter produces — `12.75 hours
        // behind`, 18 characters — at the label's size, allowing for the
        // 0.6 minimum scale factor that catches the rest.
        let widestPhraseWidth = 18 * scale.arrowLabelSize * 0.6 * 0.6
        #expect(scale.labeledArrowColumnWidth > widestPhraseWidth)
    }

    /// The flatter page-4 arrow is a different *frame*, not a different path:
    /// it keeps the design's height and only grows longer.
    @Test(arguments: ConversionPairScale.allCases)
    func theLabeledArrowStretchesRatherThanGrowing(scale: ConversionPairScale) {
        #expect(scale.labeledArrowSize.height == scale.arrowSize.height)
        let plainRatio = scale.arrowSize.width / scale.arrowSize.height
        let labeledRatio = scale.labeledArrowSize.width / scale.labeledArrowSize.height
        #expect(labeledRatio > plainRatio)
    }

    /// The compact step keeps roughly the design's aspect ratio for the arrow
    /// rather than squashing it into a different glyph.
    @Test func theArrowKeepsItsProportionsWhenItShrinks() {
        let fullRatio = ConversionPairScale.full.arrowSize.width
            / ConversionPairScale.full.arrowSize.height
        let compactRatio = ConversionPairScale.compact.arrowSize.width
            / ConversionPairScale.compact.arrowSize.height
        #expect(abs(fullRatio - compactRatio) < 0.1)
    }
}

/// The paper/glass switch.
struct ConversionPairStyleTests {
    /// The two languages genuinely differ — if a refactor ever collapsed them
    /// onto one palette, every assertion below would pass except these.
    @Test func paperAndGlassDisagreeAboutEveryInk() {
        #expect(ConversionPairStyle.paper.ink != ConversionPairStyle.glass.ink)
        #expect(ConversionPairStyle.paper.quietInk != ConversionPairStyle.glass.quietInk)
        #expect(ConversionPairStyle.paper.arrowTint != ConversionPairStyle.glass.arrowTint)
    }

    /// The loudest difference between pages 2 and 3: rust on paper, grey on
    /// glass. The glass arrow is the *same* colour as the glass furniture,
    /// which is what makes the panel read as native rather than as a poster
    /// behind frosted glass.
    @Test func theArrowIsRustOnPaperAndSecondaryInkOnGlass() {
        #expect(ConversionPairStyle.paper.arrowTint == PosterPalette.accent)
        #expect(ConversionPairStyle.glass.arrowTint == GlassPalette.secondaryInk)
        #expect(ConversionPairStyle.glass.arrowTint == ConversionPairStyle.glass.quietInk)
    }

    /// Paper is a print and a print has one ink, so its labels and its
    /// numerals are the same colour; glass builds its hierarchy out of
    /// contrast instead, because on a material size alone does not carry it.
    @Test func paperUsesOneInkAndGlassUsesTwo() {
        #expect(ConversionPairStyle.paper.ink == ConversionPairStyle.paper.quietInk)
        #expect(ConversionPairStyle.glass.ink != ConversionPairStyle.glass.quietInk)
    }

    /// `FROM` above the place on paper (pages 2 and 4), beside it on glass
    /// (page 3).
    @Test func onlyPaperStacksItsLabels() {
        #expect(ConversionPairStyle.paper.stacksLabelAbovePlace)
        #expect(!ConversionPairStyle.glass.stacksLabelAbovePlace)
    }
}

/// The glass tokens, as transcribed from the design's markup.
struct GlassPaletteTests {
    /// The hairline is 1pt, not the poster's 2pt rule: on a material a heavy
    /// rule reads as a seam. Cheap to assert, and it is the kind of constant
    /// that gets "tidied" to match its neighbour.
    @Test func theGlassRuleIsAHairlineAndNotAPosterRule() {
        #expect(GlassPalette.hairlineThickness == 1)
    }

    /// The shadow is the design's `0 24px 70px`, with the blur halved because
    /// a CSS blur radius spans the whole falloff and SwiftUI's does not.
    /// Getting this wrong by a factor of two is the usual way a transcribed
    /// shadow becomes a smear.
    @Test func theShadowHalvesTheCSSBlurRadius() {
        #expect(GlassPalette.panelShadowOffsetY == 24)
        #expect(GlassPalette.panelShadowRadius == 35)
    }

    /// `border-radius: 30px`.
    @Test func thePanelKeepsTheDesignsCornerRadius() {
        #expect(GlassPalette.panelCornerRadius == 30)
    }
}

/// The colour pairing helper both palettes are built on.
struct PaletteToneTests {
    /// The poster writes its tokens as packed hex, the glass design writes
    /// them as CSS `rgba`. Both have to land on the same normalised
    /// components, or one of the two palettes is quietly wrong.
    @Test func thePackedAndChannelInitialisersAgree() {
        let packed = PaletteTone(packedRGB: 0xEB_D3_A9)
        let channels = PaletteTone(red: 235, green: 211, blue: 169, alpha: 1)
        #expect(packed == channels)
    }

    /// Components are normalised to 0...1 on the way in, which is what every
    /// platform colour type wants.
    @Test func componentsAreNormalised() {
        let white = PaletteTone(red: 255, green: 255, blue: 255, alpha: 0.42)
        #expect(white.red == 1)
        #expect(white.green == 1)
        #expect(white.blue == 1)
        #expect(white.alpha == 0.42)

        let black = PaletteTone(packedRGB: 0x00_00_00)
        #expect(black.red == 0)
        #expect(black.alpha == 1)
    }

    /// Alpha survives the packed form, which carries no alpha channel of its
    /// own — the poster's inks are opaque, the glass's are not.
    @Test func thePackedFormCarriesAnExplicitAlpha() {
        #expect(PaletteTone(packedRGB: 0x14_12_10, alpha: 0.3).alpha == 0.3)
    }
}
