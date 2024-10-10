//import FirebaseFirestore
//import FirebaseFirestoreSwift
//import SwiftUI
//
//struct AddExpenseView: View {
//    @Environment(\.presentationMode) var presentationMode
//    @Binding var friends: [Friend]
//    @Binding var expenses: [Expense]
//
//    @State private var activityName: String = ""
//    @State private var amount: String = ""
//    @State private var selectedParticipants: [Friend] = []
//    @State private var paidBy: Friend?
//    @State private var showAddParticipant = false
//    @State private var errorMessage: String?
//
//    var body: some View {
//        NavigationView {
//            Form {
//                Section(header: Text("Activity")) {
//                    TextField("Activity Name", text: $activityName)
//                    TextField("Amount", text: $amount)
//                        .keyboardType(.decimalPad)
//                }
//
//                Section(header: Text("Participants")) {
//                    ForEach(friends) { friend in
//                        MultipleSelectionRow(
//                            friend: friend,
//                            isSelected: isSelected(friend),
//                            action: {
//                                toggleSelection(for: friend)
//                            }
//                        )
//                    }
//                    Button(action: {
//                        showAddParticipant = true
//                    }) {
//                        Text("Add Participant")
//                    }
//                }
//
//                if !selectedParticipants.isEmpty {
//                    Section(header: Text("Paid By")) {
//                        Picker("Paid By", selection: $paidBy) {
//                            ForEach(selectedParticipants) { participant in
//                                Text(participant.isCurrentUser ? "Me (\(participant.name))" : participant.name)
//                                    .tag(participant)
//                            }
//                        }
//                    }
//                }
//
//                if let errorMessage = errorMessage {
//                    Section {
//                        Text(errorMessage)
//                            .foregroundColor(.red)
//                    }
//                }
//            }
//            .navigationBarTitle("Add Expense", displayMode: .inline)
//            .navigationBarItems(leading: Button("Cancel") {
//                presentationMode.wrappedValue.dismiss()
//            }, trailing: Button("Save") {
//                saveExpense()
//            })
//            .sheet(isPresented: $showAddParticipant) {
//                AddParticipantView(friends: $friends)
//            }
//        }
//    }
//
//    // MARK: - Helper Functions
//
//    func isSelected(_ friend: Friend) -> Bool {
//        selectedParticipants.contains(where: { $0.id == friend.id })
//    }
//
//    func toggleSelection(for friend: Friend) {
//        if let index = selectedParticipants.firstIndex(where: { $0.id == friend.id }) {
//            selectedParticipants.remove(at: index)
//        } else {
//            selectedParticipants.append(friend)
//        }
//    }
//
//    func saveExpense() {
//        guard let totalAmount = Double(amount),
//              !activityName.isEmpty,
//              !selectedParticipants.isEmpty,
//              let payer = paidBy else {
//            errorMessage = "Please fill all fields and select participants and payer."
//            return
//        }
//
//        let db = Firestore.firestore()
//
//        // Prepare expense data
//        let participantEmails = selectedParticipants.map { $0.email.lowercased() }
//        let expense = Expense(
//            activityName: activityName,
//            amount: totalAmount,
//            participants: participantEmails,
//            paidBy: payer.email.lowercased(),
//            timestamp: Date()
//        )
//
//        do {
//            // Add expense to Firestore
//            let _ = try db.collection("expenses").addDocument(from: expense)
//
//            // Update balances for each participant
//            let splitAmount = totalAmount / Double(selectedParticipants.count)
//            for participant in selectedParticipants {
//                let email = participant.email.lowercased()
//                let userRef = db.collection("users").document(email)
//
//                db.runTransaction { (transaction, errorPointer) -> Any? in
//                    let userDoc: DocumentSnapshot
//                    do {
//                        try userDoc = transaction.getDocument(userRef)
//                    } catch let error as NSError {
//                        errorPointer?.pointee = error
//                        return nil
//                    }
//
//                    var balance = userDoc.data()?["balance"] as? Double ?? 0.0
//                    if email == payer.email.lowercased() {
//                        balance += totalAmount - splitAmount
//                    } else {
//                        balance -= splitAmount
//                    }
//
//                    transaction.updateData(["balance": balance], forDocument: userRef)
//                    return nil
//                } completion: { (_, error) in
//                    if let error = error {
//                        print("Error updating balance for \(email): \(error.localizedDescription)")
//                    } else {
//                        print("Successfully updated balance for \(email)")
//                    }
//                }
//            }
//
//            presentationMode.wrappedValue.dismiss()
//        } catch {
//            print("Error adding expense: \(error.localizedDescription)")
//        }
//    }
//}
