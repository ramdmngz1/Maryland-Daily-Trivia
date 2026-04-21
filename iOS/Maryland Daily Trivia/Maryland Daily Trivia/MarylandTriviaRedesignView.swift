import SwiftUI

// MARK: - Maryland Trivia Redesign Prototype
// Drop this into your project as a visual direction file.

struct MarylandTriviaRedesignView: View {
    @State private var selectedScreen: DemoScreen = .home

    var body: some View {
        ZStack {
            MarylandFlagBackground()

            VStack(spacing: 0) {
                header

                TabView(selection: $selectedScreen) {
                    MarylandHomeScreen()
                        .tag(DemoScreen.home)

                    MarylandQuestionScreen()
                        .tag(DemoScreen.question)

                    MarylandResultsScreen()
                        .tag(DemoScreen.results)

                    MarylandSettingsScreen()
                        .tag(DemoScreen.settings)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                footerNav
            }
        }
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: selectedScreen.symbol)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.yellow)
                .frame(width: 36, height: 36)
                .background(RedesignTone.panel, in: Circle())
                .overlay(Circle().stroke(RedesignTone.border, lineWidth: 1))

            VStack(alignment: .leading, spacing: 2) {
                Text("Maryland Trivia")
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text(selectedScreen.subtitle)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.72))
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 10)
    }

    private var footerNav: some View {
        HStack(spacing: 10) {
            ForEach(DemoScreen.allCases, id: \.self) { screen in
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.88)) {
                        selectedScreen = screen
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: screen.symbol)
                            .font(.system(size: 13, weight: .bold))
                        Text(screen.rawValue)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(selectedScreen == screen ? .black : .white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(selectedScreen == screen ? .yellow : RedesignTone.panel, in: Capsule())
                    .overlay(Capsule().stroke(selectedScreen == screen ? .clear : RedesignTone.border, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(RedesignTone.panelSoft, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(RedesignTone.border, lineWidth: 1)
        )
        .shadow(color: RedesignTone.shadow, radius: 12, y: 6)
        .padding(.horizontal, 18)
        .padding(.bottom, 18)
    }
}

// MARK: - Demo Screens

enum DemoScreen: String, CaseIterable {
    case home = "Home"
    case question = "Question"
    case results = "Results"
    case settings = "Settings"

    var symbol: String {
        switch self {
        case .home: return "house.fill"
        case .question: return "questionmark.circle.fill"
        case .results: return "trophy.fill"
        case .settings: return "gearshape.fill"
        }
    }

    var subtitle: String {
        switch self {
        case .home: return "Game-first redesign inspired by your icon"
        case .question: return "Large answer targets and cleaner hierarchy"
        case .results: return "A payoff screen that feels earned"
        case .settings: return "Keeps the style without turning into a mess"
        }
    }
}

private enum RedesignTone {
    static let panel = Color(red: 0.10, green: 0.06, blue: 0.07).opacity(0.94)
    static let panelSoft = Color(red: 0.13, green: 0.09, blue: 0.10).opacity(0.92)
    static let border = Color.white.opacity(0.22)
    static let shadow = Color.black.opacity(0.22)
}

struct MarylandHomeScreen: View {
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                Spacer(minLength: 8)

                MarylandLogoHeroCard()

                HStack(spacing: 14) {
                    QuickStatPill(title: "Daily Streak", value: "7", icon: "flame.fill")
                    QuickStatPill(title: "Best Score", value: "9/10", icon: "star.fill")
                }

                PrimaryActionCard(
                    title: "Daily Challenge",
                    subtitle: "10 questions. One shot. New round every day.",
                    badge: "LIVE",
                    buttonTitle: "Start Daily"
                )

                infoStrip
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 110)
        }
    }

    private var infoStrip: some View {
        HStack(spacing: 10) {
            Image(systemName: "clock.fill")
                .foregroundStyle(.yellow)
            Text("Next refresh in 03:12:44")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.86))
            Spacer()
        }
        .padding(16)
        .background(RedesignTone.panelSoft, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(RedesignTone.border, lineWidth: 1)
        )
        .shadow(color: RedesignTone.shadow, radius: 8, y: 4)
    }
}

