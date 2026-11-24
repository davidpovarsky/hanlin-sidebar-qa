import SwiftUI
import UIKit

// Hanlin AI Navigation Prototype - Swift Playgrounds (single-file App)
// Screen names and feature groups are based on the existing Hanlin source.
// This preview is self-contained: no API keys, SwiftData or Hanlin packages.

@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

private enum Theme {
    static let accent = Color(red: 0.18, green: 0.42, blue: 0.86)
    static let teal = Color(red: 0.09, green: 0.60, blue: 0.57)
    static let green = Color(red: 0.14, green: 0.58, blue: 0.37)
    static let sidebar = Color(uiColor: .secondarySystemGroupedBackground)
    static let card = Color(uiColor: .secondarySystemGroupedBackground)
}

private extension View {
    @ViewBuilder
    func avoidingWindowControls() -> some View {
        // Older SDKs already reserve a compatibility safe area. With the
        // iOS 26 SDK, custom bars must adapt to the real window-control inset.
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            self.containerCornerOffset(.horizontal, sizeToFit: true)
        } else {
            self
        }
        #else
        self
        #endif
    }
}

private struct DemoChat: Identifiable {
    let id: Int
    var title: String
    var summary: String
    var pinned: Bool
}

private struct DemoPost: Identifiable {
    let id = UUID()
    let isUser: Bool
    let text: String
}

private enum DemoPage {
    case chat
    case knowledge
}

private enum QuickAction: String, Identifiable, CaseIterable {
    case translate = "תרגום מיידי"
    case polish = "שיפור ניסוח"
    case summarize = "סיכום מיידי"
    
    var id: String { rawValue }
    
    var accessibilityKey: String {
        switch self {
        case .translate: "translate"
        case .polish: "polish"
        case .summarize: "summarize"
        }
    }

    var shortLabel: String {
        switch self {
        case .translate: "תרגום"
        case .polish: "שיפור"
        case .summarize: "סיכום"
        }
    }
    
    var icon: String {
        switch self {
        case .translate: "character.book.closed"
        case .polish: "wand.and.stars"
        case .summarize: "highlighter"
        }
    }
}

struct ContentView: View {
    @Environment(\.layoutDirection) private var contentLayoutDirection
    @Environment(\.scenePhase) private var scenePhase
    @FocusState private var sidebarSearchFocused: Bool
    @State private var chats: [DemoChat] = [
        .init(id: 1, title: "מחקר עם מקורות", summary: "חיפוש, Evidence ומקורות", pinned: true),
        .init(id: 2, title: "בניית אוטומציה", summary: "Skills ו־MCP", pinned: true),
        .init(id: 3, title: "תכנון אפליקציית SwiftUI", summary: "תכנון מסכים", pinned: false),
        .init(id: 4, title: "סיכום מסמך", summary: "מסמכים וידע", pinned: false)
    ]
    @State private var posts: [Int: [DemoPost]] = [
        1: [
            .init(isUser: true, text: "תוכל לחקור נושא ולהציג מקורות בתוך התשובה?"),
            .init(isUser: false, text: "ב־Hanlin קיימים חיפוש, מקורות בפסקאות, Evidence ופעילות סוכן. כאן מוצגת התוצאה לדוגמה בלי קריאת API.")
        ],
        2: [
            .init(isUser: true, text: "איפה מנהלים Skills ו־MCP?"),
            .init(isUser: false, text: "הסוכן משתמש בהם מתוך השיחה. הניהול נמצא בהגדרות > כלים וחיבורים, ולא בטאב נפרד.")
        ],
        3: [.init(isUser: false, text: "כאן יופיע ChatView המקורי עם Composer ו־AgentRun.")],
        4: [.init(isUser: false, text: "KnowledgeListView, MemoryArchiveView ו־PromptRepoView נשארים נגישים בספרייה.")]
    ]
    @State private var chatID = 1
    @State private var page: DemoPage = .chat
    @State private var sidebarVisible = true
    @State private var compactSidebarVisible = false
    @State private var compactHomeVisible = false
    @State private var dragOffset: CGFloat = 0
    @State private var search = ""
    @State private var draft = ""
    @State private var settingsVisible = false
    @State private var miniAppsVisible = false
    @State private var chosenAction: QuickAction?
    @State private var searchOn = true
    @State private var knowledgeOn = false
    @State private var toolsOn = true
    @State private var thinkingOn = false
    
    // The prototype has Hebrew content even without a localized bundle.
    // Honor the actual app language/locale rather than the physical LTR drawer.
    private var interfaceDirection: LayoutDirection {
        if contentLayoutDirection == .rightToLeft ||
            UIView.userInterfaceLayoutDirection(for: .unspecified) == .rightToLeft ||
            Locale.current.language.characterDirection == .rightToLeft ||
            Locale.preferredLanguages.first.map({ Locale.Language(identifier: $0).characterDirection == .rightToLeft }) == true {
            return .rightToLeft
        }
        return .leftToRight
    }

    private var chatTitle: String {
        chats.first(where: { $0.id == chatID })?.title ?? "שיחה חדשה"
    }
    
    var body: some View {
        GeometryReader { geometry in
            contentForWidth(geometry.size.width)
        }
        .fullScreenCover(isPresented: $settingsVisible) {
            SettingsHomeView()
        }
        .fullScreenCover(isPresented: $miniAppsVisible) {
            MiniAppsPreviewView()
        }
        .sheet(item: $chosenAction) { action in
            QuickActionView(action: action)
        }
    }
    
