//import SwiftUI
//import FirebaseAuth
//
//struct PhoneVerificationView: View {
//    @State private var phoneNumber = ""
//    @State private var verificationCode = ""
//    @State private var verificationID: String?
//    @State private var isShowingVerificationField = false
//    @State private var errorMessage = ""
//    @Binding var isVerified: Bool
//
//    var body: some View {
//        VStack(spacing: 20) {
//            Text("Verify Your Phone Number")
//                .font(.title)
//                .foregroundColor(.white)
//
//            TextField("Phone Number", text: $phoneNumber)
//                .keyboardType(.phonePad)
//                .padding()
//                .background(Color.white.opacity(0.2))
//                .cornerRadius(8)
//
//            if isShowingVerificationField {
//                TextField("Verification Code", text: $verificationCode)
//                    .keyboardType(.numberPad)
//                    .padding()
//                    .background(Color.white.opacity(0.2))
//                    .cornerRadius(8)
//            }
//
//            Button(action: isShowingVerificationField ? verifyCode : sendVerificationCode) {
//                Text(isShowingVerificationField ? "Verify Code" : "Send Code")
//                    .foregroundColor(.white)
//                    .padding()
//                    .frame(maxWidth: .infinity)
//                    .background(Color.blue)
//                    .cornerRadius(8)
//            }
//
//            if !errorMessage.isEmpty {
//                Text(errorMessage)
//                    .foregroundColor(.red)
//            }
//        }
//        .padding()
//        .background(BackgroundView())
//    }
//
//    func sendVerificationCode() {
//        PhoneAuthProvider.provider().verifyPhoneNumber(phoneNumber, uiDelegate: nil) { verificationID, error in
//            if let error = error {
//                self.errorMessage = error.localizedDescription
//                return
//            }
//            self.verificationID = verificationID
//            self.isShowingVerificationField = true
//        }
//    }
//
//    func verifyCode() {
//        guard let verificationID = verificationID else { return }
//        let credential = PhoneAuthProvider.provider().credential(
//            withVerificationID: verificationID,
//            verificationCode: verificationCode
//        )
//        
//        Auth.auth().currentUser?.link(with: credential) { authResult, error in
//            if let error = error {
//                self.errorMessage = error.localizedDescription
//                return
//            }
//            // Phone number verified and linked to the account
//            self.isVerified = true
//        }
//    }
//}//
////  PhoneVerificationView.swift
////  splt
////
////  Created by Rohan Y J on 10/7/24.
////
//
