//  ClipCheck.swift
//  ClipCheck — Restaurant Safety Score via App Clip
//
//  Hack Canada 2026 Submission

import SwiftUI

// MARK: - Shared Formatters

private let monthYearFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "MMM yyyy"
    return f
}()

private let fullDateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateStyle = .long
    return f
}()

// MARK: - Design System

private struct CardStyle: ViewModifier {
    var cornerRadius: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(.regularMaterial)
                    .shadow(color: .black.opacity(0.05), radius: 10, y: 3)
            }
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5)
            )
    }
}

private extension View {
    func cardStyle(cornerRadius: CGFloat = 16) -> some View {
        modifier(CardStyle(cornerRadius: cornerRadius))
    }
}

// MARK: - ClipCheck Experience

struct ClipCheck: ClipExperience {
    static let urlPattern = "example.com/restaurant/:restaurantId/check"
    static let clipName = "ClipCheck"
    static let clipDescription = "Scan to see any restaurant's health inspection score instantly."
    static let teamName = "ClipCheck"
    static let touchpoint: JourneyTouchpoint = .onSite
    static let invocationSource: InvocationSource = .qrCode

    let context: ClipContext
    @State private var activeRestaurantId: String?
    @State private var showingDetail = false
    @State private var gaugeAnimated = false
    @State private var expandedViolations: Set<UUID> = []
    @State private var selectedInspectionId: UUID?
    @State private var gemini = GeminiService()
    @State private var tts = ElevenLabsService()
    @State private var contentAppeared = false
    @State private var showingScanner = false
    @State private var showingQRGenerator = false
    @State private var manualURL = ""
    @State private var dietaryProfile = DietaryProfile()
    @State private var showingDietarySelector = false
    @State private var pendingRestaurantId: String?
    @State private var menuService = MenuAnalysisService()
    @State private var weatherService = WeatherService()

    private var restaurantId: String {
        activeRestaurantId ?? context.pathParameters["restaurantId"] ?? ""
    }

    private var restaurant: RestaurantData? {
        RestaurantDataStore.shared.lookup(restaurantId)
    }

    /// Start on detail if the URL already contains a valid restaurant
    private var initiallyHasRestaurant: Bool {
        let urlId = context.pathParameters["restaurantId"] ?? ""
        return urlId != "scan" && RestaurantDataStore.shared.lookup(urlId) != nil
    }

