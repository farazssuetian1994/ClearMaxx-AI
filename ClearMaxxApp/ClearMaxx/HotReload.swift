//
//  HotReload.swift
//  ClearMaxx — dormant hot-reload hooks (DEBUG only).
//
//  The day-to-day fast-feedback loop is the repo-root `reload.sh` script
//  (incremental build + reinstall + relaunch), because Xcode 26 broke the
//  build-log mechanism the classic InjectionIII relied on.
//
//  These hooks are kept (and harmless) so a code injector can be re-enabled
//  later without touching every screen again. To activate InjectionNext:
//    1. Install InjectionNext.app and launch Xcode via its menu.
//    2. Add the Inject/HotSwiftUI Swift package (it posts the notification below).
//    3. The `-interposable` Debug linker flag is already set.
//  Each screen already declares `@ObserveInjection var inject`, so views will
//  re-render on injection the moment an injector starts posting notifications.
//

import SwiftUI
import Combine

#if DEBUG

/// Currently a no-op. (InjectionNext, if added later, connects over the network
/// from its own package — no bundle to load here.)
func startHotReload() {}

/// Bumps a counter every time InjectionIII injects recompiled code.
final class InjectionObserver: ObservableObject {
    static let shared = InjectionObserver()
    @Published private(set) var injectionNumber = 0
    private var cancellable: AnyCancellable?

    private init() {
        cancellable = NotificationCenter.default
            .publisher(for: Notification.Name("INJECTION_BUNDLE_NOTIFICATION"))
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.injectionNumber &+= 1 }
    }
}

/// Add `@ObserveInjection var inject` to a View so its `body` re-runs (and picks
/// up freshly-injected code) on every save.
@propertyWrapper
struct ObserveInjection: DynamicProperty {
    @ObservedObject private var observer = InjectionObserver.shared
    var wrappedValue: Int { observer.injectionNumber }
    init() {}
}

extension View {
    /// Optional sugar: place at the end of a `body` to also re-render this
    /// subtree on injection. Pairs with `@ObserveInjection`.
    func enableInjection() -> some View { modifier(InjectionModifier()) }
}

private struct InjectionModifier: ViewModifier {
    @ObservedObject private var observer = InjectionObserver.shared
    func body(content: Content) -> some View { content }
}

#else  // Release — everything compiles to nothing.

@inline(__always) func startHotReload() {}

@propertyWrapper
struct ObserveInjection: DynamicProperty {
    var wrappedValue: Int { 0 }
    init() {}
}

extension View {
    @inline(__always) func enableInjection() -> some View { self }
}

#endif
