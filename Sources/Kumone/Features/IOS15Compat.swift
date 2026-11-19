import SwiftUI

// MARK: - iOS 15 navigation backport
//
// iOS 15 has no `NavigationStack`. These shims rebuild the parts of its
// behaviour the app relies on, so the rest of the code can keep treating
// `path` as the single source of truth.

#if os(iOS)
/// A `NavigationStack(path:)` stand-in built on `NavigationView`.
///
/// Every element of `path` is realised as one hidden `NavigationLink` pushed
/// from the level above it. Push, pop, the back button and the interactive
/// edge-swipe all stay native, and mutations of `path` made anywhere in the
/// app keep driving the stack.
struct CompatNavigationStack<Route: Hashable, Content: View>: View {
    private let path: Binding<[Route]>
    private let root: () -> Content
    private let build: (Route) -> AnyView

    init(
        path: Binding<[Route]>,
        destination build: @escaping (Route) -> AnyView,
        @ViewBuilder root: @escaping () -> Content
    ) {
        self.path = path
        self.root = root
        self.build = build
    }

    var body: some View {
        NavigationView {
            root()
                .background(
                    CompatPushLevel(path: path, depth: 0, build: build)
                )
        }
        .navigationViewStyle(.stack)
    }
}

private struct CompatPushLevel<Route: Hashable>: View {
    let path: Binding<[Route]>
    let depth: Int
    let build: (Route) -> AnyView

    private var isActive: Binding<Bool> {
        Binding(
            get: { path.wrappedValue.count > depth },
            set: { active in
                guard !active, path.wrappedValue.count > depth else { return }
                path.wrappedValue.removeSubrange(depth...)
            }
        )
    }

    var body: some View {
        if path.wrappedValue.count > depth {
            NavigationLink(
                isActive: isActive,
                destination: {
                    build(path.wrappedValue[depth])
                        .background(
                            CompatPushLevel(path: path, depth: depth + 1, build: build)
                        )
                },
                label: { EmptyView() }
            )
        }
    }
}
#endif

/// `NavigationLink(value:)` on iOS 16+; on iOS 15 a plain button that appends
/// to the very same `path` through `openDestination`, which every iOS
/// navigation root installs.
struct DestinationLink<Label: View>: View {
    let destination: Destination
    private let label: () -> Label

    @Environment(\.openDestination) private var openDestination

    init(_ destination: Destination, @ViewBuilder label: @escaping () -> Label) {
        self.destination = destination
        self.label = label
    }

    @ViewBuilder
    var body: some View {
        if #available(iOS 16.0, macOS 13.0, *) {
            NavigationLink(value: destination) { label() }
        } else {
            Button { openDestination(destination) } label: { label() }
                .buttonStyle(.plain)
        }
    }
}

extension View {
    /// `contentTransition` is iOS 16 / macOS 13; older systems swap the text
    /// without the cross-fade.
    @ViewBuilder
    func compatContentTransitionOpacity() -> some View {
        if #available(iOS 16.0, macOS 13.0, *) {
            contentTransition(.opacity)
        } else {
            self
        }
    }
}

/// `NavigationStack { … }` on iOS 16+, `NavigationView` on iOS 15 — for sheets
/// that only need a title and a toolbar.
struct CompatSheetStack<Content: View>: View {
    private let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    @ViewBuilder
    var body: some View {
        if #available(iOS 16.0, macOS 13.0, *) {
            NavigationStack { content() }
        } else {
            NavigationView { content() }
                .navigationViewStyle(.stack)
        }
    }
}

extension View {
    /// `scrollDismissesKeyboard` is iOS 16; older systems keep the keyboard up.
    @ViewBuilder
    func compatScrollDismissesKeyboard() -> some View {
        #if os(iOS)
        if #available(iOS 16.0, *) {
            scrollDismissesKeyboard(.interactively)
        } else {
            self
        }
        #else
        self
        #endif
    }
}

/// `ViewThatFits` is iOS 16; on iOS 15 the fallback arrangement is used, which
/// is the one guaranteed to fit a narrow screen.
struct CompatViewThatFits<Content: View, Fallback: View>: View {
    private let content: () -> Content
    private let fallback: () -> Fallback

    init(
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder fallback: @escaping () -> Fallback
    ) {
        self.content = content
        self.fallback = fallback
    }

    @ViewBuilder
    var body: some View {
        if #available(iOS 16.0, macOS 13.0, *) {
            ViewThatFits(in: .horizontal) { content(); fallback() }
        } else {
            fallback()
        }
    }
}

/// `LabeledContent` is iOS 16; older systems lay the two pieces out by hand.
struct CompatLabeledContent<Content: View>: View {
    private let title: String
    private let content: () -> Content

    init(_ title: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }

    @ViewBuilder
    var body: some View {
        if #available(iOS 16.0, macOS 13.0, *) {
            LabeledContent(title) { content() }
        } else {
            HStack {
                Text(title)
                Spacer(minLength: 8)
                content()
            }
        }
    }
}

extension View {
    /// `scrollContentBackground` is iOS 16; older systems keep the default list
    /// background.
    @ViewBuilder
    func compatScrollContentBackgroundHidden() -> some View {
        if #available(iOS 16.0, macOS 13.0, *) {
            scrollContentBackground(.hidden)
        } else {
            self
        }
    }
}

extension View {
    /// `presentationDetents` is iOS 16; older systems present the sheet at its
    /// natural height.
    @ViewBuilder
    func compatPresentationDetentHeight(_ height: CGFloat) -> some View {
        if #available(iOS 16.0, macOS 13.0, *) {
            presentationDetents([.height(height)])
        } else {
            self
        }
    }
}

extension View {
    /// `formStyle(.grouped)` is iOS 16; on iOS 15 `Form` already renders grouped.
    @ViewBuilder
    func compatFormStyleGrouped() -> some View {
        if #available(iOS 16.0, macOS 13.0, *) {
            formStyle(.grouped)
        } else {
            self
        }
    }

    /// `menuOrder(.fixed)` is iOS 16; older systems keep the default order.
    @ViewBuilder
    func compatMenuOrderFixed() -> some View {
        if #available(iOS 16.0, macOS 13.0, *) {
            menuOrder(.fixed)
        } else {
            self
        }
    }

    /// `presentationDetents` is iOS 16; older systems present the sheet at
    /// full height.
    @ViewBuilder
    func compatSheetLarge() -> some View {
        if #available(iOS 16.0, macOS 13.0, *) {
            presentationDetents([.large])
                .presentationDragIndicator(.visible)
        } else {
            self
        }
    }

    @ViewBuilder
    func compatSheetMediumLarge() -> some View {
        if #available(iOS 16.0, macOS 13.0, *) {
            presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        } else {
            self
        }
    }
}

#if os(iOS)
/// iOS 15 fallback for `ShareLink`: the system share sheet, wrapped for SwiftUI.
struct CompatActivityView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
#endif