    var body: some View {
        ZStack {
            backgroundGradient

            if showingDetail, let restaurant {
                detailView(restaurant)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)
                    ))
            } else {
                landingView
                    .transition(.opacity)
            }
        }
        .animation(.spring(duration: 0.4), value: showingDetail)
        .fullScreenCover(isPresented: $showingScanner) {
            QRScannerView { scannedValue in
                showingScanner = false
                handleScannedURL(scannedValue)
            } onCancel: {
                showingScanner = false
            }
        }
        .sheet(isPresented: $showingQRGenerator) {
            QRGeneratorView()
        }
        .sheet(isPresented: $showingDietarySelector) {
            DietarySelectorSheet(profile: $dietaryProfile) {
                showingDietarySelector = false
                if let id = pendingRestaurantId {
                    pendingRestaurantId = nil
                    finishNavigation(id)
                }
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
            .interactiveDismissDisabled()
        }
        .onAppear {
            if initiallyHasRestaurant {
                // Check for dietary params in the invocation URL
                if let urlDietary = DietaryProfile.fromQuery(context.queryParameters) {
                    dietaryProfile = urlDietary
                    showingDetail = true
                    loadRestaurant()
                    withAnimation(.easeOut(duration: 0.4)) {
                        contentAppeared = true
                    }
                } else {
                    // Show dietary selector before detail
                    let urlId = context.pathParameters["restaurantId"] ?? ""
                    pendingRestaurantId = urlId
                    showingDietarySelector = true
                }
            }
        }
    }

    // MARK: - Landing View

    private var landingView: some View {
        ScrollView {
            VStack(spacing: 28) {
                Spacer().frame(height: 32)

                // Hero section
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(.blue.opacity(0.08))
                            .frame(width: 88, height: 88)
                        Image(systemName: "qrcode.viewfinder")
                            .font(.system(size: 40, weight: .light))
                            .foregroundStyle(.blue)
                    }

                    Text("ClipCheck")
                        .font(.system(size: 32, weight: .bold, design: .rounded))

                    Text("Instant restaurant safety scores")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(.secondary)
                }
                .onLongPressGesture {
                    showingQRGenerator = true
                }

                // Scan button
                #if !targetEnvironment(simulator)
                Button {
                    showingScanner = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 17, weight: .medium))
                        Text("Scan QR Code")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(.blue.gradient, in: RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 24)
                #endif

                // Manual entry
                VStack(alignment: .leading, spacing: 6) {
                    Text("ENTER URL")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .tracking(0.8)
                        .padding(.horizontal, 4)

                    HStack(spacing: 10) {
                        TextField("example.com/restaurant/.../check", text: $manualURL)
                            .font(.system(size: 14, design: .monospaced))
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 12))

                        Button {
                            handleScannedURL(manualURL)
                        } label: {
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.system(size: 30))
                                .foregroundStyle(.blue)
                        }
                        .disabled(manualURL.isEmpty)
                        .opacity(manualURL.isEmpty ? 0.4 : 1)
                    }
                }
                .padding(.horizontal, 24)

                // Demo restaurants
                VStack(alignment: .leading, spacing: 10) {
                    Text("DEMO RESTAURANTS")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .tracking(0.8)
                        .padding(.horizontal, 4)

                    ForEach(demoRestaurants) { restaurant in
                        Button {
                            navigateToRestaurant(restaurant.id)
                        } label: {
                            demoCard(restaurant)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 24)

                // Dev hint
                Text("Long-press title for QR generator")
                    .font(.system(size: 11))
                    .foregroundStyle(.quaternary)
                    .padding(.top, 4)

                Spacer().frame(height: 32)
            }
        }
        .scrollIndicators(.hidden)
    }

    // MARK: Demo Data

    private var demoRestaurants: [RestaurantData] {
        let all = RestaurantDataStore.shared.allRestaurants
        var picks: [RestaurantData] = []
        // One danger, one caution, one safe — to show the full range
        if let danger = all.first(where: { $0.trustLevel == .danger }) { picks.append(danger) }
        if let caution = all.first(where: { $0.trustLevel == .caution }) { picks.append(caution) }
        if let safe = all.first(where: { $0.trustLevel == .safe }) { picks.append(safe) }
        return picks
    }

    private func demoCard(_ restaurant: RestaurantData) -> some View {
        HStack(spacing: 14) {
            MiniTrustGauge(score: restaurant.trustScore, level: restaurant.trustLevel)
                .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 4) {
                Text(restaurant.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)

                HStack(spacing: 6) {
                    Text(restaurant.trustLevel.label)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(restaurant.trustLevel.color)
                    Text("\u{2022}")
                        .font(.system(size: 8))
                        .foregroundStyle(.quaternary)
                    Text("\(restaurant.trustScore)/100")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.quaternary)
        }
        .padding(16)
        .cardStyle()
    }

    // MARK: - Detail View

    private func detailView(_ restaurant: RestaurantData) -> some View {
        ScrollViewReader { scrollProxy in
            ScrollView {
                let selectedInspection = restaurant.inspections.first { $0.id == selectedInspectionId }
                    ?? restaurant.inspections.first

                VStack(spacing: 20) {
                    // Back button
                    HStack {
                        Button {
                            goBackToLanding()
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 12, weight: .semibold))
                                Text("Back")
                                    .font(.system(size: 14, weight: .medium))
                            }
                            .foregroundStyle(.blue)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.blue.opacity(0.08), in: Capsule())
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                    restaurantHeader(restaurant)
                        .id("top")

                    if !dietaryProfile.isEmpty {
                        DietaryBadge(profile: dietaryProfile)
                            .padding(.horizontal, 20)
                    }

                    TrustScoreGauge(
                        score: restaurant.trustScore,
                        level: restaurant.trustLevel,
                        animated: gaugeAnimated
                    )
                    .frame(height: 250)
                    .padding(.horizontal, 16)

                    if !restaurant.inspections.isEmpty {
                        InspectionTimelineView(
                            inspections: restaurant.inspections,
                            selectedId: $selectedInspectionId
                        )
                        .padding(.horizontal, 20)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }

                    if let inspection = selectedInspection, !inspection.infractions.isEmpty {
                        violationsSection(inspection)
                            .id(inspection.id)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                            .padding(.horizontal, 20)
                    }

                    AIAdvisorCard(gemini: gemini)
                        .padding(.horizontal, 20)
                        .animation(.easeOut(duration: 0.4), value: gemini.isLoading)

                    PersonalizedRecsCard(
                        gemini: gemini,
                        weather: weatherService,
                        dietary: dietaryProfile
                    )
                    .padding(.horizontal, 20)
                    .animation(.easeOut(duration: 0.4), value: gemini.isLoading)

                    VoiceBriefingButton(
                        gemini: gemini,
                        tts: tts,
                        menuService: menuService,
                        weather: weatherService
                    )
                    .padding(.horizontal, 20)

                    MenuRecommendationCard(service: menuService, dietary: dietaryProfile)
                        .padding(.horizontal, 20)
                        .animation(.easeOut(duration: 0.4), value: menuService.isLoading)

                    if restaurant.trustScore < 70 {
                        NearbyAlternativesSection(
                            currentId: restaurant.id
                        ) { newId in
                            switchToRestaurant(newId, scrollProxy: scrollProxy)
                        }
                        .padding(.horizontal, 20)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }

                    Spacer().frame(height: 24)
                }
                .animation(.spring(duration: 0.35), value: selectedInspectionId)
                .opacity(contentAppeared ? 1 : 0)
                .offset(y: contentAppeared ? 0 : 12)
            }
            .scrollIndicators(.hidden)
        }
    }

    // MARK: Background

    private var backgroundGradient: some View {
        Color(.systemBackground)
            .overlay(alignment: .top) {
                if let restaurant, showingDetail {
                    EllipticalGradient(
                        colors: [
                            restaurant.trustLevel.color.opacity(0.08),
                            restaurant.trustLevel.color.opacity(0.02),
                            .clear
                        ],
                        center: .top,
                        startRadiusFraction: 0,
                        endRadiusFraction: 0.7
                    )
                    .frame(height: 400)
                } else {
                    EllipticalGradient(
                        colors: [
                            Color.blue.opacity(0.04),
                            .clear
                        ],
                        center: .top,
                        startRadiusFraction: 0,
                        endRadiusFraction: 0.6
                    )
                    .frame(height: 300)
                }
            }
            .ignoresSafeArea()
    }

    // MARK: URL Parsing

    private func handleScannedURL(_ raw: String) {
        // Extract restaurantId from URL like "example.com/restaurant/{id}/check"
        var normalized = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if !normalized.contains("://") {
            normalized = "https://\(normalized)"
        }
        guard let url = URL(string: normalized) else { return }

        // Parse dietary params from URL if present
        var queryParams: [String: String] = [:]
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let items = components.queryItems {
            for item in items {
                queryParams[item.name] = item.value ?? ""
            }
        }
        let urlDietary = DietaryProfile.fromQuery(queryParams)

        let segments = url.pathComponents.filter { $0 != "/" && !$0.isEmpty }
        // Pattern: /restaurant/:restaurantId/check → segments = ["restaurant", "{id}", "check"]
        if segments.count >= 3,
           segments[0].lowercased() == "restaurant",
           segments[2].lowercased() == "check" {
            let id = segments[1]
            navigateToRestaurant(id, urlDietary: urlDietary)
        } else if segments.count == 1 {
            navigateToRestaurant(segments[0], urlDietary: urlDietary)
        }
    }

    private func navigateToRestaurant(_ id: String, urlDietary: DietaryProfile? = nil) {
        if let profile = urlDietary {
            // URL carried dietary info — skip selector
            dietaryProfile = profile
            finishNavigation(id)
        } else {
            // Show dietary selector first
            pendingRestaurantId = id
            showingDietarySelector = true
        }
    }

    private func finishNavigation(_ id: String) {
        // Reset all state BEFORE showing detail to avoid stale UI flashes
        activeRestaurantId = id
        gaugeAnimated = false
        expandedViolations = []
        selectedInspectionId = nil
        contentAppeared = false
        gemini = GeminiService()
        menuService = MenuAnalysisService()

        showingDetail = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            loadRestaurant()
            withAnimation(.easeOut(duration: 0.4)) {
                contentAppeared = true
            }
        }
    }

    private func goBackToLanding() {
        tts.stop()
        withAnimation(.easeOut(duration: 0.2)) {
            contentAppeared = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            showingDetail = false
        }
    }

    // MARK: Load / Switch

    private var personalizationContext: PersonalizationContext {
        PersonalizationContext(
            weather: weatherService.weather,
            dietary: dietaryProfile
        )
    }

    private func loadRestaurant() {
        if let first = restaurant?.inspections.first {
            selectedInspectionId = first.id
        }
        withAnimation(.easeOut(duration: 1.5).delay(0.3)) {
            gaugeAnimated = true
        }
        // Fetch weather if not already loaded
        weatherService.fetch()

        if let restaurant {
            let ctx = personalizationContext
            gemini.analyze(restaurant, dietary: dietaryProfile, personalization: ctx)
            // Stagger menu analysis to avoid Gemini rate limits
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                let freshCtx = personalizationContext // may have weather by now
                menuService.analyze(restaurant: restaurant, dietary: dietaryProfile, personalization: freshCtx)
            }
        }
    }

    private func switchToRestaurant(_ id: String, scrollProxy: ScrollViewProxy) {
        tts.stop()
        withAnimation(.easeOut(duration: 0.2)) {
            contentAppeared = false
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            activeRestaurantId = id
            gaugeAnimated = false
            expandedViolations = []
            selectedInspectionId = nil
            gemini = GeminiService()
            menuService = MenuAnalysisService()
            // Keep dietary profile — it persists across restaurant switches

            scrollProxy.scrollTo("top", anchor: .top)

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                loadRestaurant()
                withAnimation(.easeOut(duration: 0.4)) {
                    contentAppeared = true
                }
            }
        }
    }

    // MARK: Not Found

    private var notFoundView: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 80)
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            Text("Restaurant Not Found")
                .font(.system(size: 20, weight: .semibold))
            Text("No inspection data available for this restaurant.")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }

    // MARK: Restaurant Header

    private func restaurantHeader(_ restaurant: RestaurantData) -> some View {
        VStack(spacing: 8) {
            Text(restaurant.name)
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(.primary)

            Text(restaurant.address)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                if !restaurant.type.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "fork.knife")
                            .font(.system(size: 10))
                        Text(restaurant.type)
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(.secondary)
                }
                if !restaurant.inspections.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.system(size: 10))
                        Text(restaurant.lastInspectedLabel)
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(.secondary)
                }
            }
            .padding(.top, 2)
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 24)
    }

    // MARK: Violations Section

    @ViewBuilder
    private func violationsSection(_ inspection: Inspection) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(cautionColor)
                Text("Violations")
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                Text(monthYearFormatter.string(from: inspection.parsedDate))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 4)

            ForEach(inspection.infractions) { infraction in
                ViolationCard(
                    infraction: infraction,
                    isExpanded: expandedViolations.contains(infraction.id)
                ) {
                    withAnimation(.spring(duration: 0.3)) {
                        if expandedViolations.contains(infraction.id) {
                            expandedViolations.remove(infraction.id)
                        } else {
                            expandedViolations.insert(infraction.id)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Trust Score Gauge

private struct TrustScoreGauge: View {
    let score: Int
    let level: TrustLevel
    let animated: Bool

    @State private var showPulse = false

    private var progress: Double {
        animated ? Double(score) / 100.0 : 0
    }

    private var spectrumGradient: AngularGradient {
        AngularGradient(
            gradient: Gradient(stops: [
                .init(color: dangerColor, location: 0.0),
                .init(color: dangerColor, location: 0.15),
                .init(color: cautionColor, location: 0.30),
                .init(color: cautionColor, location: 0.413),
                .init(color: safeColor, location: 0.525),
                .init(color: safeColor, location: 0.75),
            ]),
            center: .center
        )
    }

    private let trackStroke = StrokeStyle(lineWidth: 10, lineCap: .round)
    private let arcStroke = StrokeStyle(lineWidth: 12, lineCap: .round)

    var body: some View {
        ZStack {
            // Background track
            Circle()
                .trim(from: 0, to: 0.75)
                .stroke(Color(.quaternarySystemFill), style: trackStroke)
                .rotationEffect(.degrees(135))

            // Soft glow behind arc
            Circle()
                .trim(from: 0, to: progress * 0.75)
                .stroke(level.color.opacity(0.25), style: StrokeStyle(lineWidth: 18, lineCap: .round))
                .rotationEffect(.degrees(135))
                .blur(radius: 10)

            // Active arc
            Circle()
                .trim(from: 0, to: progress * 0.75)
                .stroke(spectrumGradient, style: arcStroke)
                .rotationEffect(.degrees(135))

            // Endpoint dot
            if animated && score > 0 {
                endpointDot
            }

            // Center content
            VStack(spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(animated ? score : 0)")
                        .font(.system(size: 54, weight: .bold, design: .rounded))
                        .foregroundStyle(level.color)
                        .contentTransition(.numericText(value: Double(animated ? score : 0)))

                    Text("/100")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(.quaternary)
                        .padding(.bottom, 4)
                }
                .scaleEffect(showPulse ? 1.05 : 1.0)

                Text(statusLabel)
                    .font(.system(size: 12, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(level.color)
                    .scaleEffect(showPulse ? 1.03 : 1.0)
            }
        }
        .padding(20)
        .task {
            // Pulse after gauge fill animation completes (0.3s delay + 1.5s fill)
            try? await Task.sleep(for: .seconds(2.0))
            withAnimation(.easeInOut(duration: 0.35)) {
                showPulse = true
            }
            try? await Task.sleep(for: .seconds(0.35))
            withAnimation(.easeInOut(duration: 0.25)) {
                showPulse = false
            }
        }
    }

    private var statusLabel: String {
        switch level {
        case .safe: return "SAFE TO EAT"
        case .caution: return "CAUTION"
        case .danger: return "AVOID"
        }
    }

    // Bright dot at the end of the arc for emphasis
    private var endpointDot: some View {
        let angle = Angle.degrees(135 + progress * 270)

        return GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let r = size / 2 - 7 // inset by half stroke
            let x = geo.size.width / 2 + r * CGFloat(cos(angle.radians - .pi / 2))
            let y = geo.size.height / 2 + r * CGFloat(sin(angle.radians - .pi / 2))

            Circle()
                .fill(.white)
                .frame(width: 6, height: 6)
                .shadow(color: level.color, radius: 4)
                .position(x: x, y: y)
        }
    }
}

// MARK: - Inspection Timeline

private struct InspectionTimelineView: View {
    let inspections: [Inspection]
    @Binding var selectedId: UUID?

    private var chronological: [Inspection] {
        inspections.reversed()
    }

    private var mostRecentId: UUID? {
        inspections.first?.id
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 13))
                    .foregroundStyle(.blue)
                Text("Inspection History")
                    .font(.system(size: 16, weight: .semibold))
            }
            .padding(.horizontal, 4)

            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 0) {
                        ForEach(Array(chronological.enumerated()), id: \.element.id) { index, inspection in
                            if index > 0 {
                                connectorLine(
                                    from: chronological[index - 1].parsedStatus,
                                    to: inspection.parsedStatus
                                )
                            }

                            timelineDot(inspection)
                                .id(inspection.id)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
                .cardStyle()
                .onAppear {
                    if let id = mostRecentId {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation { proxy.scrollTo(id, anchor: .trailing) }
                        }
                    }
                }
            }

            // Detail card for selected inspection
            if let selected = inspections.first(where: { $0.id == selectedId }) {
                inspectionDetailCard(selected)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.95)),
                        removal: .opacity
                    ))
            }
        }
    }

    // MARK: Timeline Dot

    private func timelineDot(_ inspection: Inspection) -> some View {
        let isSelected = inspection.id == selectedId
        let isMostRecent = inspection.id == mostRecentId
        let status = inspection.parsedStatus

        return Button {
            selectedId = inspection.id
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    // Radar-ping pulse on most recent (when not selected)
                    if isMostRecent && !isSelected {
                        PulseRing(color: status.color)
                    }

                    // Selection glow ring
                    if isSelected {
                        Circle()
                            .fill(status.color.opacity(0.12))
                            .frame(width: 46, height: 46)

                        Circle()
                            .stroke(status.color.opacity(0.4), lineWidth: 2)
                            .frame(width: 46, height: 46)
                    }

                    // Main dot
                    Circle()
                        .fill(status.color)
                        .frame(
                            width: isMostRecent ? 32 : 26,
                            height: isMostRecent ? 32 : 26
                        )
                        .overlay {
                            Image(systemName: status.icon)
                                .font(.system(
                                    size: isMostRecent ? 15 : 12,
                                    weight: .bold
                                ))
                                .foregroundStyle(.white)
                        }
                        .shadow(
                            color: status.color.opacity(isSelected ? 0.5 : 0.2),
                            radius: isSelected ? 8 : 3
                        )
                        .scaleEffect(isSelected ? 1.1 : 1.0)
                }
                .frame(width: 50, height: 50) // Fixed hit area

                // Date label
                Text(monthYearFormatter.string(from: inspection.parsedDate))
                    .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? .primary : .secondary)

                // Status label
                Text(status.label)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(status.color)
                    .opacity(isSelected ? 1.0 : 0.6)
            }
            .animation(.spring(duration: 0.3), value: isSelected)
        }
        .buttonStyle(.plain)
    }

    // MARK: Connector Line

    private func connectorLine(from: InspectionStatus, to: InspectionStatus) -> some View {
        RoundedRectangle(cornerRadius: 1)
            .fill(
                LinearGradient(
                    colors: [from.color.opacity(0.35), to.color.opacity(0.35)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: 28, height: 2.5)
            .padding(.bottom, 36) // Align with dot centers
    }

    // MARK: Detail Card

    private func inspectionDetailCard(_ inspection: Inspection) -> some View {
        let status = inspection.parsedStatus

        return HStack(spacing: 12) {
            Circle()
                .fill(status.color)
                .frame(width: 32, height: 32)
                .overlay {
                    Image(systemName: status.icon)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(status.label)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(status.color)

                Text(fullDateFormatter.string(from: inspection.parsedDate))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if inspection.infractions.isEmpty {
                Label("Clean", systemImage: "checkmark")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(safeColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(safeColor.opacity(0.1), in: Capsule())
            } else {
                let count = inspection.infractions.count
                Label(
                    "\(count) violation\(count == 1 ? "" : "s")",
                    systemImage: "exclamationmark.triangle.fill"
                )
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(status.color)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(status.color.opacity(0.1), in: Capsule())
            }
        }
        .padding(12)
        .cardStyle(cornerRadius: 14)
    }
}

// MARK: - Pulse Ring Animation

private struct PulseRing: View {
    let color: Color
    @State private var animating = false

    var body: some View {
        Circle()
            .stroke(color.opacity(0.5), lineWidth: 2)
            .frame(width: 32, height: 32)
            .scaleEffect(animating ? 1.8 : 1.0)
            .opacity(animating ? 0 : 0.6)
            .onAppear {
                withAnimation(.easeOut(duration: 1.6).repeatForever(autoreverses: false)) {
                    animating = true
                }
            }
    }
}

// MARK: - Violation Card

private struct ViolationCard: View {
    let infraction: Infraction
    let isExpanded: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(infraction.parsedSeverity.label.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .tracking(0.5)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(infraction.parsedSeverity.color, in: Capsule())

                    if !infraction.action.isEmpty {
                        Text(infraction.action)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.tertiary)
                    }

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }

                if isExpanded {
                    Text(infraction.detail)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardStyle(cornerRadius: 12)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - AI Advisor Card

private struct AIAdvisorCard: View {
    let gemini: GeminiService

    /// Whether analysis has been initiated (loading started or result available).
    /// The card should not render at all until this is true.
    private var hasContent: Bool {
        gemini.isLoading || gemini.result != nil
    }

    private var riskColor: Color {
        switch gemini.result?.riskLevel {
        case "LOW": return safeColor
        case "HIGH": return dangerColor
        default: return cautionColor
        }
    }

    var body: some View {
        // Don't render anything until analysis has actually started
        if hasContent {
            VStack(alignment: .leading, spacing: 10) {
                // Header
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 14))
                        .foregroundStyle(.purple)
                    Text("AI Safety Advisor")
                        .font(.system(size: 16, weight: .semibold))
                    Spacer()
                    Text("Gemini")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(.purple.opacity(0.5))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.purple.opacity(0.06), in: Capsule())
                }

                if gemini.isLoading {
                    loadingView
                } else if let result = gemini.result {
                    advisorContent(result)
                }
            }
            .padding(16)
            .cardStyle()
            .transition(.opacity.combined(with: .offset(y: 8)))
        }
    }

    // MARK: Loading

    private var loadingView: some View {
        HStack(spacing: 10) {
            ProgressView()
                .controlSize(.small)
            Text("Analyzing inspection data...")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
    }

    // MARK: Content

    @ViewBuilder
    private func advisorContent(_ result: GeminiService.AdvisorResult) -> some View {
        // Risk badge
        HStack(spacing: 6) {
            Circle()
                .fill(riskColor)
                .frame(width: 7, height: 7)
            Text("\(result.riskLevel) RISK")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .tracking(0.8)
                .foregroundStyle(riskColor)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(riskColor.opacity(0.08), in: Capsule())

        // Summary
        Text(result.summary)
            .font(.system(size: 13))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .lineSpacing(3)

        // Concerns
        if result.concerns != "None" && result.concerns != "N/A" {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 5) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 11))
                    Text("Concerns")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(cautionColor)

                Text(result.concerns)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(2)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(cautionColor.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
        }

        // Recommendations
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 5) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 11))
                Text("Tips")
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(.blue)

            Text(result.recommendations)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(2)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.blue.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))

        // Error note
        if gemini.error != nil {
            Text("AI analysis offline — showing assessment from inspection records.")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .italic()
        }
    }
}