    private func contentForWidth(_ width: CGFloat) -> some View {
        GeometryReader { geometry in
            let wide = UIDevice.current.userInterfaceIdiom != .phone && width >= 640
            let sidebarWidth = wide ? min(295, width * 0.35) : min(310, width * 0.78)
            let progress = wide ? (sidebarVisible ? CGFloat(1) : CGFloat(0)) :
                min(1, max(0, (compactSidebarVisible ? CGFloat(1) : CGFloat(0)) + dragOffset / sidebarWidth))
            let sidebarOpen = wide ? sidebarVisible : compactSidebarVisible

            ZStack(alignment: .leading) {
                Theme.sidebar.ignoresSafeArea()

                // The original sidebar, including Settings, is one transformed layer.
                sidebar
                    .environment(\.layoutDirection, interfaceDirection)
                    .frame(width: sidebarWidth, height: geometry.size.height)
                    // Scope this layer's hit shape and visibility to its own
                    // accessibility container, preserving each child control.
                    .accessibilityElement(children: .contain)
                    .contentShape(Rectangle())
                    .scaleEffect(wide ? 1 : 0.86 + 0.14 * progress, anchor: .trailing)
                    .offset(x: wide ? 0 : 22 * (1 - progress))
                    .opacity(wide ? (sidebarVisible ? 1 : 0) : 0.72 + 0.28 * progress)
                    .allowsHitTesting(sidebarOpen)
                    .accessibilityHidden(!sidebarOpen)
                    .zIndex(0)

                workspace(wide: wide)
                    .environment(\.layoutDirection, interfaceDirection)
                    .frame(width: wide && sidebarVisible ? width - sidebarWidth : width,
                           height: geometry.size.height)
                    .background(Color(uiColor: .systemBackground))
                    .accessibilityElement(children: .contain)
                    // The hit region moves with the content, before its translation.
                    .contentShape(Rectangle())
                    .clipShape(RoundedRectangle(cornerRadius: wide ? 0 : 20 * progress))
                    .shadow(color: .black.opacity(wide ? 0 : 0.13 * progress), radius: 18, x: -4)
                    .offset(x: wide ? (sidebarVisible ? sidebarWidth : 0) : sidebarWidth * progress)
                    .zIndex(1)
            }
            // Bound the viewport's hit region as well as its visible drawing.
            .frame(width: width, height: geometry.size.height, alignment: .leading)
            .accessibilityElement(children: .contain)
            .contentShape(Rectangle())
            .clipped()
            .environment(\.layoutDirection, .leftToRight)
            .gesture(
                PhysicalSidebarPan(
                    enabled: !wide && !settingsVisible && !miniAppsVisible && chosenAction == nil,
                    isOpen: compactSidebarVisible,
                    size: CGSize(width: width, height: geometry.size.height),
                    onMove: { dx in
                        var transaction = Transaction()
                        transaction.disablesAnimations = true
                        withTransaction(transaction) {
                            dragOffset = min(compactSidebarVisible ? 0 : sidebarWidth,
                                             max(compactSidebarVisible ? -sidebarWidth : 0, dx))
                        }
                    },
                    onFinish: { dx, velocity, cancelled in
                        let initial = compactSidebarVisible ? sidebarWidth : 0
                        let projected = initial + dx + (cancelled ? 0 : velocity * 0.15)
                        setCompactSidebar(projected > sidebarWidth * 0.5)
                    }
                )
            )
            .onChange(of: geometry.size) { _, _ in resetDrag() }
            .onChange(of: scenePhase) { _, phase in
                if phase != .active { resetDrag() }
            }
        }
    }

    private func resetDrag() {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            dragOffset = 0
        }
    }

    @ViewBuilder
    private func workspace(wide: Bool) -> some View {
        if !wide && compactHomeVisible && page == .chat {
            CompactHomeWorkspace(
                chats: chats,
                draft: $draft,
                searchOn: $searchOn,
                knowledgeOn: $knowledgeOn,
                toolsOn: $toolsOn,
                thinkingOn: $thinkingOn,
                onNew: newChat,
                onLibrary: {
                    page = .knowledge
                    compactHomeVisible = false
                },
                onViewAll: { setCompactSidebar(true) },
                onChat: selectChat,
                onSettings: { settingsVisible = true },
                onAction: { chosenAction = $0 },
                onMiniApps: { miniAppsVisible = true },
                onSend: sendFromCompactHome
            )
        } else if page == .chat {
            ChatScreen(
                title: chatTitle,
                messages: posts[chatID] ?? [],
                draft: $draft,
                searchOn: $searchOn,
                knowledgeOn: $knowledgeOn,
                toolsOn: $toolsOn,
                thinkingOn: $thinkingOn,
                isWide: wide,
                sidebarOpen: wide ? sidebarVisible : compactSidebarVisible,
                onSidebar: { toggleSidebar(wide: wide) },
                onHome: { toggleSidebar(wide: wide) },
                onMiniApps: { miniAppsVisible = true },
                onSend: send
            )
        } else {
            LibraryScreen(
                onSidebar: { toggleSidebar(wide: wide) },
                onBack: {
                    page = .chat
                    if !wide { compactHomeVisible = true }
                }
            )
        }
    }
    
    private var sidebar: some View {
        HistorySidebar(
            chats: chats,
            selectedID: chatID,
            currentPage: page,
            search: $search,
            searchFocused: $sidebarSearchFocused,
            onNew: newChat,
            onChat: selectChat,
            onAction: {
                sidebarSearchFocused = false
                chosenAction = $0
            },
            onLibrary: {
                page = .knowledge
                compactHomeVisible = false
                setCompactSidebar(false)
            },
            onSettings: {
                // Present from the stable root without dismissing or moving
                // the sidebar in the same update transaction.
                sidebarSearchFocused = false
                settingsVisible = true
            },
            onPin: togglePin
        )
    }
    
    private func toggleSidebar(wide: Bool) {
        if wide {
            if sidebarVisible { sidebarSearchFocused = false }
            withAnimation(.easeInOut(duration: 0.2)) {
                sidebarVisible.toggle()
            }
        } else {
            setCompactSidebar(!compactSidebarVisible)
        }
    }

    private func setCompactSidebar(_ open: Bool) {
        if !open { sidebarSearchFocused = false }
        withAnimation(.interactiveSpring(response: 0.34, dampingFraction: 0.88)) {
            compactSidebarVisible = open
            dragOffset = 0
        }
    }
    
    private func sendFromCompactHome() {
        let value = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        newChat()
        draft = value
        send()
    }
    
    private func newChat() {
        let id = (chats.map(\.id).max() ?? 0) + 1
        chats.insert(.init(id: id, title: "שיחה חדשה", summary: "שיחה חדשה", pinned: false), at: 0)
        posts[id] = []
        chatID = id
        page = .chat
        draft = ""
        compactHomeVisible = false
        setCompactSidebar(false)
    }
    
    private func selectChat(_ id: Int) {
        // End editing before the searched row disappears and the drawer
        // animates away. A focus-state update alone may leave UIKit's
        // responder/keyboard active after the TextField is removed.
        sidebarSearchFocused = false
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                        to: nil, from: nil, for: nil)
        chatID = id
        page = .chat
        compactHomeVisible = false
        setCompactSidebar(false)
        draft = ""
    }
    
    private func togglePin(_ id: Int) {
        guard let index = chats.firstIndex(where: { $0.id == id }) else { return }
        chats[index].pinned.toggle()
    }
    
    private func send() {
        let value = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        posts[chatID, default: []].append(.init(isUser: true, text: value))
        posts[chatID, default: []].append(.init(isUser: false, text: "הודעת הדגמה: הניווט החדש עובד. באפליקציה המלאה ChatView ו־APIManager יפיקו כאן תשובה אמיתית."))
        if let index = chats.firstIndex(where: { $0.id == chatID }) {
            if chats[index].title == "שיחה חדשה" {
                chats[index].title = String(value.prefix(28))
            }
            chats[index].summary = value
        }
        draft = ""
    }
}

