import SwiftUI
import Firebase
import FirebaseAuth
import AuthenticationServices
import CryptoKit
import GoogleSignIn

struct ContentView: View {
    @State private var currentNonce: String?
    @State private var isUserSignedIn = false
    @State private var appleSignInDelegates: SignInWithAppleCoordinator?

    var body: some View {
        if isUserSignedIn {
            MatchesView(isUserSignedIn: $isUserSignedIn)
        } else {
            signInView
        }
    }
    
    var signInView: some View {
        ZStack {
            // Dark background
            BackgroundView()
            
            VStack(spacing: 20) {
                Spacer()
                
                // App Title or Logo
                Text("splt.")
                    .font(.custom("BebasNeue-Regular", size: 50))
                    .foregroundColor(.white)
                    .padding(.bottom, 40)
                
                // Custom Sign In with Apple Button
                CustomSignInWithAppleButton(action: {
                    startSignInWithAppleFlow()
                })
                .padding(.bottom, 10)
                
                // Custom Google Sign-In Button
                SignInWithGoogleButton(action: signInWithGoogle)
                    .padding(.bottom, 10)
                
                Spacer()
            }
            .padding()
        }
        .onAppear {
            if Auth.auth().currentUser != nil {
                self.isUserSignedIn = true
            }
        }
    }
    // MARK: - Sign In with Apple Handlers

    func startSignInWithAppleFlow() {
        let nonce = randomNonceString()
        currentNonce = nonce
        
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
        
        let coordinator = SignInWithAppleCoordinator(currentNonce: currentNonce) { result in
            switch result {
            case .success(let authResults):
                handleSignInWithAppleCompletion(authResults)
            case .failure(let error):
                print("Authorization failed: \(error.localizedDescription)")
            }
        }
        self.appleSignInDelegates = coordinator
        
        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = coordinator
        authorizationController.presentationContextProvider = coordinator
        authorizationController.performRequests()
    }

    func handleSignInWithAppleCompletion(_ authResults: ASAuthorization) {
        if let appleIDCredential = authResults.credential as? ASAuthorizationAppleIDCredential {
            guard let nonce = currentNonce else {
                fatalError("Invalid state: A login callback was received, but no login request was sent.")
            }
            guard let appleIDToken = appleIDCredential.identityToken else {
                print("Unable to fetch identity token")
                return
            }
            guard let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
                print("Unable to serialize token string from data: \(appleIDToken.debugDescription)")
                return
            }
            // Initialize a Firebase credential.
            let credential = OAuthProvider.credential(withProviderID: "apple.com", idToken: idTokenString, rawNonce: nonce)
            // Sign in with Firebase.
            Auth.auth().signIn(with: credential) { (authResult, error) in
                if let error = error {
                    // Error handling
                    print("Firebase Sign In with Apple error: \(error.localizedDescription)")
                    return
                }
                // User is signed in
                print("Successfully signed in with Apple: \(authResult?.user.uid ?? "")")
                self.isUserSignedIn = true
            }
        }
    }
    
    // MARK: - Google Sign-In Handler

    func signInWithGoogle() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            print("There is no root view controller!")
            return
        }
        
        GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController) { signInResult, error in
            if let error = error {
                print("Error during Google Sign-In: \(error.localizedDescription)")
                return
            }
            
            guard let user = signInResult?.user,
                  let idToken = user.idToken?.tokenString else {
                print("Failed to get authentication object from Google user.")
                return
            }
            
            let accessToken = user.accessToken.tokenString
            
            let credential = GoogleAuthProvider.credential(withIDToken: idToken,
                                                           accessToken: accessToken)
            
            // Sign in with Firebase.
            Auth.auth().signIn(with: credential) { authResult, error in
                if let error = error {
                    print("Firebase Sign-In error: \(error.localizedDescription)")
                } else {
                    print("User signed in with Google: \(authResult?.user.email ?? "")")
                    self.isUserSignedIn = true
                }
            }
        }
    }
}

// MARK: - SignInWithAppleCoordinator

class SignInWithAppleCoordinator: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    var currentNonce: String?
    var completion: (Result<ASAuthorization, Error>) -> Void
    
    init(currentNonce: String?, completion: @escaping (Result<ASAuthorization, Error>) -> Void) {
        self.currentNonce = currentNonce
        self.completion = completion
    }
    
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let window = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .flatMap({ $0.windows })
                .first(where: { $0.isKeyWindow }) else {
            fatalError("No key window found")
        }
        return window
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        completion(.success(authorization))
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        completion(.failure(error))
    }
}

// MARK: - Custom Sign In with Apple Button

struct CustomSignInWithAppleButton: View {
    var action: () -> Void

    var body: some View {
        Button(action: {
            self.action()
        }) {
            HStack {
                Image(systemName: "applelogo")
                    .font(.system(size: 24))
                    .foregroundColor(.white)
                Text("Sign in with Apple")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [Color.black, Color.gray]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(12)
            .shadow(color: Color.white.opacity(0.2), radius: 5, x: 0, y: 5)
        }
        .frame(width: 280, height: 50)
    }
}

// MARK: - Custom Sign In with Google Button

struct SignInWithGoogleButton: View {
    var action: () -> Void

    var body: some View {
        Button(action: {
            self.action()
        }) {
            HStack {
                Image("google_logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                Text("Sign in with Google")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 219/255, green: 68/255, blue: 55/255),
                        Color(red: 244/255, green: 180/255, blue: 0/255)
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(12)
            .shadow(color: Color.red.opacity(0.4), radius: 5, x: 0, y: 5)
        }
        .frame(width: 280, height: 50)
    }
}

// MARK: - Background View

struct BackgroundView: View {
    var body: some View {
        LinearGradient(
            gradient: Gradient(colors: [Color.black, Color(white: 0.1), Color(white: 0.2)]),
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

// MARK: - Helper Functions

func randomNonceString(length: Int = 32) -> String {
    precondition(length > 0)
    let charset: [Character] =
        Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
    var result = ""
    var remainingLength = length

    while remainingLength > 0 {
        var randoms = [UInt8](repeating: 0, count: 16)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randoms.count, &randoms)
        if errorCode != errSecSuccess {
            fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
        }

        randoms.forEach { random in
            if remainingLength == 0 {
                return
            }

            if random < charset.count {
                result.append(charset[Int(random % UInt8(charset.count))])
                remainingLength -= 1
            }
        }
    }

    return result
}

@available(iOS 13, *)
func sha256(_ input: String) -> String {
    let inputData = Data(input.utf8)
    let hashedData = SHA256.hash(data: inputData)
    let hashString = hashedData.compactMap { String(format: "%02x", $0) }.joined()
    return hashString
}
