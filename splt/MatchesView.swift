import SwiftUI
import Foundation
import Firebase
import FirebaseAuth
import FirebaseFirestore

class MatchesViewModel: ObservableObject {
    @Published var matches: [Match] = []
    @Published var groupedMatches: [String: [Match]] = [:]
    @Published var standings: [String: CompetitionStandings] = [:]
    @Published var isLoading = false
    @Published var isLoadingStandings = false
    @Published var errorMessage = ""
    
    func fetchMatches(for date: Date) {
        isLoading = true
        errorMessage = ""
        
        FootballDataService.shared.fetchMatches(for: date) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                switch result {
                case .success(let matches):
                    self?.matches = matches
                    self?.groupMatchesByCompetition()
                    print("Fetched \(matches.count) matches for \(date)")
                case .failure(let error):
                    self?.errorMessage = "Error fetching matches: \(error.localizedDescription)"
                    print(self?.errorMessage ?? "")
                }
            }
        }
    }
    
    func fetchStandings(for competition: String) {
        isLoadingStandings = true
        
        FootballDataService.shared.fetchStandings(for: competition) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoadingStandings = false
                switch result {
                case .success(let competitionStandings):
                    self?.standings[competition] = competitionStandings
                case .failure(let error):
                    print("Error fetching standings: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func groupMatchesByCompetition() {
        groupedMatches = Dictionary(grouping: matches, by: { $0.competition.name })
        print("Grouped matches: \(groupedMatches.keys)")
    }
    
    func logout(completion: @escaping (Bool) -> Void) {
        do {
            try Auth.auth().signOut()
            completion(true)
        } catch let signOutError as NSError {
            print("Error signing out: %@", signOutError)
            completion(false)
        }
    }
}

class FavoriteTeamManager: ObservableObject {
    @Published var favoriteTeamId: Int?
    private var db = Firestore.firestore()
    private var listenerRegistration: ListenerRegistration?

    init() {
        setupFavoriteTeamListener()
    }

    private func setupFavoriteTeamListener() {
        guard let userId = Auth.auth().currentUser?.uid else { return }

        listenerRegistration = db.collection("users").document(userId).addSnapshotListener { documentSnapshot, error in
            guard let document = documentSnapshot else {
                print("Error fetching document: \(error!)")
                return
            }
            self.favoriteTeamId = document.data()?["favoriteTeamId"] as? Int
        }
    }

    deinit {
        listenerRegistration?.remove()
    }
}

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

struct StandingsView: View {
    @ObservedObject var viewModel: MatchesViewModel
    @State private var selectedCompetition = "PL"
    
    let competitions = [
        ("PL", "Premier League"),
        ("PD", "La Liga"),
        ("CL", "Champions League"),
        ("BL1", "Bundesliga")
    ]
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 0) {
                    Picker("Competition", selection: $selectedCompetition) {
                        ForEach(competitions, id: \.0) { code, name in
                            Text(name).tag(code)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding()
                    
                    if viewModel.isLoadingStandings {
                        Spacer()
                        ProgressView("Loading standings...")
                            .foregroundColor(.white)
                        Spacer()
                    } else if let competitionStandings = viewModel.standings[selectedCompetition],
                              !competitionStandings.standings.isEmpty {
                        List {
                            ForEach(competitionStandings.standings.flatMap { $0.table }) { row in
                                standingsRow(for: row)
                            }
                        }
                        .listStyle(PlainListStyle())
                    } else {
                        Spacer()
                        Text("No standings available")
                            .foregroundColor(.gray)
                        Spacer()
                    }
                }
            }
            .navigationTitle("Standings")
            .navigationBarTitleDisplayMode(.inline)
        }
        .accentColor(.white)
        .preferredColorScheme(.dark)
        .onAppear {
            if viewModel.standings[selectedCompetition] == nil {
                viewModel.fetchStandings(for: selectedCompetition)
            }
        }
        .onChange(of: selectedCompetition) { newValue in
            if viewModel.standings[newValue] == nil {
                withAnimation(.easeInOut(duration: 0.3)) {
                    viewModel.fetchStandings(for: newValue)
                }
            }
        }
    }
    
    private func standingsRow(for row: Table) -> some View {
        HStack(spacing: 8) {
            Text("\(row.position)")
                .frame(width: 30, alignment: .center)
                .foregroundColor(.white)
            
            TeamCrest(url: row.team.crest)
                .frame(width: 30, height: 30)
            
            Text(row.team.shortName ?? row.team.name)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(1)
                .foregroundColor(.white)
            
            Text("\(row.playedGames)")
                .frame(width: 30, alignment: .center)
                .foregroundColor(.gray)
            
            Text("\(row.points)")
                .frame(width: 30, alignment: .trailing)
                .foregroundColor(.white)
        }
        .padding(.vertical, 8)
        .background(Color(UIColor.systemGray6).opacity(0.1))
        .cornerRadius(8)
    }
}

