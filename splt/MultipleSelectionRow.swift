//import SwiftUI
//
//struct MultipleSelectionRow: View {
//    var friend: Friend
//    var isSelected: Bool
//    var action: () -> Void
//
//    var body: some View {
//        Button(action: {
//            self.action()
//        }) {
//            HStack {
//                Text(friend.isCurrentUser ? "Me (\(friend.name))" : friend.name)
//                if isSelected {
//                    Spacer()
//                    Image(systemName: "checkmark")
//                        .foregroundColor(.blue)
//                }
//            }
//        }
//    }
//}