struct MarylandQuestionScreen: View {
    @State private var selectedAnswer: Int? = 1

    private let answers = [
        "Annapolis",
        "Frederick",
        "Baltimore",
        "St. Mary's City"
    ]

    private let letters = ["A", "B", "C", "D"]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                Spacer(minLength: 8)

                HStack(spacing: 12) {
                    ScoreCapsule(title: "Score", value: "240")
                    ScoreCapsule(title: "Question", value: "4/10")
                    ScoreCapsule(title: "Time", value: "11s")
                }

                VStack(alignment: .leading, spacing: 14) {
                    Text("History")
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.yellow, in: Capsule())

                    Text("What was Maryland's first capital?")
                        .font(.system(size: 30, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.leading)

                    Text("Pick one answer before the timer runs out.")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.78))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(22)
                .background(
                    LinearGradient(
                        colors: [RedesignTone.panel, Color(red: 0.44, green: 0.08, blue: 0.12).opacity(0.45)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 28, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(RedesignTone.border, lineWidth: 1)
                )
                .shadow(color: RedesignTone.shadow, radius: 12, y: 6)

                VStack(spacing: 12) {
                    ForEach(Array(answers.enumerated()), id: \.offset) { index, answer in
                        AnswerChoiceCard(
                            letter: letters[index],
                            text: answer,
                            isSelected: selectedAnswer == index
                        ) {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                                selectedAnswer = index
                            }
                        }
                    }
                }

                VStack(spacing: 10) {
                    HStack {
                        Text("Progress")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.75))
                        Spacer()
                        Text("40%")
                            .font(.system(size: 13, weight: .black, design: .rounded))
                            .foregroundStyle(.yellow)
                    }

                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule().fill(.white.opacity(0.12))
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [.red, .orange, .yellow],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: proxy.size.width * 0.4)
                        }
                    }
                    .frame(height: 12)
                }
                .padding(18)
                .background(RedesignTone.panelSoft, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(RedesignTone.border, lineWidth: 1)
                )
                .shadow(color: RedesignTone.shadow, radius: 8, y: 4)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 110)
        }
    }
}

struct MarylandResultsScreen: View {
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                Spacer(minLength: 8)

                VStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(.yellow.opacity(0.18))
                            .frame(width: 150, height: 150)
                            .blur(radius: 10)

                        Image(systemName: "trophy.fill")
                            .font(.system(size: 62, weight: .black))
                            .foregroundStyle(.yellow)
                    }

                    Text("8 / 10")
                        .font(.system(size: 48, weight: .black, design: .rounded))
                        .foregroundStyle(.white)

                    Text("Not bad. You actually know Maryland.")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.82))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(28)
                .background(RedesignTone.panel, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .stroke(RedesignTone.border, lineWidth: 1)
                )
                .shadow(color: RedesignTone.shadow, radius: 12, y: 6)

                HStack(spacing: 14) {
                    ResultStatCard(title: "Correct", value: "8", tint: .green)
                    ResultStatCard(title: "Avg Time", value: "9.1s", tint: .yellow)
                    ResultStatCard(title: "Streak", value: "7", tint: .orange)
                }

                VStack(spacing: 12) {
                    BigButton(title: "Play Again", subtitle: "Jump into the next round", fill: .yellow, foreground: .black)
                    BigButton(title: "Back Home", subtitle: "Return to the main menu", fill: RedesignTone.panelSoft, foreground: .white)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 110)
        }
    }
}

struct MarylandSettingsScreen: View {
    @State private var soundOn = true
    @State private var hapticsOn = true
    @State private var reduceMotion = false
    @State private var difficulty = 1

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                Spacer(minLength: 8)

                SettingsCard(title: "Gameplay") {
                    settingsToggleRow(icon: "speaker.wave.2.fill", title: "Sound Effects", isOn: $soundOn)
                    settingsToggleRow(icon: "iphone.radiowaves.left.and.right", title: "Haptics", isOn: $hapticsOn)
                    settingsToggleRow(icon: "figure.walk.motion", title: "Reduce Motion", isOn: $reduceMotion)
                }

