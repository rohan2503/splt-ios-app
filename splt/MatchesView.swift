import SwiftUI
import Foundation
import Firebase
import FirebaseAuth
import FirebaseFirestore


struct MatchesView: View {
    @StateObject private var viewModel = MatchesViewModel()
    @StateObject private var favoriteTeamManager = FavoriteTeamManager()
    @State private var selectedDate = Date()
    @State private var showingStandingsSheet = false
    @State private var showingAccountSheet = false
    @Binding var isUserSignedIn: Bool
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 0) {
                    // Date selector
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(-7...0, id: \.self) { offset in
                                let date = Calendar.current.date(byAdding: .day, value: offset, to: Date())!
                                DateButton(date: date, isSelected: Binding(
                                    get: { Calendar.current.isDate(selectedDate, inSameDayAs: date) },
                                    set: { _ in
                                        selectedDate = date
                                        viewModel.fetchMatches(for: date)
                                    }
                                ))
                            }
                        }
                        .padding()
                    }
                    .background(Color(UIColor.systemGray6).opacity(0.1))
                    
                    // Matches list
                    if viewModel.isLoading {
                        ProgressView("Loading matches...")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if !viewModel.errorMessage.isEmpty {
                        Text(viewModel.errorMessage)
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if viewModel.groupedMatches.isEmpty {
                        Text("No matches found for this date.")
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        List {
                            // Favorite team section
                            if let favoriteTeamId = favoriteTeamManager.favoriteTeamId,
                               let favoriteMatch = viewModel.matches.first(where: { $0.homeTeam.id == favoriteTeamId || $0.awayTeam.id == favoriteTeamId }) {
                                Section(header: Text("Favorite").font(.headline).foregroundColor(.white)) {
                                    MatchRow(match: favoriteMatch)
                                }
                            } else if favoriteTeamManager.favoriteTeamId != nil {
                                Section(header: Text("Favorite").font(.headline).foregroundColor(.white)) {
                                    Text("No fixture for your favorite team today")
                                        .foregroundColor(.gray)
                                        .padding()
                                }
                            }
                            
                            // Other matches
                            ForEach(viewModel.groupedMatches.keys.sorted(), id: \.self) { competition in
                                Section(header:
                                    Text(competition)
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .padding(.vertical, 8)
                                ) {
                                    ForEach(viewModel.groupedMatches[competition] ?? []) { match in
                                        if match.homeTeam.id != favoriteTeamManager.favoriteTeamId && match.awayTeam.id != favoriteTeamManager.favoriteTeamId {
                                            MatchRow(match: match)
                                        }
                                    }
                                }
                            }
                        }
                        .listStyle(PlainListStyle())
                        .background(Color.black)
                    }
                }
            }
            .navigationTitle("Matches")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingStandingsSheet = true
                    }) {
                        Image(systemName: "list.number")
                            .foregroundColor(.white)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingAccountSheet = true
                    }) {
                        Image(systemName: "person.circle")
                            .foregroundColor(.white)
                    }
                }
            }
        }
        .accentColor(.white)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showingStandingsSheet) {
            StandingsView(viewModel: viewModel)
        }
        .sheet(isPresented: $showingAccountSheet) {
            AccountView(viewModel: viewModel, isUserSignedIn: $isUserSignedIn)
        }
        .onAppear {
            viewModel.fetchMatches(for: selectedDate)
        }
    }
}


struct DateButton: View {
    let date: Date
    @Binding var isSelected: Bool
    
    var body: some View {
        Button(action: {
            isSelected = true
        }) {
            VStack {
                Text(dayName(from: date))
                    .font(.caption)
                    .fontWeight(.bold)
                Text(date, style: .date)
                    .font(.caption2)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(isSelected ? Color.blue.opacity(0.8) : Color.gray.opacity(0.2))
            .cornerRadius(15)
            .foregroundColor(isSelected ? .white : .gray)
        }
    }
    
    private func dayName(from date: Date) -> String {
        if Calendar.current.isDateInToday(date) {
            return "Today"
        } else if Calendar.current.isDateInYesterday(date) {
            return "Yesterday"
        } else if Calendar.current.isDateInTomorrow(date) {
            return "Tomorrow"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE"
            return formatter.string(from: date)
        }
    }
}

struct MatchRow: View {
    let match: Match
    
    var body: some View {
        HStack {
            // Home team crest
            TeamCrest(url: match.homeTeam.crest)
                .frame(width: 30, height: 30) // Reduced size to match standings
            
            VStack(alignment: .leading, spacing: 4) {
                Text(match.homeTeam.shortName ?? match.homeTeam.name)
                    .font(.system(size: 14, weight: .semibold))
                Text(match.awayTeam.shortName ?? match.awayTeam.name)
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(.white)
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(String(match.score.fullTime.home ?? 0))
                    .fontWeight(.bold)
                Text(String(match.score.fullTime.away ?? 0))
                    .fontWeight(.bold)
            }
            .foregroundColor(.white)
            .frame(width: 20)
            
            // Away team crest
            TeamCrest(url: match.awayTeam.crest)
                .frame(width: 30, height: 30) // Reduced size to match standings
            
            StatusBadge(status: match.status)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 8)
        .background(Color(UIColor.systemGray6).opacity(0.1))
        .cornerRadius(15)
    }
}


struct StatusBadge: View {
    let status: String
    
    var body: some View {
        Text(status)
            .font(.caption2)
            .fontWeight(.bold)
            .padding(6)
            .background(statusColor)
            .foregroundColor(.white)
            .cornerRadius(8)
    }
    
    private var statusColor: Color {
        switch status {
        case "FINISHED":
            return Color.green
        case "SCHEDULED":
            return Color.blue
        case "LIVE":
            return Color.red
        default:
            return Color.gray
        }
    }
}

