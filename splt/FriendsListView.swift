//import SwiftUI
//import FirebaseAuth
//import FirebaseFirestore
//import FirebaseFirestoreSwift
//
//struct FriendsListView: View {
//    @State private var showAddExpense = false
//    @State private var friends: [Friend] = []
//    @State private var expenses: [Expense] = []
//
//    var body: some View {
//        NavigationView {
//            List {
//                // "Me" Card
//                if let me = friends.first(where: { $0.isCurrentUser }) {
//                    HStack {
//                        Text("Me (\(me.name))")
//                            .fontWeight(.bold)
//                        Spacer()
//                        Text("$\(me.balance, specifier: "%.2f")")
//                            .foregroundColor(me.balance >= 0 ? .green : .red)
//                            .fontWeight(.bold)
//                    }
//                }
//
//                // Other Friends
//                ForEach(friends.filter { !$0.isCurrentUser }) { friend in
//                    HStack {
//                        Text(friend.name)
//                        Spacer()
//                        Text("$\(friend.balance, specifier: "%.2f")")
//                            .foregroundColor(friend.balance >= 0 ? .green : .red)
//                    }
//                }
//            }
//            .navigationBarTitle("Friends")
//            .navigationBarItems(trailing: Button(action: {
//                showAddExpense = true
//            }) {
//                Image(systemName: "plus.circle.fill")
//                    .font(.title)
//            })
//            .sheet(isPresented: $showAddExpense) {
//                AddExpenseView(friends: $friends, expenses: $expenses)
//            }
//            .onAppear {
//                loadCurrentUser()
//                loadFriends()
//            }
//        }
//    }
//
//    // MARK: - Load Current User
//
//    func loadCurrentUser() {
//        guard let user = Auth.auth().currentUser else { return }
//        let email = user.email?.lowercased() ?? ""
//
//        let db = Firestore.firestore()
//        let userRef = db.collection("users").document(email)
//
//        userRef.getDocument { (document, error) in
//            if let document = document, document.exists {
//                do {
//                    if var friend = try document.data(as: Friend.self) {
//                        friend.isCurrentUser = true
//                        if !friends.contains(where: { $0.email.lowercased() == friend.email.lowercased() }) {
//                            friends.append(friend)
//                        }
//                    }
//                } catch {
//                    print("Error decoding user: \(error)")
//                }
//            } else {
//                // Create the user document if it doesn't exist
//                let currentUser = Friend(
//                    id: email,
//                    name: user.displayName ?? "You",
//                    email: email,
//                    balance: 0.0,
//                    isCurrentUser: true
//                )
//                do {
//                    try userRef.setData(from: currentUser)
//                    friends.append(currentUser)
//                } catch {
//                    print("Error adding current user: \(error)")
//                }
//            }
//        }
//    }
//
//    // MARK: - Load Friends
//
//    func loadFriends() {
//        let db = Firestore.firestore()
//        db.collection("users").addSnapshotListener { (snapshot, error) in
//            if let error = error {
//                print("Error fetching friends: \(error)")
//                return
//            }
//
//            var newFriends: [Friend] = []
//
//            snapshot?.documents.forEach { document in
//                do {
//                    if var friend = try document.data(as: Friend.self) {
//                        // Identify current user
//                        if friend.email.lowercased() == Auth.auth().currentUser?.email?.lowercased() {
//                            friend.isCurrentUser = true
//                        }
//                        newFriends.append(friend)
//                    }
//                } catch {
//                    print("Error decoding friend: \(error)")
//                }
//            }
//
//            self.friends = newFriends
//        }
//    }
//}