                SettingsCard(title: "Difficulty") {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("Mode")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                            Spacer()
                            Text(["Easy", "Normal", "Hard"][difficulty])
                                .font(.system(size: 14, weight: .black, design: .rounded))
                                .foregroundStyle(.yellow)
                        }

                        Picker("Difficulty", selection: $difficulty) {
                            Text("Easy").tag(0)
                            Text("Normal").tag(1)
                            Text("Hard").tag(2)
                        }
                        .pickerStyle(.segmented)
                    }
                }

                SettingsCard(title: "Account") {
                    HStack(spacing: 14) {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 38))
                            .foregroundStyle(.yellow)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Ramon")
                                .font(.system(size: 18, weight: .black, design: .rounded))
                                .foregroundStyle(.white)
                            Text("Contest-ready profile")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.72))
                        }

                        Spacer()
                    }
                }

                BigButton(title: "Save Changes", subtitle: "Keep the settings clean and predictable", fill: .yellow, foreground: .black)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 110)
        }
    }

    private func settingsToggleRow(icon: String, title: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.yellow)
                .frame(width: 34)

            Text(title)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Spacer()

            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(.yellow)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Building Blocks

struct MarylandFlagBackground: View {
    var body: some View {
        Color(red: 0.96, green: 0.92, blue: 0.85)
            .ignoresSafeArea()
    }
}

private struct MarylandFlagPattern: View {
    var body: some View {
        GeometryReader { geo in
            let halfWidth = geo.size.width * 0.5
            let halfHeight = geo.size.height * 0.5

            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    CalvertPattern()
                        .frame(width: halfWidth, height: halfHeight)
                    CrosslandPattern()
                        .frame(width: halfWidth, height: halfHeight)
                }
                HStack(spacing: 0) {
                    CrosslandPattern()
                        .frame(width: halfWidth, height: halfHeight)
                    CalvertPattern()
                        .frame(width: halfWidth, height: halfHeight)
                }
            }
        }
    }
}

private struct CalvertPattern: View {
    private let calvertGold = Color(red: 0.90, green: 0.74, blue: 0.24)
    private let calvertBlack = Color(red: 0.07, green: 0.06, blue: 0.07)

