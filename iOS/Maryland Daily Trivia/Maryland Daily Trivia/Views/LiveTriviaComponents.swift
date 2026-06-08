import SwiftUI

struct QuestionLayoutMetrics {
    let containerHorizontalPadding: CGFloat
    let topPadding: CGFloat
    let bottomPadding: CGFloat
    let stackSpacing: CGFloat
    let answerSpacing: CGFloat

    let questionFontSize: CGFloat
    let questionLineLimit: Int
    let questionHorizontalPadding: CGFloat
    let questionVerticalPadding: CGFloat
    let questionCornerRadius: CGFloat

    let answerFontSize: CGFloat
    let answerLineLimit: Int
    let answerHorizontalPadding: CGFloat
    let answerVerticalPadding: CGFloat
    let answerCornerRadius: CGFloat
    let answerMinHeight: CGFloat
    let answerLetterFontSize: CGFloat
    let answerLetterWidth: CGFloat
    let answerIndicatorSize: CGFloat

    let timerSegmentCount: Int
    let timerSegmentWidth: CGFloat
    let timerSegmentHeight: CGFloat
    let timerSegmentSpacing: CGFloat
    let timerGroupGap: CGFloat
    let timerSecondsFontSize: CGFloat
    let timerIconSize: CGFloat
    let timerOuterPadding: CGFloat
    let timerInnerHorizontalPadding: CGFloat
    let timerInnerVerticalPadding: CGFloat
    let timerInnerCornerRadius: CGFloat
    let timerOuterCornerRadius: CGFloat
}