// MARK: History / original ListView

// UIKit performs axis arbitration while SwiftUI owns this recognizer's
// lifetime, target action and scope in the fixed viewport. A window-level
// recognizer can receive cancellation before dispatch in a floating iPad scene.
@MainActor
private struct PhysicalSidebarPan: UIGestureRecognizerRepresentable {
    var enabled: Bool
    var isOpen: Bool
    var size: CGSize
    var onMove: (CGFloat) -> Void
    var onFinish: (CGFloat, CGFloat, Bool) -> Void

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator {
        Coordinator(configuration: self, converter: converter)
    }

    func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        let recognizer = UIPanGestureRecognizer()
        recognizer.maximumNumberOfTouches = 1
        recognizer.cancelsTouchesInView = true
        recognizer.delegate = context.coordinator
        recognizer.isEnabled = enabled
        return recognizer
    }

    func updateUIGestureRecognizer(_ recognizer: UIPanGestureRecognizer, context: Context) {
        context.coordinator.configuration = self
        // The view and recognizer remain mounted across real window resizing.
        if recognizer.isEnabled != enabled {
            recognizer.isEnabled = enabled
        }
    }

    func handleUIGestureRecognizerAction(_ recognizer: UIPanGestureRecognizer, context: Context) {
        guard enabled else { return }
        let dx = context.converter.localTranslation?.x ?? 0
        switch recognizer.state {
        case .began, .changed:
            onMove(dx)
        case .ended:
            onFinish(dx, context.converter.localVelocity?.x ?? 0, false)
        case .cancelled, .failed:
            onFinish(dx, 0, true)
        default:
            break
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var configuration: PhysicalSidebarPan
        private let converter: CoordinateSpaceConverter

        init(configuration: PhysicalSidebarPan, converter: CoordinateSpaceConverter) {
            self.configuration = configuration
            self.converter = converter
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            let startPoint = converter.convert(globalPoint: touch.location(in: nil), to: .local)
            return configuration.enabled
                && CGRect(origin: .zero, size: configuration.size).contains(startPoint)
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard configuration.enabled else { return false }
            let velocity = converter.localVelocity ?? .zero
            guard abs(velocity.x) > abs(velocity.y) * 1.3 else { return false }
            return configuration.isOpen ? velocity.x < 0 : velocity.x > 0
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            // Preserve the prototype's native controls and vertical scrolling.
            // Only the physical horizontal direction gate admits this gesture.
            true
        }
    }
}

private struct HistorySidebar: View {
    let chats: [DemoChat]
    let selectedID: Int
    let currentPage: DemoPage
    @Binding var search: String
    let searchFocused: FocusState<Bool>.Binding
    let onNew: () -> Void
    let onChat: (Int) -> Void
    let onAction: (QuickAction) -> Void
    let onLibrary: () -> Void
    let onSettings: () -> Void
    let onPin: (Int) -> Void
    
    private var filteredChats: [DemoChat] {
        chats.filter { chat in
            search.isEmpty || chat.title.localizedCaseInsensitiveContains(search) || chat.summary.localizedCaseInsensitiveContains(search)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            header
            searchBox
            QuickActionsRow(onAction: onAction)
                .padding(.horizontal, 10)
                .padding(.top, 13)
            quickLinks
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 17) {
                    section("מוצמדות", chats: filteredChats.filter(\.pinned))
                    section("אחרונות", chats: filteredChats.filter { !$0.pinned })
                }
                .padding(12)
            }
            .accessibilityIdentifier("sidebar-chat-list")
            Divider()
            Button(action: onSettings) {
                Label("הגדרות", systemImage: "gearshape")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(17)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("sidebar-settings")
        }
        .background(Theme.sidebar)
    }
    
    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.title2)
                .foregroundColor(Theme.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text("Hanlin AI").font(.headline)
                Text("Hylic.AI").font(.caption2).foregroundColor(.secondary)
            }
            Spacer()
            Button(action: onNew) {
                Image(systemName: "plus.bubble")
                    .font(.title3)
                    .foregroundColor(.accentColor)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("שיחה חדשה")
            .accessibilityIdentifier("sidebar-new-chat")
        }
        .padding(.leading, 17)
        .padding(.trailing, 8)
        .padding(.vertical, 12)
        .avoidingWindowControls()
    }
    
    private var searchBox: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundColor(.secondary)
            TextField("חיפוש שיחות והודעות", text: $search)
                .accessibilityIdentifier("sidebar-search")
                .focused(searchFocused)
        }
        .padding(10)
        .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 12)
    }
    
    private var quickLinks: some View {
        VStack(spacing: 4) {
            sidebarButton("ספריית ידע", icon: "books.vertical", action: onLibrary)
                .accessibilityIdentifier("sidebar-library")
        }
        .padding(12)
    }
    
    private func sidebarButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(11)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    private func section(_ title: String, chats: [DemoChat]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption.weight(.bold)).foregroundColor(.secondary)
                .padding(.horizontal, 9)
            ForEach(chats) { chat in
                HistoryChatRow(
                    chat: chat,
                    selected: currentPage == .chat && selectedID == chat.id,
                    onSelect: { onChat(chat.id) },
                    onPin: { onPin(chat.id) }
                )
            }
        }
    }
}

