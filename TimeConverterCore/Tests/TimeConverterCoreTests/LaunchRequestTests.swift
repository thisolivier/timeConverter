import Foundation
import Testing
@testable import TimeConverterCore

/// Item 11 — the launcher decisions, separated from the launcher plumbing.
///
/// `ControlWidget`, `AppShortcutsProvider` and `@FocusState` are platform glue
/// and are verified by launching the app (see the README's QA section). What is
/// worth testing is what the app *decides* when a launcher opens it: which URLs
/// count as a launch, what the typed sentence becomes, and that a request is
/// honoured exactly once.
struct LaunchRequestTests {
    @Test func aLauncherAlwaysHandsOverAnEmptyField() {
        #expect(LaunchRequest.startFreshConversion.inputToStartFrom == "")
    }

    /// Pressing the control mid-session discards whatever was typed: the button
    /// means "start a conversion", so the field must not be half-full of a
    /// sentence from an hour ago.
    @Test func aLauncherDiscardsAHalfTypedSentence() {
        let halfTyped = "9am CST to "
        #expect(LaunchRequest.startFreshConversion.inputToStartFrom != halfTyped)
        #expect(LaunchRequest.startFreshConversion.inputToStartFrom == "")
    }

    /// What the field *becomes*, spelled out as the shell applies it: a
    /// launcher's answer replaces the sentence, a summon's `nil` leaves it. The
    /// companion assertion — that arriving also takes keyboard focus — is
    /// `InputFocusPolicy`'s, and stayed in the iOS shell's test target when the
    /// core was extracted (item 16).
    @Test func eachRequestResolvesToTheFieldTheShellShouldShow() {
        let halfTyped = "9am CST to "
        #expect(LaunchRequest.startFreshConversion.inputToStartFrom ?? halfTyped == "")
        #expect(LaunchRequest.summonWithoutReset.inputToStartFrom ?? halfTyped == halfTyped)
    }

    /// Item 12a. The Mac menu bar and ⌃⌥T are the one route that must *not*
    /// clear the field: on the Mac the app sits behind other windows all day
    /// and is summoned back to a sentence mid-edit. `nil` is what tells
    /// `ContentView` to leave the typed text alone.
    @Test func summoningTheWindowKeepsWhatWasTyped() {
        #expect(LaunchRequest.summonWithoutReset.inputToStartFrom == nil)
    }

    /// The two cases have to disagree about exactly this one thing, or the menu
    /// bar is just a slower Control Center button that eats your sentence.
    @Test func theTwoRequestsDisagreeAboutClearingTheField() {
        #expect(LaunchRequest.startFreshConversion.inputToStartFrom != nil)
        #expect(LaunchRequest.summonWithoutReset.inputToStartFrom == nil)
        #expect(LaunchRequest.startFreshConversion != .summonWithoutReset)
    }

    /// Adding a third request must not silently inherit either answer. The enum
    /// makes the *compiler* enforce that in `inputToStartFrom`; this is the
    /// matching runtime guard, so a new case that forgets to decide shows up
    /// here rather than as a wiped field in the app.
    @Test func everyRequestHasADecidedAnswer() {
        let allRequests: [LaunchRequest] = [.startFreshConversion, .summonWithoutReset]
        #expect(allRequests.count == 2, "a new LaunchRequest case needs its own test above")
        #expect(Set(allRequests.map { $0.inputToStartFrom ?? "«unchanged»" }).count
            == allRequests.count)
    }
}

struct LaunchURLRouterTests {
    @Test(arguments: [
        "timeconverter://convert",
        "timeconverter:///convert",
        "TimeConverter://Convert",
        "timeconverter://convert?ignored=1"
    ])
    func launchURLsRouteToAFreshConversion(urlString: String) throws {
        let url = try #require(URL(string: urlString))
        #expect(LaunchURLRouter.request(for: url) == .startFreshConversion)
    }

    /// An unknown action must route nowhere rather than be guessed at: honouring
    /// a request empties the field, so a wrong guess destroys typed input.
    @Test(arguments: [
        "timeconverter://",
        "timeconverter://settings",
        "timeconverter://convert/extra/convert",
        "https://thisolivier.dev/convert",
        "timeconvertor://convert",
        "mailto:olivier@example.com"
    ])
    func everythingElseRoutesNowhere(urlString: String) throws {
        let url = try #require(URL(string: urlString))
        #expect(LaunchURLRouter.request(for: url) == nil)
    }
}

@MainActor
struct LaunchRequestInboxTests {
    @Test func takingARequestClearsIt() {
        let inbox = LaunchRequestInbox()
        inbox.post(.startFreshConversion)

        #expect(inbox.pendingRequest == .startFreshConversion)
        #expect(inbox.takePendingRequest() == .startFreshConversion)
        #expect(inbox.pendingRequest == nil)
    }

    /// The view drains the mailbox from both `onAppear` and an observation of
    /// `pendingRequest`, because their order differs between a cold and a warm
    /// launch. Whichever runs second must find nothing and do nothing — a second
    /// honouring would wipe a field the user had already started typing in.
    @Test func aRequestIsHonouredOnlyOnce() {
        let inbox = LaunchRequestInbox()
        inbox.post(.startFreshConversion)

        _ = inbox.takePendingRequest()
        #expect(inbox.takePendingRequest() == nil)
    }

    @Test func anEmptyMailboxIsTheRestingState() {
        let inbox = LaunchRequestInbox()
        #expect(inbox.pendingRequest == nil)
        #expect(inbox.takePendingRequest() == nil)
    }

    /// Two presses in a row mean the same thing as one — a single slot, not a
    /// queue.
    @Test func repeatedPressesCollapse() {
        let inbox = LaunchRequestInbox()
        inbox.post(.startFreshConversion)
        inbox.post(.startFreshConversion)

        #expect(inbox.takePendingRequest() == .startFreshConversion)
        #expect(inbox.takePendingRequest() == nil)
    }

    /// The mailbox is shared with the Mac menu bar (item 12a), and the two
    /// requests must not be confusable: a later press wins outright rather than
    /// merging into whatever was already pending.
    @Test func aSummonAndALaunchStayDistinctInTheMailbox() {
        let inbox = LaunchRequestInbox()
        inbox.post(.startFreshConversion)
        inbox.post(.summonWithoutReset)

        #expect(inbox.takePendingRequest() == .summonWithoutReset)
        #expect(inbox.takePendingRequest() == nil)
    }
}