func computeQuestionLayoutMetrics(
    size: CGSize,
    question: String,
    answers: [String]
) -> QuestionLayoutMetrics {
    let width = max(size.width, 320)
    let height = max(size.height, 500)
    let questionLength = question.count
    let longestAnswer = answers.map(\.count).max() ?? 0

    let widthScale: CGFloat = width < 350 ? 0.82 : (width < 390 ? 0.92 : 1.0)
    let heightScale: CGFloat
    switch height {
    case ..<610: heightScale = 0.68
    case ..<680: heightScale = 0.78
    case ..<760: heightScale = 0.89
    default: heightScale = 1.0
    }

    let questionDensityScale = max(0.62, min(1.0, 1.0 - CGFloat(max(0, questionLength - 62)) / 185.0))
    let answerDensityScale = max(0.64, min(1.0, 1.0 - CGFloat(max(0, longestAnswer - 24)) / 120.0))
    let baselineScale = max(0.64, min(1.0, min(widthScale, min(heightScale, min(questionDensityScale, answerDensityScale)))))
    let segmentCount = width < 350 ? 8 : 10

    let availableHeight = max(360, height - 10)
    var globalScale = baselineScale

    func boundedLines(_ count: Int, min minLines: Int, max maxLines: Int) -> Int {
        max(minLines, min(maxLines, count))
    }

    func estimatedLines(charCount: Int, charsPerLine: CGFloat, min minLines: Int, max maxLines: Int) -> Int {
        guard charCount > 0 else { return minLines }
        let safeCharsPerLine = max(10, charsPerLine)
        let raw = Int(ceil(CGFloat(charCount) / safeCharsPerLine))
        return boundedLines(raw, min: minLines, max: maxLines)
    }

    func estimateTotalHeight(for scale: CGFloat) -> CGFloat {
        let containerHorizontalPadding = max(10, 18 * widthScale)
        let stackSpacing = max(7, 14 * scale)
        let answerSpacing = max(6, 9 * scale)
        let topPadding = max(4, 14 * heightScale)
        let bottomPadding = max(8, 14 * heightScale)

        let questionFont = max(18, 43 * scale)
        let questionLineEstimate = estimatedLines(
            charCount: questionLength,
            charsPerLine: (width - (containerHorizontalPadding * 2) - (max(12, 18 * widthScale) * 2)) / max(8, questionFont * 0.52),
            min: 2,
            max: 5
        )
        let questionBlockHeight =
            CGFloat(questionLineEstimate) * questionFont * 1.16 +
            (max(12, 22 * scale) * 2)

        let answerFont = max(14, 35 * scale)
        let answerHorizontalPadding = max(11, 18 * widthScale)
        let letterWidth = max(38, 64 * widthScale)
        let answerTextWidth = max(
            80,
            width - (containerHorizontalPadding * 2) - (answerHorizontalPadding * 2) - letterWidth - max(16, 24 * scale) - 24
        )
        let perAnswerHeight: CGFloat = answers.reduce(0) { partial, answer in
            let lineEstimate = estimatedLines(
                charCount: answer.count,
                charsPerLine: answerTextWidth / max(7.5, answerFont * 0.52),
                min: 1,
                max: 4
            )
            let answerHeight = max(
                44,
                CGFloat(lineEstimate) * answerFont * 1.13 + (max(8, 14 * scale) * 2)
            )
            return partial + answerHeight
        }

        let timerHeight =
            max(7, 14 * scale) +
            (max(5, 8 * scale) * 2) +
            (max(6, 10 * scale) * 2) +
            (max(6, 10 * scale) * 2)

        let stackSectionSpacing = stackSpacing * 2
        let answerStackSpacing = answerSpacing * CGFloat(max(0, answers.count - 1))

        return topPadding + questionBlockHeight + stackSectionSpacing + perAnswerHeight + answerStackSpacing + timerHeight + bottomPadding
    }

    while estimateTotalHeight(for: globalScale) > availableHeight && globalScale > 0.48 {
        globalScale *= 0.93
    }

    let questionFont = max(18, 43 * globalScale)
    let questionCharsPerLine = (width - (max(10, 18 * widthScale) * 2) - (max(12, 18 * widthScale) * 2)) / max(8, questionFont * 0.52)
    let questionLineLimit = estimatedLines(
        charCount: questionLength,
        charsPerLine: questionCharsPerLine,
        min: 2,
        max: 5
    )

    let answerFont = max(14, 35 * globalScale)
    let answerCharsPerLine = (width - (max(10, 18 * widthScale) * 2) - (max(11, 18 * widthScale) * 2) - max(38, 64 * widthScale) - max(16, 24 * globalScale) - 24) / max(7.5, answerFont * 0.52)
    let answerLineLimit = estimatedLines(
        charCount: longestAnswer,
        charsPerLine: answerCharsPerLine,
        min: 1,
        max: 4
    )

    return QuestionLayoutMetrics(
        containerHorizontalPadding: max(10, 18 * widthScale),
        topPadding: max(4, 14 * heightScale),
        bottomPadding: max(8, 14 * heightScale),
        stackSpacing: max(7, 14 * globalScale),
        answerSpacing: max(6, 9 * globalScale),
        questionFontSize: max(22, 43 * globalScale),
        questionLineLimit: questionLineLimit,
        questionHorizontalPadding: max(12, 18 * widthScale),
        questionVerticalPadding: max(12, 22 * globalScale),
        questionCornerRadius: max(12, 18 * globalScale),
        answerFontSize: max(17, 35 * globalScale),
        answerLineLimit: answerLineLimit,
        answerHorizontalPadding: max(11, 18 * widthScale),
        answerVerticalPadding: max(8, 14 * globalScale),
        answerCornerRadius: max(10, 14 * globalScale),
        answerMinHeight: max(52, 80 * globalScale + CGFloat(answerLineLimit == 3 ? 12 : 0)),
        answerLetterFontSize: max(17, 34 * globalScale),
        answerLetterWidth: max(38, 64 * widthScale),
        answerIndicatorSize: max(16, 24 * globalScale),
        timerSegmentCount: segmentCount,
        timerSegmentWidth: max(7, 14 * globalScale),
        timerSegmentHeight: max(7, 14 * globalScale),
        timerSegmentSpacing: max(2, 4 * globalScale),
        timerGroupGap: max(6, 12 * globalScale),
        timerSecondsFontSize: max(17, 28 * globalScale),
        timerIconSize: max(11, 15 * globalScale),
        timerOuterPadding: max(6, 10 * globalScale),
        timerInnerHorizontalPadding: max(6, 10 * globalScale),
        timerInnerVerticalPadding: max(5, 8 * globalScale),
        timerInnerCornerRadius: max(6, 8 * globalScale),
        timerOuterCornerRadius: max(9, 12 * globalScale)
    )
}

struct MarylandTriviaQuizBackground: View {
    var body: some View {
        GeometryReader { geo in
            ZStack {
                Image("LaunchIcon")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .blur(radius: 18)
                    .scaleEffect(1.08)
                    .saturation(1.18)
                    .overlay(Color.black.opacity(0.52))

                LinearGradient(
                    colors: [.black.opacity(0.54), .clear, .black.opacity(0.62)],
                    startPoint: .top,
                    endPoint: .bottom
                )

                RadialGradient(
                    colors: [Color(red: 1.0, green: 0.82, blue: 0.16).opacity(0.14), .clear],
                    center: .center,
                    startRadius: 10,
                    endRadius: 430
                )
            }
            .ignoresSafeArea()
        }
    }
}

struct CoachStep {
    let title: String
    let detail: String
    let icon: String
}

struct PressableCardButtonStyle: ButtonStyle {
    let reduceMotion: Bool
    let isDisabled: Bool

    func makeBody(configuration: Configuration) -> some View {
        let pressedScale: CGFloat = (configuration.isPressed && !reduceMotion && !isDisabled) ? 0.985 : 1.0
        return configuration.label
            .scaleEffect(pressedScale)
            .animation(
                reduceMotion ? nil : .spring(response: 0.2, dampingFraction: 0.78),
                value: configuration.isPressed
            )
    }
}

struct ShareContent: Identifiable {
    let id = UUID()
    let text: String
}
