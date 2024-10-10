//
//  MatchesViewModel.swift
//  splt
//
//  Created by Rohan Y J on 10/10/24.
//

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