private struct HistoryChatRow: View {
    let chat: DemoChat
    let selected: Bool
    let onSelect: () -> Void
    let onPin: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 10) {
                Image(systemName: "bubble.left").foregroundColor(.secondary)
                VStack(alignment: .leading, spacing: 3) {
                    Text(chat.title).font(.subheadline.weight(.medium)).lineLimit(1)
                    Text(chat.summary).font(.caption2).foregroundColor(.secondary).lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(10)
            .background(selected ? Theme.accent.opacity(0.12) : Color.clear, in: RoundedRectangle(cornerRadius: 10))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("sidebar-chat-\(chat.id)")
        .accessibilityValue(chat.pinned ? "pinned" : "unpinned")
        .contextMenu {
            Button(action: onPin) {
                Label(chat.pinned ? "בטל הצמדה" : "הצמד שיחה", systemImage: chat.pinned ? "pin.slash" : "pin")
            }
        }
    }
}

// MARK: Compact iPhone / iPad narrow home (HanlinCompactChatWorkspace)

private struct CompactHomeWorkspace: View {
    let chats: [DemoChat]
    @Binding var draft: String
    @Binding var searchOn: Bool
    @Binding var knowledgeOn: Bool
    @Binding var toolsOn: Bool
    @Binding var thinkingOn: Bool
    let onNew: () -> Void
    let onLibrary: () -> Void
    let onViewAll: () -> Void
    let onChat: (Int) -> Void
    let onSettings: () -> Void
    let onAction: (QuickAction) -> Void
    let onMiniApps: () -> Void
    let onSend: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            homeToolbar
            Divider()
            homeScroll
            Divider()
            ChatComposerView(
                draft: $draft,
                searchOn: $searchOn,
                knowledgeOn: $knowledgeOn,
                toolsOn: $toolsOn,
                thinkingOn: $thinkingOn,
                onMiniApps: onMiniApps,
                onSend: onSend
            )
        }
        .background(Color(uiColor: .systemBackground))
    }
    
    private var homeToolbar: some View {
        HStack {
            Text("Hylic.AI").font(.headline)
            Spacer()
            Button(action: onNew) {
                Image(systemName: "plus.bubble")
                    .font(.title3)
            }
            .accessibilityLabel("שיחה חדשה")
        }
        .padding(.horizontal, 19)
        .padding(.vertical, 15)
        .avoidingWindowControls()
    }
    
    private var homeScroll: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 23) {
                QuickActionsRow(onAction: onAction)
                welcome
                recentChats
                footerLinks
            }
            .frame(maxWidth: 760, alignment: .leading)
            .padding(19)
            .frame(maxWidth: .infinity)
        }
    }
    
    private var welcome: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "sparkles.rectangle.stack")
                .font(.system(size: 30))
                .foregroundColor(Theme.accent)
            Text("במה נוכל לעזור?")
                .font(.largeTitle.weight(.semibold))
            Text("אפשר להתחיל שיחה חדשה למטה או לפתוח שיחה קודמת.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 16)
    }
    
    private var recentChats: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("שיחות אחרונות")
                    .font(.headline)
                Spacer()
                Button("הצג הכול", action: onViewAll)
                    .font(.subheadline)
            }
            ForEach(Array(chats.prefix(3))) { chat in
                Button { onChat(chat.id) } label: {
                    Label(chat.title, systemImage: "bubble.left")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 11)
                }
                .buttonStyle(.plain)
                Divider()
            }
        }
    }
    
    private var footerLinks: some View {
        HStack(spacing: 12) {
            Button(action: onLibrary) {
                Label("ספריית ידע", systemImage: "books.vertical")
                    .frame(maxWidth: .infinity)
            }
            Button(action: onSettings) {
                Label("הגדרות", systemImage: "gearshape")
                    .frame(maxWidth: .infinity)
            }
        }
        .font(.subheadline)
        .buttonStyle(.bordered)
        .padding(.top, 8)
    }
}

private struct CompactConversationLibrary: View {
    let chats: [DemoChat]
    let selectedID: Int
    let onClose: () -> Void
    let onNew: () -> Void
    let onChat: (Int) -> Void
    let onLibrary: () -> Void
    let onPin: (Int) -> Void
    @State private var search = ""
    @State private var settingsVisible = false
    
    private var filteredChats: [DemoChat] {
        chats.filter { item in
            search.isEmpty || item.title.localizedCaseInsensitiveContains(search)
            || item.summary.localizedCaseInsensitiveContains(search)
        }
    }
    
    var body: some View {
        NavigationStack {
            chatList
                .navigationTitle("כל השיחות")
                .searchable(text: $search, prompt: "חיפוש שיחות והודעות")
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("סגור", action: onClose)
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(action: onNew) {
                            Label("שיחה חדשה", systemImage: "plus.bubble")
                        }
                    }
                }
                .safeAreaInset(edge: .bottom) {
                    bottomActions
                }
        }
        .fullScreenCover(isPresented: $settingsVisible) {
            SettingsHomeView()
        }
    }
    
    private var chatList: some View {
        List {
            Section("מוצמדות") {
                ForEach(filteredChats.filter(\.pinned)) { chat in
                    HistoryChatRow(
                        chat: chat,
                        selected: selectedID == chat.id,
                        onSelect: { onChat(chat.id) },
                        onPin: { onPin(chat.id) }
                    )
                }
            }
            Section("אחרונות") {
                ForEach(filteredChats.filter { !$0.pinned }) { chat in
                    HistoryChatRow(
                        chat: chat,
                        selected: selectedID == chat.id,
                        onSelect: { onChat(chat.id) },
                        onPin: { onPin(chat.id) }
                    )
                }
            }
        }
    }
    
    private var bottomActions: some View {
        HStack(spacing: 16) {
            Button(action: onLibrary) {
                Label("ספריית ידע", systemImage: "books.vertical")
            }
            Spacer()
            Button { settingsVisible = true } label: {
                Label("הגדרות", systemImage: "gearshape")
            }
        }
        .font(.subheadline)
        .padding(14)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
    }
}

// MARK: Chat / original ChatView, ChatBubbleView, Composer, AgentRun

private struct ChatScreen: View {
    let title: String
    let messages: [DemoPost]
    @Binding var draft: String
    @Binding var searchOn: Bool
    @Binding var knowledgeOn: Bool
    @Binding var toolsOn: Bool
    @Binding var thinkingOn: Bool
    let isWide: Bool
    let sidebarOpen: Bool
    let onSidebar: () -> Void
    let onHome: () -> Void
    let onMiniApps: () -> Void
    let onSend: () -> Void
    @State private var activityOpen = false
    
