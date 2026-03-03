import SwiftUI

struct SimulatorShell: View {
    @Bindable var router: ClipRouter
    @State private var invocationStart: Date?

    var body: some View {
        ZStack {
            if let match = router.currentMatch {
                ClipHostView(
                    match: match,
                    invocationStart: $invocationStart,
                    router: router
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                LandingView(router: router)
                    .transition(.opacity)
            }
        }
        .animation(.spring(duration: 0.4), value: router.currentMatch?.id)
        .onChange(of: router.currentMatch?.id) { _, newValue in
            if newValue != nil {
                invocationStart = Date()
            }
        }
    }
}

struct ClipHostView: View {
    let match: ClipRouter.MatchResult
    @Binding var invocationStart: Date?
    @Bindable var router: ClipRouter

    var body: some View {
        ZStack(alignment: .top) {
            match.makeView()
                .ignoresSafeArea()

            VStack {
                GlassEffectContainer {
                    HStack(spacing: 10) {
                        HStack(spacing: 5) {
                            Image(systemName: "appclip")
                                .font(.system(size: 11, weight: .semibold))
                            Text("App Clip")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .glassEffect(.regular, in: .capsule)

                        Spacer()

                        if let start = invocationStart {
                            MomentTimer(startDate: start)
                        }

                        Button {
                            router.dismiss()
                            invocationStart = nil
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.primary)
                                .frame(width: 36, height: 36)
                                .glassEffect(.regular.interactive(), in: .circle)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 6)

                Spacer()
            }
        }
    }
}