struct TeamCrest: View {
    let url: String?
    
    var body: some View {
        if let crestUrl = url, let url = URL(string: crestUrl) {
            AsyncImage(url: url) { image in
                image
                    .resizable()
                    .scaledToFit()
            } placeholder: {
                Image(systemName: "shield.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundColor(.gray)
            }
        } else {
            Image(systemName: "shield.fill")
                .resizable()
                .scaledToFit()
                .foregroundColor(.gray)
        }
    }
}

struct AccountView: View {
    @ObservedObject var viewModel: MatchesViewModel
    @Binding var isUserSignedIn: Bool
    @Environment(\.presentationMode) var presentationMode
    @State private var favoriteTeamId: Int?
    @State private var isLoading: Bool = true
    @State private var errorMessage: String?
    @State private var teams: [Team] = []
    
    let competitions = ["PL", "BL1", "PD"]
    
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            VStack {
                ScrollView {
                    VStack(spacing: 20) {
                        userProfileSection
                        favoriteTeamSection
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, 20)
                }
                
                Spacer()
                
                logoutButton
                    .padding(.bottom, 40)
                    .padding(.horizontal)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .navigationBarItems(leading: backButton)
        .overlay(loadingOverlay)
        .alert(item: Binding<AlertItem?>(
            get: { errorMessage.map { AlertItem(message: $0) } },
            set: { errorMessage = $0?.message }
        )) { alertItem in
            Alert(title: Text("Error"), message: Text(alertItem.message), dismissButton: .default(Text("OK")))
        }
        .onAppear(perform: {
            loadFavoriteTeam()
            loadCachedTeams()
        })
    }
    
    private var userProfileSection: some View {
        HStack {
            InitialsAvatar(name: Auth.auth().currentUser?.displayName ?? "User")
                .frame(width: 60, height: 60)
            
            Text("Hi, \(Auth.auth().currentUser?.displayName ?? "User")")
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
            
            Spacer()
        }
        .padding()
        .background(Color(hex: "1A1A1A"))
        .cornerRadius(12)
    }
    
    private var favoriteTeamSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Favorite Team")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundColor(Color(hex: "3A82F6"))
            
            Menu {
                ForEach(teams, id: \.id) { team in
                    Button(action: {
                        favoriteTeamId = team.id
                        saveFavoriteTeam(team)
                    }) {
                        Text(team.name)
                    }
                }
            } label: {
                HStack {
                    Text(favoriteTeamId.flatMap { id in teams.first(where: { $0.id == id })?.name } ?? "Select a team")
                        .foregroundColor(.white)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .foregroundColor(Color(hex: "3A82F6"))
                }
                .padding()
                .background(Color(hex: "2A2A2A"))
                .cornerRadius(12)
            }
            