    var body: some View {
        VStack(spacing: 0) {
            chatToolbar
            Divider()
            ChatHistoryView(messages: messages, onInspect: { activityOpen = true })
            Divider()
            ChatComposerView(
                draft: $draft,
                searchOn: $searchOn,
                knowledgeOn: $knowledgeOn,
                toolsOn: $toolsOn,
                thinkingOn: $thinkingOn,
                onMiniApps: onMiniApps,
                onSend: onSend
            )
        }
        .background(Color(uiColor: .systemBackground))
        .sheet(isPresented: $activityOpen) {
            AgentActivityView()
        }
    }
    
    private var chatToolbar: some View {
        HStack(spacing: 7) {
            Button {
                onSidebar()
            } label: {
                Image(systemName: "sidebar.left")
                    .foregroundColor(.accentColor)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("הצג סרגל שיחות")
            .accessibilityIdentifier("sidebar-toggle")
            .accessibilityValue(sidebarOpen ? "open" : "closed")
            
            Text(title)
                .accessibilityIdentifier("chat-title")
                .font(.headline)
                .lineLimit(1)
            Spacer(minLength: 0)
            // No model / new-chat / settings buttons in chat title bar.
        }
        .environment(\.layoutDirection, .leftToRight)
        .font(.title3)
        .padding(.leading, 11)
        .padding(.trailing, 19)
        .padding(.vertical, 3)
        .avoidingWindowControls()
    }
}

private struct ChatHistoryView: View {
    let messages: [DemoPost]
    let onInspect: () -> Void
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                if messages.isEmpty {
                    emptyState
                }
                ForEach(messages) { message in
                    ChatBubbleRow(message: message, onInspect: onInspect)
                }
            }
            .frame(maxWidth: 800, alignment: .leading)
            .padding(20)
            .frame(maxWidth: .infinity)
        }
        .accessibilityIdentifier("chat-history")
    }
    
    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: "sparkles.rectangle.stack")
                .font(.system(size: 36))
                .foregroundColor(Theme.accent)
            Text("במה נוכל לעזור?").font(.largeTitle.weight(.semibold))
                .accessibilityIdentifier("chat-empty")
            Text("שיחה חדשה, חיפוש, תרגום, Skills, MCP ו־Knowledge — בלי סרגל טאבים.")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 45)
    }
}

private struct QuickActionsRow: View {
    let onAction: (QuickAction) -> Void
    
    var body: some View {
        HStack(spacing: 6) {
            ForEach(QuickAction.allCases) { action in
                Button { onAction(action) } label: {
                    VStack(spacing: 4) {
                        Image(systemName: action.icon)
                            .font(.subheadline)
                        Text(action.shortLabel)
                            .font(.caption2.weight(.medium))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, minHeight: 40)
                    .padding(.vertical, 5)
                    .background(Theme.accent.opacity(0.09), in: RoundedRectangle(cornerRadius: 11))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(action.rawValue)
                .accessibilityIdentifier("sidebar-action-\(action.accessibilityKey)")
            }
        }
    }
}

private struct ChatBubbleRow: View {
    let message: DemoPost
    let onInspect: () -> Void
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if message.isUser { Spacer(minLength: 42) }
            if !message.isUser {
                Image(systemName: "sparkles")
                    .foregroundColor(Theme.accent)
                    .frame(width: 24)
            }
            VStack(alignment: .leading, spacing: 10) {
                if !message.isUser {
                    Text("Hanlin AI").font(.caption.weight(.bold))
                }
                Text(message.text)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if !message.isUser { assistantActions }
            }
            .padding(message.isUser ? 13 : 0)
            .background(message.isUser ? Theme.accent.opacity(0.10) : Color.clear, in: RoundedRectangle(cornerRadius: 16))
            if !message.isUser { Spacer(minLength: 8) }
        }
    }
    
    private var assistantActions: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(action: onInspect) {
                Label("Thinking · Tools · Evidence", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .padding(9)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            Button {
                UIPasteboard.general.string = message.text
            } label: {
                Label("העתק תשובה", systemImage: "doc.on.doc").font(.caption)
            }
        }
    }
}

private struct ChatComposerView: View {
    @Binding var draft: String
    @Binding var searchOn: Bool
    @Binding var knowledgeOn: Bool
    @Binding var toolsOn: Bool
    @Binding var thinkingOn: Bool
    let onMiniApps: () -> Void
    let onSend: () -> Void
    @State private var microphonePreview = false
    @State private var attachmentPreview = false
    @State private var chosenModel = "מודל נבחר"
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            inputRow
            statusRow
            if microphonePreview || attachmentPreview {
                Text(microphonePreview ? "מיקרופון: הדמיה בלבד" : "קובץ: הדמיה בלבד")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: 820)
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
    }
    
    private var inputRow: some View {
        HStack(spacing: 12) {
            Menu { composerOptions } label: {
                Image(systemName: "plus.circle").font(.title2)
            }
            TextField("שאל את Hanlin...", text: $draft, axis: .vertical)
                .lineLimit(1...4)
                .submitLabel(.send)
                .onSubmit(onSend)
                .accessibilityIdentifier("chat-input")
            Button {
                microphonePreview.toggle()
            } label: {
                Image(systemName: microphonePreview ? "mic.fill" : "mic")
            }
            .accessibilityLabel("הדמיית מיקרופון")
            Button(action: onSend) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 29))
                    .foregroundColor(draft.isEmpty ? .gray : Theme.accent)
            }
            .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityLabel("שלח הודעה")
            .accessibilityIdentifier("chat-send")
        }
        .padding(12)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 21))
    }
    
    @ViewBuilder
    private var composerOptions: some View {
        Button { attachmentPreview.toggle() } label: {
            Label("צרף קובץ / תמונה (דמו)", systemImage: "paperclip")
        }
        Button(action: onMiniApps) {
            Label("Hanlin MiniApps", systemImage: "square.grid.2x2")
        }
        Divider()
        Toggle("חיפוש", isOn: $searchOn)
        Toggle("ידע", isOn: $knowledgeOn)
        Toggle("כלים", isOn: $toolsOn)
        Toggle("חשיבה", isOn: $thinkingOn)
    }
    
    private var statusRow: some View {
        HStack(spacing: 11) {
            status("חיפוש", enabled: searchOn)
            status("ידע", enabled: knowledgeOn)
            status("כלים", enabled: toolsOn)
            status("חשיבה", enabled: thinkingOn)
            Spacer(minLength: 0)
            modelMenu
        }
        .font(.caption2)
    }
    
    private var modelMenu: some View {
        Menu {
            Button("מודל נבחר") { chosenModel = "מודל נבחר" }
            Button("מודל מקוון (דמו)") { chosenModel = "מודל מקוון" }
            Button("מודל מקומי (דמו)") { chosenModel = "מודל מקומי" }
        } label: {
            Label(chosenModel, systemImage: "cpu")
                .lineLimit(1)
        }
        .accessibilityLabel("בחירת מודל")
    }
    
    private func status(_ title: String, enabled: Bool) -> some View {
        Label(title, systemImage: enabled ? "checkmark.circle.fill" : "circle")
            .foregroundColor(enabled ? Theme.accent : .secondary)
    }
}

