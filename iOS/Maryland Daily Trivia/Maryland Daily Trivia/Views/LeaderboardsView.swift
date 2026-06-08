//
//  LeaderboardsView.swift
//  Maryland Daily Trivia
//
//  Updated: 1/16/26 - Contest-only leaderboard
//

import SwiftUI

struct LeaderboardsView: View {
    var body: some View {
        DailyLeaderboardView()
    }
}

#Preview {
    NavigationStack {
        LeaderboardsView()
    }
}
