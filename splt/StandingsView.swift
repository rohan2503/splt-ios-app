//
//  StandingsView.swift
//  splt
//
//  Created by Rohan Y J on 10/10/24.
//

import SwiftUI
import Foundation

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