private struct AgentActivityView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                Section("AgentRun · פעילות סוכן") {
                    Label("Thinking", systemImage: "brain")
                    Label("Tools / MCP / Skills", systemImage: "hammer")
                    Label("Evidence ומקורות", systemImage: "text.book.closed")
                    Label("תוצאות אינטראקטיביות", systemImage: "rectangle.stack")
                }
                Section {
                    Text("בתוצר המלא משתמשים ב־AgentRun וב־ChatBubbleView הקיימים. כאן רק רואים את מיקום הפעילות בתוך השיחה.")
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("פעילות הסוכן")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("סגור") { dismiss() }
                }
            }
        }
    }
}

private struct QuickActionView: View {
    @Environment(\.dismiss) private var dismiss
    let action: QuickAction
    @State private var input = ""
    @State private var showResult = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section("טקסט") {
                    TextField("הקלד טקסט", text: $input, axis: .vertical)
                        .lineLimit(3...6)
                        .accessibilityIdentifier("quick-action-input")
                }
                Section {
                    Button("הצג תוצאה לדוגמה") { showResult = true }
                        .accessibilityIdentifier("quick-action-run")
                }
                if showResult {
                    Section("דוגמה") {
                        Text("פעולת \(action.rawValue) קיימת בממשק Hanlin. השירות עצמו אינו מחובר לדוגמה זו.")
                            .accessibilityIdentifier("quick-action-result")
                    }
                }
            }
            .navigationTitle(action.rawValue)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("סגור") { dismiss() }
                        .accessibilityIdentifier("quick-action-close")
                }
            }
        }
    }
}

// MARK: Library / original KnowledgeListView, MemoryArchiveView, PromptRepoView

private enum LibraryCategory: String, CaseIterable, Identifiable {
    case knowledge = "ידע"
    case saved = "שמורים"
    case prompts = "פרומפטים"
    case memory = "זיכרון"
    var id: String { rawValue }
}

private struct LibraryDocument: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let symbol: String
}

private struct LibraryScreen: View {
    let onSidebar: () -> Void
    let onBack: () -> Void
    @State private var category: LibraryCategory = .knowledge
    @State private var query = ""
    @State private var newTitle = ""
    @State private var adding = false
    @State private var selected: LibraryDocument?
    @State private var knowledge: [LibraryDocument] = [
        .init(title: "מסמך ידע לדוגמה", subtitle: "KnowledgeRecords / KnowledgeWritingView", symbol: "doc.text"),
        .init(title: "סקירה ומקורות", subtitle: "KnowledgeListView", symbol: "books.vertical")
    ]
    
    private var currentDocs: [LibraryDocument] {
        switch category {
        case .knowledge: return knowledge
        case .saved: return [.init(title: "קטע שמור", subtitle: "שמירת קטע וקפיצה למקור · תכנון", symbol: "bookmark")]
        case .prompts: return [.init(title: "פרומפט למחקר", subtitle: "PromptRepoView", symbol: "tray.full")]
        case .memory: return [.init(title: "Memory Archive", subtitle: "MemoryArchiveView", symbol: "archivebox")]
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            topBar
            Divider()
            filterControls
            documentList
            Button(action: onBack) {
                Label("חזרה לשיחה", systemImage: "bubble.left")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("library-back")
            .padding(14)
        }
        .sheet(item: $selected) { doc in
            LibraryDocumentView(document: doc)
        }
        .alert("מסמך ידע חדש", isPresented: $adding) {
            TextField("שם המסמך", text: $newTitle)
            Button("הוסף") { addDocument() }
            Button("ביטול", role: .cancel) { }
        } message: {
            Text("הפריט יופיע בדוגמה המקומית בלבד.")
        }
    }
    
    private var topBar: some View {
        HStack(spacing: 16) {
            Button(action: onSidebar) { Image(systemName: "sidebar.left") }
            Spacer()
            Text("הספרייה").font(.headline)
                .accessibilityIdentifier("library-title")
            Spacer()
        }
        .font(.title3)
        .padding(18)
        .avoidingWindowControls()
    }
    
    private var filterControls: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                Text("Knowledge & Library").font(.title2.weight(.bold))
                Spacer()
                Button { adding = true } label: {
                    Image(systemName: "document.badge.plus")
                }
            }
            Picker("תוכן הספרייה", selection: $category) {
                ForEach(LibraryCategory.allCases) { item in
                    Text(item.rawValue).tag(item)
                }
            }
            .pickerStyle(.segmented)
            TextField("חפש בספרייה", text: $query)
                .textFieldStyle(.roundedBorder)
        }
        .padding(19)
    }
    
    private var documentList: some View {
        List {
            ForEach(currentDocs.filter { query.isEmpty || $0.title.localizedCaseInsensitiveContains(query) }) { doc in
                Button { selected = doc } label: {
                    Label {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(doc.title).font(.headline)
                            Text(doc.subtitle).font(.caption).foregroundColor(.secondary)
                        }
                    } icon: {
                        Image(systemName: doc.symbol).foregroundColor(Theme.accent)
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
            }
        }
        .listStyle(.plain)
    }
    
    private func addDocument() {
        let value = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        knowledge.insert(.init(title: value, subtitle: "מסמך הדגמה מקומי", symbol: "doc.text"), at: 0)
        category = .knowledge
        newTitle = ""
    }
}

private struct LibraryDocumentView: View {
    @Environment(\.dismiss) private var dismiss
    let document: LibraryDocument
    
    var body: some View {
        NavigationStack {
            List {
                Label(document.title, systemImage: document.symbol)
                Text(document.subtitle)
                Text("זהו מסך דוגמה. באפליקציה המקורית התוכן מנוהל דרך SwiftData.")
                    .foregroundColor(.secondary)
            }
            .navigationTitle(document.title)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("סגור") { dismiss() }
                }
            }
        }
    }
}