            if let teamId = favoriteTeamId, let team = teams.first(where: { $0.id == teamId }) {
                HStack(spacing: 16) {
                    AsyncImage(url: URL(string: team.crest ?? "")) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        case .failure:
                            Image(systemName: "exclamationmark.triangle")
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .frame(width: 40, height: 40)
                    .background(Color(hex: "2A2A2A"))
                    .clipShape(Circle())
                    
                    Text(team.name)
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(.white)
                }
                .padding()
                .background(Color(hex: "2A2A2A"))
                .cornerRadius(12)
            }
        }
        .padding()
        .background(Color(hex: "1A1A1A"))
        .cornerRadius(12)
    }
    

    
    private var logoutButton: some View {
        Button(action: {
            viewModel.logout { success in
                if success {
                    isUserSignedIn = false
                    presentationMode.wrappedValue.dismiss()
                }
            }
        }) {
            Text("Logout")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(hex: "3A82F6"))
                .cornerRadius(12)
        }
    }
    
    private var backButton: some View {
        Button(action: {
            presentationMode.wrappedValue.dismiss()
        }) {
            Image(systemName: "chevron.left")
                .foregroundColor(Color(hex: "3A82F6"))
                .font(.system(size: 20, weight: .semibold))
        }
    }
    
    private var loadingOverlay: some View {
        Group {
            if isLoading {
                Color.black.opacity(0.5)
                    .edgesIgnoringSafeArea(.all)
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "3A82F6")))
                    .scaleEffect(1.2)
            }
        }
    }
    
    private func loadFavoriteTeam() {
        guard let userId = Auth.auth().currentUser?.uid else {
            isLoading = false
            errorMessage = "User not authenticated"
            return
        }
        
        let db = Firestore.firestore()
        db.collection("users").document(userId).getDocument { (document, error) in
            if let error = error {
                self.errorMessage = "Error loading data: \(error.localizedDescription)"
            } else if let document = document, document.exists,
                      let favoriteTeamId = document.data()?["favoriteTeamId"] as? Int {
                self.favoriteTeamId = favoriteTeamId
            }
            self.isLoading = false
        }
    }
    
    private func saveFavoriteTeam(_ team: Team) {
        guard let userId = Auth.auth().currentUser?.uid else {
            errorMessage = "User not authenticated"
            return
        }
        
        let db = Firestore.firestore()
        db.collection("users").document(userId).setData(["favoriteTeamId": team.id], merge: true) { error in
            if let error = error {
                errorMessage = "Error saving favorite team: \(error.localizedDescription)"
            } else {
                errorMessage = nil // Clear any previous error messages
            }
        }
    }
    
    private func loadCachedTeams() {
        if let cachedTeams = UserDefaults.standard.object(forKey: "cachedTeams") as? Data {
            let decoder = JSONDecoder()
            if let loadedTeams = try? decoder.decode([Team].self, from: cachedTeams) {
                self.teams = loadedTeams
                return
            }
        }
        
        fetchAllTeams()
    }
    
    private func fetchAllTeams() {
        isLoading = true
        errorMessage = nil
        
        let dispatchGroup = DispatchGroup()
        var allTeams: Set<Team> = []
        
        for (index, competition) in competitions.enumerated() {
            dispatchGroup.enter()
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 1.0) {
                FootballDataService.shared.fetchTeams(for: competition) { result in
                    defer { dispatchGroup.leave() }
                    switch result {
                    case .success(let fetchedTeams):
                        allTeams.formUnion(fetchedTeams)
                    case .failure(let error):
                        DispatchQueue.main.async {
                            self.errorMessage = "Error fetching teams: \(error.localizedDescription)"
                        }
                    }
                }
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            self.teams = Array(allTeams).sorted(by: { $0.name < $1.name })
            self.isLoading = false
            
            // Cache the fetched teams
            let encoder = JSONEncoder()
            if let encoded = try? encoder.encode(self.teams) {
                UserDefaults.standard.set(encoded, forKey: "cachedTeams")
            }
        }
    }
}


struct InitialsAvatar: View {
    let name: String
    
    var initials: String {
        name.components(separatedBy: " ")
            .prefix(2)
            .compactMap { $0.first }
            .map { String($0) }
            .joined()
    }
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color(hex: "3A82F6"))
            Text(initials)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
    }
}
struct AlertItem: Identifiable {
    let id = UUID()
    let message: String
}



extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

//struct MatchRow2: View {
//    let homeTeam: String
//    let awayTeam: String
//    let homeScore: Int
//    let awayScore: Int
//    let status: String
//    
//    var body: some View {
//        HStack {
//            Text(homeTeam)
//                .font(.system(size: 14, weight: .medium, design: .rounded))
//                .foregroundColor(.white)
//            Spacer()
//            Text("\(homeScore) - \(awayScore)")
//                .font(.system(size: 14, weight: .bold, design: .rounded))
//                .foregroundColor(.white)
//            Spacer()
//            Text(awayTeam)
//                .font(.system(size: 14, weight: .medium, design: .rounded))
//                .foregroundColor(.white)
//            Text(status)
//                .font(.system(size: 12, weight: .medium, design: .rounded))
//                .foregroundColor(.green)
//                .padding(.horizontal, 8)
//                .padding(.vertical, 4)
//                .background(Color.green.opacity(0.2))
//                .cornerRadius(8)
//        }
//        .padding(.vertical, 8)
//    }
//}
