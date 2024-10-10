import SwiftUI
import Foundation
import Firebase
import FirebaseAuth
import FirebaseFirestore

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
                .font(.system(size: 18, weight: .medium, design: .rounded))
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
                .font(.system(size: 13, weight: .semibold, design: .rounded))
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