// MARK: Settings / real SettingsView destination mapping

private struct SettingDestination: Identifiable {
    let id: String
    let title: String
    let originalView: String
    let icon: String
    
    init(_ id: String, _ title: String, _ originalView: String, _ icon: String) {
        self.id = id
        self.title = title
        self.originalView = originalView
        self.icon = icon
    }
}

private struct SettingCategory: Identifiable {
    let id: String
    let title: String
    let icon: String
    let subtitle: String
    let destinations: [SettingDestination]
}

private enum SettingsData {
    static let personalization = SettingCategory(
        id: "personal", title: "התאמה אישית", icon: "person.crop.circle", subtitle: "פרופיל והעדפות",
        destinations: [
            .init("profile", "פרטי משתמש", "UserInfoView", "person"),
            .init("dictionary", "מילון תרגום", "TranslationDicView", "character.book.closed")
        ]
    )
    
    static let memory = SettingCategory(
        id: "memory", title: "זיכרון וידע", icon: "books.vertical", subtitle: "זיכרון, פרומפטים ו־Canvas",
        destinations: [
            .init("archive", "ארכיון זיכרון", "MemoryArchiveView", "archivebox"),
            .init("prompts", "מאגר פרומפטים", "PromptRepoView", "tray.full"),
            .init("knowledge", "הגדרות ידע", "KnowledgeSettingView", "backpack"),
            .init("canvas", "Canvas", "CanvasSettingView", "pencil")
        ]
    )
    
    static let models = SettingCategory(
        id: "models", title: "מודלים וסוכנים", icon: "cpu", subtitle: "מודלים, ספקים ומפתחות",
        destinations: [
            .init("manageModels", "מודלים וסוכנים", "ModelsView", "square.stack.3d.up"),
            .init("providers", "ספקי מודלים", "APIKeysView", "key.horizontal"),
            .init("embedding", "מודל Embedding", "SelectEmbeddingModelView", "circle.hexagongrid"),
            .init("optimization", "מודלי אופטימיזציה", "SelectOptimizationModelView", "hammer"),
            .init("voice", "מודל דיבור", "SelectTTSModelView", "waveform")
        ]
    )
    
    static let tools = SettingCategory(
        id: "tools", title: "כלים וחיבורים", icon: "wrench.and.screwdriver", subtitle: "MCP, Skills, Runtime וכלי סוכן",
        destinations: [
            .init("mcp", "MCP Servers", "MCPServersSettingsView", "server.rack"),
            .init("skills", "Skill Center", "SkillCenterView", "sparkles"),
            .init("runtime", "Packages & Tools", "RuntimePackagesView", "shippingbox"),
            .init("search", "חיפוש ברשת", "SearchSettingView", "magnifyingglass"),
            .init("maps", "מפות", "MapSettingView", "map"),
            .init("weather", "מזג אוויר", "WeatherSettingView", "cloud.sun"),
            .init("calendar", "יומן ותזכורות", "CalendarSettingView", "calendar"),
            .init("health", "בריאות", "HealthSettingView", "heart"),
            .init("code", "הרצת קוד", "CodeSettingView", "terminal")
        ]
    )
    
    static let general = SettingCategory(
        id: "general", title: "כללי", icon: "gearshape", subtitle: "העדפות מערכת",
        destinations: [.init("generalSettings", "הגדרות כלליות", "GeneralSettingsView", "gearshape")]
    )
    
    static let advanced = SettingCategory(
        id: "advanced", title: "מתקדם ואבחון", icon: "slider.horizontal.3", subtitle: "אבחון Runtime ו־Agent",
        destinations: [
            .init("diagnostics", "Runtime Diagnostics", "RuntimeCenterView", "waveform.path.ecg"),
            .init("agentDiagnostics", "Agent Diagnostics", "AgentDiagnosticsView", "stethoscope")
        ]
    )
    
    static let about = SettingCategory(
        id: "about", title: "עזרה ומידע", icon: "info.circle", subtitle: "גרסה, עדכונים ותמיכה",
        destinations: [
            .init("aboutApp", "על Hanlin", "SoftwareIntroView", "doc.text"),
            .init("updates", "מה חדש", "UpdateNotesView", "newspaper"),
            .init("version", "פרטי גרסה", "VersionInfoView", "number"),
            .init("contact", "צור קשר", "ContactUsView", "envelope")
        ]
    )
}

private struct SettingsHomeView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showMiniApps = false
    
    var body: some View {
        NavigationStack {
            List {
                Section("Customize Hanlin") {
                    categoryLink(SettingsData.personalization)
                    categoryLink(SettingsData.memory)
                }
                Section("סוכן AI") {
                    categoryLink(SettingsData.models)
                    categoryLink(SettingsData.tools)
                }
                Section("מערכת") {
                    categoryLink(SettingsData.general)
                    categoryLink(SettingsData.advanced)
                    categoryLink(SettingsData.about)
                }
                Section("אפליקציה נפרדת") {
                    Button { showMiniApps = true } label: {
                        Label("Hanlin MiniApps — תצוגת האפליקציה הנפרדת", systemImage: "square.grid.2x2")
                    }
                }
            }
            .navigationTitle("הגדרות Hanlin")
            .toolbar { closeButton }
        }
        .fullScreenCover(isPresented: $showMiniApps) {
            MiniAppsPreviewView()
        }
    }
    
    private func categoryLink(_ category: SettingCategory) -> some View {
        NavigationLink {
            SettingsCategoryView(category: category, onClose: { dismiss() })
        } label: {
            Label {
                VStack(alignment: .leading, spacing: 4) {
                    Text(category.title)
                    Text(category.subtitle).font(.caption).foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            } icon: {
                Image(systemName: category.icon).foregroundColor(Theme.accent)
            }
        }
        .accessibilityIdentifier("settings-category-\(category.id)")
    }
    
    private var closeButton: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark").font(.headline)
            }
            .accessibilityLabel("סגור הגדרות")
            .accessibilityIdentifier("settings-close")
        }
    }
}

private struct SettingsCategoryView: View {
    let category: SettingCategory
    let onClose: () -> Void
    