// MARK: - Nearby Alternatives

private struct NearbyAlternativesSection: View {
    let currentId: String
    let onSelect: (String) -> Void

    private var alternatives: [RestaurantData] {
        RestaurantDataStore.shared.nearbyAlternatives(excluding: currentId)
    }

    var body: some View {
        if !alternatives.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(.blue)
                    Text("Safer Alternatives Nearby")
                        .font(.system(size: 16, weight: .semibold))
                }
                .padding(.horizontal, 4)

                ForEach(alternatives) { alt in
                    Button { onSelect(alt.id) } label: {
                        alternativeRow(alt)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func alternativeRow(_ restaurant: RestaurantData) -> some View {
        HStack(spacing: 12) {
            MiniTrustGauge(score: restaurant.trustScore, level: restaurant.trustLevel)
                .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 3) {
                Text(restaurant.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Label(pseudoDistance(for: restaurant.id), systemImage: "location.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Label(restaurant.type, systemImage: "fork.knife")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .cardStyle(cornerRadius: 14)
    }

    private func pseudoDistance(for id: String) -> String {
        // Stable pseudo-distance from character codes
        let hash = id.utf8.reduce(0) { $0 &+ Int($1) }
        let meters = 150 + (hash % 800) // 150m to 950m
        return "\(meters) m"
    }
}

// MARK: - Mini Trust Gauge

private struct MiniTrustGauge: View {
    let score: Int
    let level: TrustLevel

    var body: some View {
        ZStack {
            Circle()
                .trim(from: 0, to: 0.75)
                .stroke(Color(.tertiarySystemFill), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(135))

            Circle()
                .trim(from: 0, to: Double(score) / 100.0 * 0.75)
                .stroke(level.color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(135))

            Text("\(score)")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(level.color)
        }
    }
}

// MARK: - Voice Briefing Button

private struct VoiceBriefingButton: View {
    let gemini: GeminiService
    let tts: ElevenLabsService
    var menuService: MenuAnalysisService? = nil
    var weather: WeatherService? = nil

    private var briefingText: String? {
        guard let result = gemini.result else { return nil }
        var parts = [result.summary]
        if result.concerns != "None" && result.concerns != "N/A" {
            parts.append(result.concerns)
        }
        parts.append(result.recommendations)

        // Weather and time tips
        if result.weatherTip != "N/A" {
            parts.append(result.weatherTip)
        }
        if result.timeTip != "N/A" {
            parts.append(result.timeTip)
        }

        // Append menu recommendations if available
        if let menu = menuService?.result {
            let recNames = menu.recommended.prefix(2).map(\.dishName)
            if !recNames.isEmpty {
                parts.append("Based on the inspection data, we recommend ordering \(recNames.joined(separator: " or ")).")
            }
            if let firstAvoid = menu.avoid.first {
                parts.append("You may want to avoid \(firstAvoid.dishName) due to \(firstAvoid.reason.lowercased())")
            }
        }

        // Allergen warning
        if result.allergenWarning != "No specific allergen concerns." && result.allergenWarning != "N/A" {
            parts.append(result.allergenWarning)
        }

        return parts.joined(separator: " ")
    }

    private var isDisabled: Bool {
        gemini.isLoading || briefingText == nil
    }

    var body: some View {
        Button {
            guard let text = briefingText else { return }
            tts.speak(text)
        } label: {
            HStack(spacing: 10) {
                Group {
                    switch tts.state {
                    case .idle:
                        Image(systemName: "waveform.circle.fill")
                            .font(.system(size: 20))
                    case .loading:
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white)
                    case .playing:
                        WaveformIndicator()
                    }
                }
                .frame(width: 24, height: 22)

                VStack(alignment: .leading, spacing: 1) {
                    Text(buttonLabel)
                        .font(.system(size: 15, weight: .semibold))
                    if tts.state == .idle {
                        Text("AI-powered voice summary")
                            .font(.system(size: 10, weight: .medium))
                            .opacity(0.7)
                    }
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(buttonGradient, in: RoundedRectangle(cornerRadius: 14))
            .opacity(isDisabled ? 0.5 : 1.0)
        }
        .disabled(isDisabled)
        .animation(.easeInOut(duration: 0.25), value: tts.state)
    }

    private var buttonLabel: String {
        switch tts.state {
        case .idle: return "Listen to Briefing"
        case .loading: return "Generating Audio..."
        case .playing: return "Tap to Stop"
        }
    }

    private var buttonGradient: LinearGradient {
        switch tts.state {
        case .playing:
            return LinearGradient(colors: [.purple, .pink.opacity(0.9)], startPoint: .leading, endPoint: .trailing)
        default:
            return LinearGradient(colors: [.blue, .blue.opacity(0.8)], startPoint: .leading, endPoint: .trailing)
        }
    }
}

// MARK: - Menu Recommendation Card

private struct MenuRecommendationCard: View {
    let service: MenuAnalysisService
    let dietary: DietaryProfile

    private var hasContent: Bool {
        service.isLoading || service.result != nil
    }

    var body: some View {
        if hasContent {
            VStack(spacing: 16) {
                // Recommended section
                if service.isLoading {
                    menuLoadingView
                } else if let result = service.result {
                    recommendedSection(result.recommended)
                    if !result.avoid.isEmpty {
                        avoidSection(result.avoid)
                    }
                }

                if service.error != nil {
                    Text("Menu analysis offline — showing general guidance.")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                        .italic()
                }
            }
            .transition(.opacity.combined(with: .offset(y: 8)))
        }
    }

    // MARK: Loading

    private var menuLoadingView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "fork.knife.circle.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(safeColor)
                Text("Recommended for You")
                    .font(.system(size: 16, weight: .semibold))
            }

            HStack(spacing: 10) {
                ProgressView()
                    .controlSize(.small)
                Text("Analyzing menu options...")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
        }
        .padding(16)
        .cardStyle()
    }

    // MARK: Recommended

    private func recommendedSection(_ items: [MenuRecommendation]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "fork.knife.circle.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(safeColor)
                Text("Recommended for You")
                    .font(.system(size: 16, weight: .semibold))
                Spacer()

                if !dietary.isEmpty {
                    Text(dietary.summary)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.blue)
                        .lineLimit(1)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.blue.opacity(0.06), in: Capsule())
                }
            }

            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(safeColor)
                        .padding(.top, 1)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.dishName)
                            .font(.system(size: 14, weight: .semibold))
                        Text(item.reason)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .lineSpacing(1)
                    }
                }
                .opacity(hasContent ? 1 : 0)
                .offset(y: hasContent ? 0 : 8)
                .animation(.easeOut(duration: 0.3).delay(Double(index) * 0.1), value: hasContent)
            }
        }
        .padding(16)
        .cardStyle()
    }

    // MARK: Avoid

    private func avoidSection(_ items: [MenuAvoidance]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.shield.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(cautionColor)
                Text("Consider Avoiding")
                    .font(.system(size: 16, weight: .semibold))
            }

            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(cautionColor)
                        .padding(.top, 2)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.dishName)
                            .font(.system(size: 13, weight: .medium))
                        Text(item.reason)
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                            .fixedSize(horizontal: false, vertical: true)
                            .lineSpacing(1)
                    }
                }
            }
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(cautionColor.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(cautionColor.opacity(0.12), lineWidth: 0.5)
                )
        }
    }
}