    var body: some View {
        GeometryReader { geo in
            Canvas { context, size in
                context.fill(
                    Path(CGRect(origin: .zero, size: size)),
                    with: .color(calvertBlack)
                )

                let band = max(size.width * 0.14, 42)
                let overshoot = size.height + band

                for idx in -6...12 {
                    var path = Path()
                    let x0 = CGFloat(idx) * band * 0.95

                    path.move(to: CGPoint(x: x0, y: 0))
                    path.addLine(to: CGPoint(x: x0 + band * 0.7, y: 0))
                    path.addLine(to: CGPoint(x: x0 + overshoot + band * 0.7, y: size.height))
                    path.addLine(to: CGPoint(x: x0 + overshoot, y: size.height))
                    path.closeSubpath()

                    if idx.isMultiple(of: 2) {
                        context.fill(path, with: .color(calvertGold))
                    }
                }
            }
            .overlay(
                LinearGradient(
                    colors: [.clear, .black.opacity(0.2)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
    }
}

private struct CrosslandPattern: View {
    private let crossRed = Color(red: 0.78, green: 0.10, blue: 0.20)

    var body: some View {
        GeometryReader { geo in
            ZStack {
                CheckerboardPattern(first: crossRed, second: .white)

                CrossBottonyShape()
                    .fill(.white)
                    .mask(CheckerMask(inverse: false))
                CrossBottonyShape()
                    .fill(crossRed)
                    .mask(CheckerMask(inverse: true))
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .overlay(
                LinearGradient(
                    colors: [.white.opacity(0.05), .black.opacity(0.08)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
    }
}

private struct CheckerboardPattern: View {
    let first: Color
    let second: Color

    var body: some View {
        GeometryReader { geo in
            let hw = geo.size.width * 0.5
            let hh = geo.size.height * 0.5
            ZStack(alignment: .topLeading) {
                first

                Rectangle()
                    .fill(second)
                    .frame(width: hw, height: hh)
                    .offset(x: hw, y: 0)

                Rectangle()
                    .fill(second)
                    .frame(width: hw, height: hh)
                    .offset(x: 0, y: hh)
            }
        }
    }
}

private struct CheckerMask: View {
    let inverse: Bool

    var body: some View {
        GeometryReader { geo in
            let hw = geo.size.width * 0.5
            let hh = geo.size.height * 0.5

            ZStack(alignment: .topLeading) {
                if inverse {
                    Rectangle().fill(.white)
                        .frame(width: hw, height: hh)
                        .offset(x: hw, y: 0)
                    Rectangle().fill(.white)
                        .frame(width: hw, height: hh)
                        .offset(x: 0, y: hh)
                } else {
                    Rectangle().fill(.white)
                        .frame(width: hw, height: hh)
                        .offset(x: 0, y: 0)
                    Rectangle().fill(.white)
                        .frame(width: hw, height: hh)
                        .offset(x: hw, y: hh)
                }
            }
        }
    }
}

private struct CrossBottonyShape: Shape {
    func path(in rect: CGRect) -> Path {
        let dimension = min(rect.width, rect.height)
        let arm = dimension * 0.19
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let lobe = arm * 0.42

        var path = Path()

        path.addRoundedRect(
            in: CGRect(
                x: center.x - arm * 0.5,
                y: rect.minY + arm * 0.42,
                width: arm,
                height: rect.height - arm * 0.84
            ),
            cornerSize: CGSize(width: arm * 0.35, height: arm * 0.35)
        )

        path.addRoundedRect(
            in: CGRect(
                x: rect.minX + arm * 0.42,
                y: center.y - arm * 0.5,
                width: rect.width - arm * 0.84,
                height: arm
            ),
            cornerSize: CGSize(width: arm * 0.35, height: arm * 0.35)
        )

        func addTrefoil(at point: CGPoint, direction: CGVector) {
            path.addEllipse(
                in: CGRect(
                    x: point.x - lobe,
                    y: point.y - lobe,
                    width: lobe * 2,
                    height: lobe * 2
                )
            )

            let side = lobe * 0.82
            let tangent = CGVector(dx: -direction.dy, dy: direction.dx)
            let forward = CGVector(dx: direction.dx * (lobe * 0.45), dy: direction.dy * (lobe * 0.45))

            let p1 = CGPoint(x: point.x + tangent.dx * side + forward.dx, y: point.y + tangent.dy * side + forward.dy)
            let p2 = CGPoint(x: point.x - tangent.dx * side + forward.dx, y: point.y - tangent.dy * side + forward.dy)

            path.addEllipse(in: CGRect(x: p1.x - lobe * 0.74, y: p1.y - lobe * 0.74, width: lobe * 1.48, height: lobe * 1.48))
            path.addEllipse(in: CGRect(x: p2.x - lobe * 0.74, y: p2.y - lobe * 0.74, width: lobe * 1.48, height: lobe * 1.48))
        }

        addTrefoil(at: CGPoint(x: center.x, y: rect.minY + arm * 0.42), direction: CGVector(dx: 0, dy: -1))
        addTrefoil(at: CGPoint(x: center.x, y: rect.maxY - arm * 0.42), direction: CGVector(dx: 0, dy: 1))
        addTrefoil(at: CGPoint(x: rect.minX + arm * 0.42, y: center.y), direction: CGVector(dx: -1, dy: 0))
        addTrefoil(at: CGPoint(x: rect.maxX - arm * 0.42, y: center.y), direction: CGVector(dx: 1, dy: 0))

        return path
    }
}

private struct FlagFabricOverlay: View {
    var body: some View {
        GeometryReader { geo in
            Canvas { context, size in
                let waveSpacing = max(size.height * 0.035, 18)
                for row in stride(from: CGFloat(0), through: size.height + waveSpacing, by: waveSpacing) {
                    var path = Path()
                    path.move(to: CGPoint(x: 0, y: row))
                    path.addQuadCurve(
                        to: CGPoint(x: size.width, y: row),
                        control: CGPoint(
                            x: size.width * 0.45,
                            y: row + waveSpacing * 0.55
                        )
                    )
                    context.stroke(path, with: .color(.white.opacity(0.055)), lineWidth: 1)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }
}

struct MarylandLogoHeroCard: View {
    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(.yellow.opacity(0.2))
                    .frame(width: 180, height: 180)
                    .blur(radius: 14)

                Image("LaunchIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 210)
                    .shadow(color: .black.opacity(0.45), radius: 20, y: 10)
            }
            .padding(.top, 10)

            Text("Maryland Daily Trivia")
                .font(.system(size: 34, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Text("Bold, fast, and not visually timid.")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.76))
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(
            LinearGradient(
                colors: [RedesignTone.panel, Color(red: 0.46, green: 0.09, blue: 0.12).opacity(0.38)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 30, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(RedesignTone.border, lineWidth: 1)
        )
        .shadow(color: RedesignTone.shadow, radius: 12, y: 6)
    }
}

struct PrimaryActionCard: View {
    let title: String
    let subtitle: String
    let badge: String
    let buttonTitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(title)
                    .font(.system(size: 25, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                Spacer()

                Text(badge)
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(.yellow, in: Capsule())
            }

            Text(subtitle)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.78))

            BigButton(title: buttonTitle, subtitle: "Best played with confidence", fill: .yellow, foreground: .black)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(22)
        .background(RedesignTone.panelSoft, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(RedesignTone.border, lineWidth: 1)
        )
        .shadow(color: RedesignTone.shadow, radius: 10, y: 5)
    }
}

struct SecondaryActionGrid: View {
    var body: some View {
        SmallMenuCard(icon: "list.number", title: "Leaderboard", subtitle: "See today's top scores")
    }
}

struct SmallMenuCard: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.yellow)
                .frame(width: 44, height: 44)
                .background(.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            Text(title)
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundStyle(.white)

            Text(subtitle)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.72))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 160, alignment: .topLeading)
        .padding(18)
        .background(RedesignTone.panelSoft, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(RedesignTone.border, lineWidth: 1)
        )
        .shadow(color: RedesignTone.shadow, radius: 8, y: 4)
    }
}

struct QuickStatPill: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(.yellow)
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text(title)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
            }
            Spacer()
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(RedesignTone.panelSoft, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(RedesignTone.border, lineWidth: 1)
        )
        .shadow(color: RedesignTone.shadow, radius: 6, y: 4)
    }
}

struct ScoreCapsule: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundStyle(.yellow)
            Text(title)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.72))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(RedesignTone.panelSoft, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(RedesignTone.border, lineWidth: 1)
        )
        .shadow(color: RedesignTone.shadow, radius: 6, y: 4)
    }
}