    var body: some View {
        List {
            Section(category.subtitle) {
                ForEach(category.destinations) { destination in
                    NavigationLink {
                        SettingsDetailView(destination: destination, onClose: onClose)
                    } label: {
                        Label(destination.title, systemImage: destination.icon)
                            .padding(.vertical, 5)
                    }
                    .accessibilityIdentifier("settings-destination-\(destination.id)")
                }
            }
        }
        .navigationTitle(category.title)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: onClose) { Image(systemName: "xmark") }
                    .accessibilityLabel("סגור הגדרות")
                    .accessibilityIdentifier("settings-close")
            }
        }
    }
}

private struct SettingsDetailView: View {
    let destination: SettingDestination
    let onClose: () -> Void
    @State private var exampleEnabled = true
    @State private var modelKind = "מודלים"
    @State private var showingInfo = false
    
    var body: some View {
        Form {
            sourceSection
            exampleSection
            Section("מידע על הדוגמה") {
                Text("שם המסך והרכיב נלקחו מ־SettingsView של Hanlin. הגדרות אמיתיות יפעלו רק בתוך האפליקציה המקורית.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle(destination.title)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: onClose) { Image(systemName: "xmark") }
                    .accessibilityLabel("סגור הגדרות")
                    .accessibilityIdentifier("settings-close")
            }
        }
        .alert("הדגמה בלבד", isPresented: $showingInfo) {
            Button("אישור", role: .cancel) { }
        } message: {
            Text("הפעולה הזו דורשת את המנוע והנתונים של Hanlin המקורי.")
        }
    }
    
    private var sourceSection: some View {
        Section("מסך המקור הקיים") {
            Label(destination.originalView, systemImage: destination.icon)
                .font(.system(.subheadline, design: .monospaced))
        }
    }
    
    @ViewBuilder
    private var exampleSection: some View {
        if destination.id == "manageModels" {
            Section("ModelsView") {
                Picker("סוג", selection: $modelKind) {
                    Text("מודלים").tag("מודלים")
                    Text("סוכנים").tag("סוכנים")
                }
                .pickerStyle(.segmented)
                Button("הוסף מודל מקוון") { showingInfo = true }
                Button("הוסף מודל מקומי") { showingInfo = true }
                Button("הוסף סוכן") { showingInfo = true }
            }
        } else {
            Section("אפשרויות") {
                Toggle("פעיל בדוגמה", isOn: $exampleEnabled)
                    .accessibilityIdentifier("settings-example-toggle")
                Button("אפשרויות מתקדמות") { showingInfo = true }
            }
        }
    }
}

// MARK: Companion app / original NativeAppsHubView engine taxonomy

private struct MiniAppExample: Identifiable {
    let id: String
    let title: String
    let engine: String
    let icon: String
    let subtitle: String
}

private struct MiniAppsPreviewView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var selected: MiniAppExample?
    @State private var showImport = false
    
    private let examples: [MiniAppExample] = [
        .init(id: "torah", title: "לימוד מצילום", engine: "Swift", icon: "camera.viewfinder", subtitle: "NativeAppsHubView"),
        .init(id: "script", title: "ScriptUI", engine: "ScriptUI", icon: "curlybraces", subtitle: "חבילות סקריפטים"),
        .init(id: "native", title: "NativeScript", engine: "NativeScript", icon: "square.stack.3d.up", subtitle: "אפליקציות NativeScript"),
        .init(id: "expo", title: "Expo", engine: "Expo", icon: "apps.iphone", subtitle: "אפליקציות Expo")
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    intro
                    searchField
                    ForEach(["Swift", "ScriptUI", "NativeScript", "Expo"], id: \.self) { engine in
                        engineSection(engine)
                    }
                }
                .padding(24)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("MiniApps")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showImport = true } label: { Image(systemName: "plus") }
                        .accessibilityLabel("ייבוא מיני־אפליקציה")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { dismiss() }) { Image(systemName: "xmark") }
                        .accessibilityLabel("סגור")
                }
            }
        }
        .sheet(item: $selected) { app in
            MiniAppDetailView(app: app)
        }
        .alert("הדמיית התקנה", isPresented: $showImport) {
            Button("אישור", role: .cancel) { }
        } message: {
            Text("להתקנה אמיתית נדרש Runtime מקורי. כאן זו דוגמת ניווט בלבד.")
        }
    }
    
    private var intro: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Hanlin MiniApps").font(.largeTitle.weight(.bold))
            Text("האפליקציה הנפרדת — גלריה, התקנה, ניהול והפעלה.")
                .foregroundColor(.secondary)
            Text("Swift · ScriptUI · NativeScript · Expo")
                .font(.caption)
                .foregroundColor(Theme.accent)
        }
    }
    
    private var searchField: some View {
        TextField("Search Apps", text: $query)
            .textFieldStyle(.roundedBorder)
    }
    
    private func engineSection(_ engine: String) -> some View {
        let matching = examples.filter {
            $0.engine == engine && (query.isEmpty || $0.title.localizedCaseInsensitiveContains(query))
        }
        return VStack(alignment: .leading, spacing: 12) {
            if !matching.isEmpty {
                Text(engine).font(.title2.weight(.bold))
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 12)]) {
                    ForEach(matching) { app in
                        MiniAppPreviewCard(app: app, onOpen: { selected = app })
                    }
                }
            }
        }
    }
}

private struct MiniAppPreviewCard: View {
    let app: MiniAppExample
    let onOpen: () -> Void
    
    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: app.icon)
                    .font(.title)
                    .foregroundColor(Theme.accent)
                Text(app.title).font(.headline).foregroundColor(.primary)
                Text(app.subtitle).font(.caption).foregroundColor(.secondary)
                Label("פתח פרטים", systemImage: "arrow.up.right")
                    .font(.caption)
                    .foregroundColor(Theme.accent)
            }
            .frame(maxWidth: .infinity, minHeight: 118, alignment: .leading)
            .padding(16)
            .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 15))
        }
        .buttonStyle(.plain)
    }
}

private struct MiniAppDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let app: MiniAppExample
    
    var body: some View {
        NavigationStack {
            List {
                Label(app.title, systemImage: app.icon)
                Text("Runtime: \(app.engine)")
                Text(app.subtitle)
                Text("המסך המקורי נמצא ב־NativeAppsHubView. זו דוגמת מיקום בלבד.")
                    .foregroundColor(.secondary)
            }
            .navigationTitle(app.title)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("סגור") { dismiss() }
                }
            }
        }
    }
}