// MARK: - Personalized Recommendations Card

private struct PersonalizedRecsCard: View {
    let gemini: GeminiService
    let weather: WeatherService
    let dietary: DietaryProfile

    private var hasContent: Bool {
        gemini.result != nil
    }

    var body: some View {
        if hasContent, let result = gemini.result {
            let showWeather = result.weatherTip != "N/A"
            let showTime = result.timeTip != "N/A"
            let showAllergen = result.allergenWarning != "N/A"
                && result.allergenWarning != "No specific allergen concerns."
                && !dietary.allergens.isEmpty

            if showWeather || showTime || showAllergen {
                VStack(alignment: .leading, spacing: 14) {
                    // Header
                    HStack(spacing: 8) {
                        Image(systemName: "person.text.rectangle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.teal)
                        Text("Personalized For You")
                            .font(.system(size: 16, weight: .semibold))
                    }

                    // Weather tip
                    if showWeather {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: weather.weather?.sfSymbol ?? "cloud.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(.blue)
                                .frame(width: 24)

                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(weather.weather?.temperatureLabel ?? "")
                                        .font(.system(size: 13, weight: .semibold))
                                    Text(weather.weather?.condition ?? "")
                                        .font(.system(size: 12))
                                        .foregroundStyle(.secondary)
                                }
                                Text(result.weatherTip)
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .lineSpacing(1.5)
                            }
                        }
                    }

                    // Time tip
                    if showTime {
                        let period = MealPeriod.classify()
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: period.sfSymbol)
                                .font(.system(size: 16))
                                .foregroundStyle(.orange)
                                .frame(width: 24)

                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(period.label)
                                        .font(.system(size: 13, weight: .semibold))
                                    Text(timeString())
                                        .font(.system(size: 12))
                                        .foregroundStyle(.secondary)
                                }
                                Text(result.timeTip)
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .lineSpacing(1.5)
                            }
                        }
                    }

                    // Allergen warning
                    if showAllergen {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(cautionColor)
                                .frame(width: 24)

                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 4) {
                                    ForEach(Array(dietary.allergens).sorted(by: { $0.rawValue < $1.rawValue }), id: \.self) { allergen in
                                        Text(allergen.emoji)
                                            .font(.system(size: 12))
                                    }
                                    ForEach(Array(dietary.preferences).sorted(by: { $0.rawValue < $1.rawValue }), id: \.self) { pref in
                                        Text(pref.emoji)
                                            .font(.system(size: 12))
                                    }
                                }
                                Text(result.allergenWarning)
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .lineSpacing(1.5)
                            }
                        }
                    }
                }
                .padding(16)
                .cardStyle()
                .transition(.opacity.combined(with: .offset(y: 8)))
            }
        }
    }

    private func timeString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: Date())
    }
}

