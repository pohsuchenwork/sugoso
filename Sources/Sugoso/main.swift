import Foundation
import SugosoCore

// Process entry point. Launched with `--run-tests` it runs the framework-free
// state-machine self-tests (handy on machines that only have Command Line Tools,
// which lack XCTest / Swift Testing); otherwise it launches the menu bar app. All
// real behavior lives in SugosoCore - this executable only supplies branding and
// launches the scene. (A file named `main.swift` is the entry point via top-level
// code, so no `@main` attribute is used.)
if CommandLine.arguments.contains("--run-tests") {
    SelfTests.runAndExit()
} else {
    Theme.configure(Theme.freeDefault)
    // Free build only: a single marketing link to the paid "Pro" signup site. This is
    // a plain URL the user's browser opens - no Pro feature code is bundled here.
    PanelExtensions.setPromo(
        PromoLink(title: "Customize with Pro",
                  systemImage: "sparkles",
                  url: URL(string: "https://sugoso-pro-signup.vercel.app")!)
    )
    SugosoApp.main()
}
