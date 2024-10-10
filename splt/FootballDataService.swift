import Foundation

struct FootballDataService {
    static let shared = FootballDataService()
    private let urlSession = URLSession.shared
    private let apiKey = "7b372039417c4ffeb96f624752f801d1"
    private let baseURL = "https://api.football-data.org/v4/"
    
    private let jsonDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
    
    private init() {}
    
    static private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
    
    func fetchMatches(for date: Date, completion: @escaping(Result<[Match], Error>) -> ()) {
        let dateString = Self.dateFormatter.string(from: date)
        
        // PL: Premier League, PD: La Liga, CL: Champions League, BL1: Bundesliga
        let url = baseURL + "matches?date=\(dateString)&competitions=PL,PD,CL,BL1"
        guard let url = URL(string: url) else {
            completion(.failure(NSError(domain: "Invalid URL", code: 0, userInfo: nil)))
            return
        }
        
        var request = URLRequest(url: url)
        request.addValue(apiKey, forHTTPHeaderField: "X-Auth-Token")
        
        print("Fetching URL: \(url.absoluteString)")
        
        urlSession.dataTask(with: request) { (data, response, error) in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("HTTP Status Code: \(httpResponse.statusCode)")
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "No data received", code: 0, userInfo: nil)))
                return
            }
            
            do {
                let matchResponse = try self.jsonDecoder.decode(MatchResponse.self, from: data)
                print("Decoded \(matchResponse.matches.count) matches")
                completion(.success(matchResponse.matches))
            } catch {
                print("JSON Decoding Error: \(error)")
                completion(.failure(error))
            }
        }.resume()
    }
    
    func fetchStandings(for competition: String, completion: @escaping(Result<CompetitionStandings, Error>) -> ()) {
        let url = baseURL + "competitions/\(competition)/standings"
        guard let url = URL(string: url) else {
            completion(.failure(NSError(domain: "Invalid URL", code: 0, userInfo: nil)))
            return
        }
        
        var request = URLRequest(url: url)
        request.addValue(apiKey, forHTTPHeaderField: "X-Auth-Token")
        
        print("Fetching URL: \(url.absoluteString)")
        
        urlSession.dataTask(with: request) { (data, response, error) in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("HTTP Status Code: \(httpResponse.statusCode)")
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "No data received", code: 0, userInfo: nil)))
                return
            }
            
            do {
                let competitionStandings = try self.jsonDecoder.decode(CompetitionStandings.self, from: data)
                completion(.success(competitionStandings))
            } catch {
                print("JSON Decoding Error: \(error)")
                completion(.failure(error))
            }
        }.resume()
    }
    
    func fetchTeams(for competition: String, completion: @escaping (Result<[Team], Error>) -> Void) {
        let urlString = baseURL + "competitions/\(competition)/teams"
        
        guard let url = URL(string: urlString) else {
            completion(.failure(NSError(domain: "Invalid URL", code: 0, userInfo: nil)))
            return
        }
        
        var request = URLRequest(url: url)
        request.addValue(apiKey, forHTTPHeaderField: "X-Auth-Token")
        
        print("Fetching URL: \(urlString)")
        
        urlSession.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("HTTP Status Code: \(httpResponse.statusCode)")
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "No data received", code: 0, userInfo: nil)))
                return
            }
            
            do {
                let teamsResponse = try self.jsonDecoder.decode(TeamsResponse.self, from: data)
                print("Decoded \(teamsResponse.teams.count) teams")
                completion(.success(teamsResponse.teams))
            } catch {
                print("JSON Decoding Error: \(error)")
                completion(.failure(error))
            }
        }.resume()
    }
}

// MARK: - Models

struct MatchResponse: Codable {
    let matches: [Match]
}

struct Match: Codable, Identifiable {
    let id: Int
    let utcDate: String
    let status: String
    let homeTeam: Team
    let awayTeam: Team
    let score: Score
    let competition: Competition
}

struct Team: Codable, Identifiable, Hashable, Equatable {
    let id: Int
    let name: String
    let shortName: String?
    let tla: String?
    let crest: String?

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Team, rhs: Team) -> Bool {
        lhs.id == rhs.id
    }
}

struct Score: Codable {
    let fullTime: ScoreDetail
}

struct ScoreDetail: Codable {
    let home: Int?
    let away: Int?
}

struct Competition: Codable {
    let id: Int
    let name: String
}

struct CompetitionStandings: Codable {
    let filters: [String: String]
    let competition: Competition
    let season: Season
    let standings: [Standing]
}

struct Standing: Codable, Identifiable {
    let stage: String
    let type: String
    let group: String?
    let table: [Table]
    
    var id: String { stage + type + (group ?? "") }
}

struct Table: Codable, Identifiable {
    let position: Int
    let team: Team
    let playedGames: Int
    let won: Int
    let draw: Int
    let lost: Int
    let points: Int
    let goalsFor: Int
    let goalsAgainst: Int
    let goalDifference: Int
    
    var id: Int { team.id }
}

struct Season: Codable {
    let id: Int
    let startDate: String
    let endDate: String
    let currentMatchday: Int?
}

enum StandingType: String, Codable {
    case total = "TOTAL"
    case home = "HOME"
    case away = "AWAY"
}

struct CompetitionStandingsFiltersOptions {
    let standingType: StandingType
}

struct TeamsResponse: Codable {
    let teams: [Team]
}