// MARK: - Dietary Selector Sheet

private struct DietarySelectorSheet: View {
    @Binding var profile: DietaryProfile
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 6) {
                Text("Dietary Preferences")
                    .font(.system(size: 22, weight: .bold))
                Text("We'll personalize your safety report")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 12)

            // Allergens
            VStack(alignment: .leading, spacing: 8) {
                Text("ALLERGENS")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .tracking(1)

                FlowLayout(spacing: 8) {
                    ForEach(Allergen.allCases) { allergen in
                        ChipButton(
                            label: "\(allergen.emoji) \(allergen.label)",
                            isSelected: profile.allergens.contains(allergen)
                        ) {
                            if profile.allergens.contains(allergen) {
                                profile.allergens.remove(allergen)
                            } else {
                                profile.allergens.insert(allergen)
                            }
                        }
                    }
                }
            }

            // Dietary preferences
            VStack(alignment: .leading, spacing: 8) {
                Text("DIETARY")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .tracking(1)

                FlowLayout(spacing: 8) {
                    ForEach(DietaryPreference.allCases) { pref in
                        ChipButton(
                            label: "\(pref.emoji) \(pref.label)",
                            isSelected: profile.preferences.contains(pref)
                        ) {
                            if profile.preferences.contains(pref) {
                                profile.preferences.remove(pref)
                            } else {
                                profile.preferences.insert(pref)
                            }
                        }
                    }
                }
            }

            Spacer()

            // Buttons
            VStack(spacing: 10) {
                Button {
                    onContinue()
                } label: {
                    Text(profile.isEmpty ? "Skip" : "Continue")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(.blue.gradient, in: RoundedRectangle(cornerRadius: 14))
                }

                if !profile.isEmpty {
                    Button {
                        profile = DietaryProfile()
                    } label: {
                        Text("Clear All")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.red.opacity(0.7))
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
    }
}

