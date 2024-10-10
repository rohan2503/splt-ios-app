//import SwiftUI
//
//struct AddParticipantView: View {
//    @Environment(\.presentationMode) var presentationMode
//    @Binding var friends: [Friend]
//    @State private var name: String = ""
//    @State private var email: String = ""
//    @State private var errorMessage: String?
//
//    var body: some View {
//        NavigationView {
//            Form {
//                Section(header: Text("Participant Info")) {
//                    TextField("Name", text: $name)
//                    TextField("Email", text: $email)
//                        .keyboardType(.emailAddress)
//                }
//                if let errorMessage = errorMessage {
//                    Text(errorMessage)
//                        .foregroundColor(.red)
//                }
//            }
//            .navigationBarTitle("Add Participant", displayMode: .inline)
//            .navigationBarItems(leading: Button("Cancel") {
//                presentationMode.wrappedValue.dismiss()
//            }, trailing: Button("Add") {
//                addParticipant()
//            })
//        }
//    }
//    
//    func addParticipant() {
//        guard !name.isEmpty, !email.isEmpty else {
//            errorMessage = "Please enter both name and email."
//            return
//        }
//        
//        // Prevent adding a participant with the same email as existing friends
//        if friends.contains(where: { $0.email.lowercased() == email.lowercased() }) {
//            errorMessage = "This email is already in your friends list."
//            return
//        }
//        
//        let newFriend = Friend(name: name, email: email, balance: 0.0)
//        friends.append(newFriend)
//        presentationMode.wrappedValue.dismiss()
//    }
//}