struct AnswerChoiceCard: View {
    let letter: String
    let text: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Text(letter)
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundStyle(isSelected ? .black : .yellow)
                    .frame(width: 42, height: 42)
                    .background(isSelected ? .yellow : .white.opacity(0.08), in: Circle())

                Text(text)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(isSelected ? .yellow : .white.opacity(0.35))
            }
            .padding(18)
            .background(isSelected ? .yellow.opacity(0.16) : RedesignTone.panelSoft, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(isSelected ? .yellow.opacity(0.65) : RedesignTone.border, lineWidth: 1.2)
            )
        }
        .buttonStyle(.plain)
    }
}

struct ResultStatCard: View {
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(spacing: 8) {
            Text(value)
                .font(.system(size: 24, weight: .black, design: .rounded))
                .foregroundStyle(tint)
            Text(title)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.72))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(RedesignTone.panelSoft, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(RedesignTone.border, lineWidth: 1)
        )
        .shadow(color: RedesignTone.shadow, radius: 8, y: 4)
    }
}

struct SettingsCard<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(.white)

            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(RedesignTone.panelSoft, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(RedesignTone.border, lineWidth: 1)
        )
        .shadow(color: RedesignTone.shadow, radius: 10, y: 5)
    }
}

struct BigButton: View {
    let title: String
    let subtitle: String
    let fill: Color
    let foreground: Color

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 18, weight: .black, design: .rounded))
                Text(subtitle)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .opacity(0.8)
            }

            Spacer()

            Image(systemName: "arrow.right")
                .font(.system(size: 16, weight: .black))
        }
        .foregroundStyle(foreground)
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(fill, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

// MARK: - Preview

#Preview {
    MarylandTriviaRedesignView()
}