// MARK: - Chip Button

private struct ChipButton: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    isSelected ? Color.blue.opacity(0.15) : Color(.tertiarySystemFill),
                    in: Capsule()
                )
                .overlay(
                    Capsule().stroke(isSelected ? Color.blue : .clear, lineWidth: 1.5)
                )
                .foregroundStyle(isSelected ? .blue : .primary)
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.15), value: isSelected)
    }
}

// MARK: - Flow Layout

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        let height = rows.reduce(CGFloat(0)) { total, row in
            total + row.height + (total > 0 ? spacing : 0)
        }
        return CGSize(width: proposal.width ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        var y = bounds.minY
        for row in rows {
            var x = bounds.minX
            for item in row.items {
                subviews[item.index].place(at: CGPoint(x: x, y: y), proposal: .unspecified)
                x += item.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct RowItem { let index: Int; let width: CGFloat; let height: CGFloat }
    private struct Row { let items: [RowItem]; var height: CGFloat }

    private func computeRows(proposal: ProposedViewSize, subviews: Subviews) -> [Row] {
        let maxWidth = proposal.width ?? .infinity
        var rows: [Row] = []
        var currentItems: [RowItem] = []
        var currentX: CGFloat = 0
        var currentHeight: CGFloat = 0

        for (i, subview) in subviews.enumerated() {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth && !currentItems.isEmpty {
                rows.append(Row(items: currentItems, height: currentHeight))
                currentItems = []
                currentX = 0
                currentHeight = 0
            }
            currentItems.append(RowItem(index: i, width: size.width, height: size.height))
            currentX += size.width + spacing
            currentHeight = max(currentHeight, size.height)
        }
        if !currentItems.isEmpty {
            rows.append(Row(items: currentItems, height: currentHeight))
        }
        return rows
    }
}

// MARK: - Dietary Badge

private struct DietaryBadge: View {
    let profile: DietaryProfile

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "leaf.fill")
                .font(.system(size: 11))
                .foregroundStyle(.green)
            Text(profile.summary)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.primary.opacity(0.7))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Color(.tertiarySystemFill), in: Capsule())
    }
}

// MARK: - Waveform Indicator

private struct WaveformIndicator: View {
    @State private var animating = false

    private let barCount = 4
    private let barWidth: CGFloat = 3

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<barCount, id: \.self) { i in
                Capsule()
                    .fill(.white)
                    .frame(width: barWidth, height: animating ? barHeight(for: i) : 4)
                    .animation(
                        .easeInOut(duration: 0.4)
                            .repeatForever(autoreverses: true)
                            .delay(Double(i) * 0.12),
                        value: animating
                    )
            }
        }
        .onAppear { animating = true }
    }

    private func barHeight(for index: Int) -> CGFloat {
        switch index {
        case 0: return 12
        case 1: return 18
        case 2: return 14
        default: return 10
        }
    }
}
