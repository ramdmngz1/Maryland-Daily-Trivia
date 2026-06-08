import SwiftUI

func leaderboardRankMedalColor(_ rank: Int) -> Color {
    switch rank {
    case 1: return Color(red: 1.0, green: 0.84, blue: 0.0)
    case 2: return Color(red: 0.75, green: 0.75, blue: 0.75)
    case 3: return Color(red: 0.80, green: 0.50, blue: 0.20)
    default: return ColorTheme.textMuted
    }
}

func leaderboardTruncateName(_ name: String) -> String {
    name.count > 12 ? String(name.prefix(10)) + "\u{2026}" : name
}

func leaderboardCurrentUserId() -> String {
    KeychainHelper.getOrCreateUserId()
}

struct LeaderboardRankPill: View {
    let rank: Int
    let scoreText: String

    var body: some View {
        HStack(spacing: 12) {
            Text("Your Rank #\(rank)")
                .font(.system(size: 15, weight: .black, design: .rounded))
                .foregroundStyle(Color(red: 1.0, green: 0.86, blue: 0.24))
            Spacer()
            Text(scoreText)
                .font(.system(size: 15, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(0.96))
                .monospacedDigit()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.42))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 1))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Your rank number \(rank), \(scoreText)")
    }
}

struct LeaderboardPodiumColumn: View {
    let name: String
    let isCurrentUser: Bool
    let rank: Int
    let height: CGFloat
    let scoreText: String
    var subtitle: String? = nil

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: "medal.fill")
                .font(.system(size: 24, weight: .black))
                .foregroundStyle(leaderboardRankMedalColor(rank))

            Text(leaderboardTruncateName(name))
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundStyle(isCurrentUser ? Color(red: 1.0, green: 0.86, blue: 0.24) : .white.opacity(0.95))
                .lineLimit(1)

            Text(scoreText)
                .font(.system(size: 16, weight: .black, design: .rounded))
                .foregroundStyle(Color(red: 1.0, green: 0.86, blue: 0.24))
                .monospacedDigit()

            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.64))
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .background(
            LinearGradient(
                colors: [Color(red: 0.27, green: 0.18, blue: 0.13), Color(red: 0.16, green: 0.11, blue: 0.09)],
                startPoint: .top,
                endPoint: .bottom
            ),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(rank == 1 ? Color(red: 0.95, green: 0.74, blue: 0.18) : Color.white.opacity(0.17), lineWidth: rank == 1 ? 1.5 : 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(name), rank \(rank), \(scoreText)\(subtitle.map { ", \($0)" } ?? "")")
    }
}

struct LeaderboardHeader: View {
    let title: String
    let subtitle: String
    let isLoading: Bool

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.system(size: 29, weight: .black, design: .rounded))
                .foregroundStyle(Color(red: 1.0, green: 0.86, blue: 0.24))
                .shadow(color: .black.opacity(0.62), radius: 6, y: 3)
                .accessibilityAddTraits(.isHeader)

            Text(subtitle)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.78))

            if isLoading {
                ProgressView()
                    .tint(ColorTheme.accent)
                    .scaleEffect(0.7)
            }
        }
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [Color.black.opacity(0.48), Color.black.opacity(0.38)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.16), lineWidth: 1)
        )
    }
}

struct LeaderboardRow: View {
    let rank: Int
    let username: String
    let isCurrentUser: Bool
    let scoreText: String
    var subtitle: String? = nil

    var body: some View {
        HStack(spacing: 12) {
            Group {
                if rank <= 3 {
                    Image(systemName: "medal.fill")
                        .font(.system(size: 20, weight: .black))
                        .foregroundStyle(leaderboardRankMedalColor(rank))
                } else {
                    Text("#\(rank)")
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundStyle(.white.opacity(0.65))
                }
            }
            .frame(width: 36)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(username)
                        .font(.system(size: 16, weight: isCurrentUser ? .black : .bold, design: .rounded))
                        .foregroundStyle(isCurrentUser ? Color(red: 1.0, green: 0.86, blue: 0.24) : .white.opacity(0.95))
                        .lineLimit(1)
                        .truncationMode(.tail)

                    if isCurrentUser {
                        Text("(you)")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.62))
                    }
                }

                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.66))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(scoreText)
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundStyle(Color(red: 1.0, green: 0.86, blue: 0.24))
                .lineLimit(1)
                .monospacedDigit()
                .frame(minWidth: 76, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            LinearGradient(
                colors: isCurrentUser
                    ? [Color(red: 0.30, green: 0.22, blue: 0.09), Color(red: 0.20, green: 0.14, blue: 0.08)]
                    : [Color(red: 0.20, green: 0.14, blue: 0.11), Color(red: 0.13, green: 0.10, blue: 0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isCurrentUser ? Color(red: 0.95, green: 0.74, blue: 0.18) : Color.white.opacity(0.15), lineWidth: isCurrentUser ? 1.3 : 1)
        )
        .shadow(color: .black.opacity(isCurrentUser ? 0.28 : 0.18), radius: 7, y: 3)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(username)\(isCurrentUser ? ", you" : ""), rank \(rank), \(scoreText)\(subtitle.map { ", \($0)" } ?? "")")
    }
}

struct LeaderboardListContainer<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                content
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
        }
        .background(
            LinearGradient(
                colors: [Color.black.opacity(0.56), Color.black.opacity(0.44)],
                startPoint: .top,
                endPoint: .bottom
            ),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
    }
}
