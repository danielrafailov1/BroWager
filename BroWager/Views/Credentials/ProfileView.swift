import Foundation
import SwiftUI
import PhotosUI
import Auth

struct ProfileView: View {
    
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var profileImage: Image? = nil
    @State private var profileUIImage: UIImage? = nil
    
    @Binding var navPath: NavigationPath
    
    @Environment(\.supabaseClient) private var supabaseClient
    @State private var isUploading = false
    @State private var uploadError: String? = nil
    @State private var userId: String? = nil
    @State private var tokenBalance: Int? = nil
    @State private var username: String = ""
    @State private var identifier: String = ""

    // Editing states
    @State private var isEditingUsername = false
    @State private var newUsername: String = ""
    @State private var isEditingEmail = false
    @State private var showChangePassword = false
    @State private var currentEmail: String
    @State private var updateMessage: String?
    @State private var isErrorUpdate: Bool = false
    
    // New states for inline password editing
    @State private var isEditingPassword = false
    @State private var newPassword = ""

    @State private var friends: [String] = []

    @EnvironmentObject var sessionManager: SessionManager

    init(navPath: Binding<NavigationPath>, email: String) {
        _navPath = navPath
        _currentEmail = State(initialValue: email)
    }

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.1, green: 0.1, blue: 0.2),
                    Color(red: 0.15, green: 0.15, blue: 0.25)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 32) {
                    profileHeader
                    
                    if tokenBalance != nil {
                        tokenBalanceView
                    }
                    
                    // Account Info Section
                    accountInfoSection
                    
                    // Friends Section (moved below account info)
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Friends")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            Spacer()
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 8)
                        if friends.isEmpty {
                            Text("No friends yet.")
                                .foregroundColor(.white.opacity(0.5))
                                .font(.system(size: 16))
                                .padding(.horizontal, 24)
                        } else {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 16) {
                                    ForEach(friends, id: \.self) { friend in
                                        VStack(spacing: 8) {
                                            Image(systemName: "person.crop.circle.fill")
                                                .resizable()
                                                .frame(width: 48, height: 48)
                                                .foregroundColor(.blue)
                                            Text(friend)
                                                .font(.system(size: 16, weight: .medium))
                                                .foregroundColor(.white)
                                                .lineLimit(1)
                                                .truncationMode(.tail)
                                        }
                                        .padding(12)
                                        .background(Color.white.opacity(0.08))
                                        .cornerRadius(16)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16)
                                                .stroke(Color.white.opacity(0.15), lineWidth: 1)
                                        )
                                    }
                                }
                                .padding(.horizontal, 24)
                                .padding(.vertical, 8)
                            }
                        }
                    }
                    .padding(.bottom, 8)
                    
                    if let message = updateMessage {
                        Text(message)
                            .foregroundColor(isErrorUpdate ? .red : .green)
                            .padding()
                    }
                    
                    logoutButton
                }
            }
            .onChange(of: selectedItem) { newItem in
                Task {
                    guard let data = try? await newItem?.loadTransferable(type: Data.self),
                          let uiImage = UIImage(data: data) else {
                        return
                    }
                    
                    profileUIImage = uiImage
                    profileImage = Image(uiImage: uiImage)
                    // Upload to Supabase
                    isUploading = true
                    uploadError = nil
                    do {
                        // Get user_id if not already fetched
                        if userId == nil {
                            userId = try await fetchUserId()
                        }
                        guard let userId = userId else {
                            uploadError = "Could not fetch user ID."
                            isUploading = false
                            return
                        }
                        let manager = ProfileManager(supabaseClient: supabaseClient)
                        let _ = try await manager.uploadProfileImageAndSaveURL(for: userId, image: uiImage)
                        isUploading = false
                    } catch {
                        uploadError = "Upload failed: \(error.localizedDescription)"
                        isUploading = false
                    }
                }
            }
            .task {
                await fetchUserProfile()
            }
        }
    }

    // MARK: - Subviews
    
    private var profileHeader: some View {
        VStack(spacing: 16) {
            // Profile Image
            ZStack {
                if let image = profileImage {
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 120, height: 120)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color.white.opacity(0.8),
                                            Color.white.opacity(0.4)
                                        ]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 4
                                )
                        )
                } else {
                    Image(systemName: "person.crop.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 120, height: 120)
                        .foregroundColor(.white.opacity(0.8))
                }
                
                // Change Photo Button
                PhotosPicker(
                    selection: $selectedItem,
                    matching: .images,
                    photoLibrary: .shared()
                ) {
                    Image(systemName: "camera.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.white)
                        .background(Color.blue)
                        .clipShape(Circle())
                }
                .offset(x: 40, y: 40)
            }
            
            Text("Change Profile Picture")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
            if isUploading {
                ProgressView("Uploading...")
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
            }
            if let uploadError = uploadError {
                Text(uploadError)
                    .foregroundColor(.red)
            }
        }
        .padding(.top, 32)
    }
    
    private var tokenBalanceView: some View {
        HStack {
            Image(systemName: "dollarsign.circle.fill")
                .font(.system(size: 24))
                .foregroundColor(.yellow)
            Text("Token Balance: \(tokenBalance ?? 0)")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
            Spacer()
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(12)
        .padding(.horizontal, 24)
    }
    
    private var accountInfoSection: some View {
        VStack(spacing: 24) {
            // Section Header
            HStack {
                Text("Account Info")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Spacer()
            }
            .padding(.horizontal, 24)
            
            // Username Field
            EditableInfoRow(
                title: "Username",
                value: $username,
                isEditing: $isEditingUsername,
                onSave: { updatedUsername in
                    Task { await updateUsername(newUsername: updatedUsername) }
                },
                identifier: identifier
            )
            
            // Email Field
            EditableInfoRow(
                title: "Email",
                value: $currentEmail,
                isEditing: $isEditingEmail,
                onSave: { updatedEmail in
                    Task { await updateUserEmail(newEmail: updatedEmail) }
                }
            )
            
            // New Editable Password Row
            EditablePasswordRow(
                isEditing: $isEditingPassword,
                password: $newPassword,
                onSave: { updatedPassword in
                    Task { await updatePassword(newPassword: updatedPassword) }
                }
            )
        }
    }
    
    private var logoutButton: some View {
        Button(action: {
            Task {
                await sessionManager.signOut()
                navPath = NavigationPath()
            }
        }) {
            HStack {
                Image(systemName: "arrow.right.square.fill")
                    .font(.system(size: 20))
                Text("Logout")
                    .font(.system(size: 18, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.red,
                        Color.red.opacity(0.8)
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(16)
            .shadow(color: Color.red.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 32)
    }

    // MARK: - Functions
    private func fetchUserProfile() async {
        do {
            var fetchedUserId: String? = nil
            // Prefer user_id from sessionManager if available
            if let sessionUserId = sessionManager.newUserId {
                fetchedUserId = sessionUserId
                print("[ProfileView] Using userId from sessionManager: \(sessionUserId)")
            } else {
                // Fallback: fetch user_id from Login Information by email
                let response = try await supabaseClient
                    .from("Login Information")
                    .select("user_id")
                    .eq("email", value: currentEmail)
                    .limit(1)
                    .execute()
                struct UserIdRow: Decodable { let user_id: String }
                let userRows = try JSONDecoder().decode([UserIdRow].self, from: response.data)
                guard let userRow = userRows.first else {
                    throw URLError(.cannotDecodeContentData)
                }
                fetchedUserId = userRow.user_id
                print("[ProfileView] Fallback loaded userId: \(fetchedUserId ?? "nil")")
            }
            guard let userId = fetchedUserId else { throw URLError(.userAuthenticationRequired) }
            await MainActor.run { self.userId = userId }

            // Fetch email from Login Information
            let emailResponse = try await supabaseClient
                .from("Login Information")
                .select("email")
                .eq("user_id", value: userId)
                .limit(1)
                .execute()
            struct EmailRow: Decodable { let email: String }
            let emailRows = try JSONDecoder().decode([EmailRow].self, from: emailResponse.data)
            let fetchedEmail = emailRows.first?.email ?? ""
            await MainActor.run { self.currentEmail = fetchedEmail }

            // Fetch username, token balance, profile image, and friends in parallel
            async let usernameTask = fetchUsernameAndIdentifier(for: userId)
            async let tokenBalanceTask = fetchTokenBalance(for: userId)
            async let profileImageTask = fetchAndLoadProfileImage(for: userId)
            async let friendsTask = fetchFriends(for: userId)

            let (fetchedUsername, fetchedIdentifier) = await (try? usernameTask) ?? ("", "")
            let fetchedTokenBalance = await (try? tokenBalanceTask) ?? 0
            let loadedImage = await (try? profileImageTask)
            let fetchedFriends = await (try? friendsTask) ?? []

            print("[ProfileView] Username: \(fetchedUsername), TokenBalance: \(fetchedTokenBalance)")

            await MainActor.run {
                self.username = fetchedUsername
                self.identifier = fetchedIdentifier
                self.tokenBalance = fetchedTokenBalance
                if let (uiImage, image) = loadedImage {
                    self.profileUIImage = uiImage
                    self.profileImage = image
                }
                self.friends = fetchedFriends
                self.isErrorUpdate = false
                self.updateMessage = nil
            }
        } catch {
            print("❌ Error fetching user profile: \(error.localizedDescription)")
            await MainActor.run {
                self.isErrorUpdate = true
                self.updateMessage = "Error loading profile. Please try again."
            }
        }
    }

    private func updateUsername(newUsername: String) async {
        guard let userId = userId, !newUsername.isEmpty else { return }
        do {
            try await supabaseClient
                .from("Username")
                .update(["username": newUsername])
                .eq("user_id", value: userId)
                .execute()
            
            await MainActor.run {
                self.username = newUsername
                self.isEditingUsername = false
            }
        } catch {
            print("❌ Error updating username: \(error.localizedDescription)")
        }
    }

    private func updateUserEmail(newEmail: String) async {
        guard !newEmail.isEmpty, newEmail != currentEmail else { return }
        
        do {
            try await supabaseClient.auth.update(
                user: UserAttributes(email: newEmail)
            )
            
            // Also update the Login Information table
            try await supabaseClient
                .from("Login Information")
                .update(["email": newEmail])
                .eq("user_id", value: userId!)
                .execute()

            await MainActor.run {
                self.currentEmail = newEmail
                self.isEditingEmail = false
                self.isErrorUpdate = false
                self.updateMessage = "Confirmation email sent to \(newEmail). Please verify to complete the change."
            }
        } catch {
            await MainActor.run {
                self.isErrorUpdate = true
                self.updateMessage = "Error updating email: \(error.localizedDescription)"
            }
        }
    }

    private func updatePassword(newPassword: String) async {
        guard !newPassword.isEmpty else {
            await MainActor.run {
                self.isErrorUpdate = true
                self.updateMessage = "Password cannot be empty."
            }
            return
        }

        do {
            try await supabaseClient.auth.update(user: UserAttributes(password: newPassword))
            await MainActor.run {
                self.isEditingPassword = false
                self.newPassword = ""
                self.isErrorUpdate = false
                self.updateMessage = "Password updated successfully!"
            }
        } catch {
            await MainActor.run {
                self.isErrorUpdate = true
                self.updateMessage = "Error updating password: \(error.localizedDescription)"
            }
        }
    }

    // Helper to fetch user_id from Login Information
    func fetchUserId() async throws -> String? {
        struct UserIdResponse: Decodable { let user_id: String }
        let response: UserIdResponse = try await supabaseClient
            .from("Login Information")
            .select("user_id")
            .eq("email", value: currentEmail)
            .limit(1)
            .execute()
            .value
        return response.user_id
    }
    
    func fetchTokenBalance(for userId: String) async throws -> Int? {
        do {
            print("[fetchTokenBalance] Fetching for userId: \(userId)")
            struct UserTokenBalance: Codable { let balance: Double }
            let response: [UserTokenBalance] = try await supabaseClient
                .from("User Tokens")
                .select("balance")
                .eq("user_id", value: userId)
                .limit(1)
                .execute()
                .value
            print("[fetchTokenBalance] Raw response: \(response)")
            let balance = response.first.map { Int($0.balance) } ?? 0
            print("[fetchTokenBalance] Decoded balance: \(balance)")
            return balance
        } catch {
            print("[fetchTokenBalance] Error: \(error)")
            return 0
        }
    }

    func fetchUsernameAndIdentifier(for userId: String) async throws -> (String, String) {
        do {
            let response: [UsernameRow] = try await supabaseClient
                .from("Username")
                .select("username, identifier")
                .eq("user_id", value: userId)
                .limit(1)
                .execute()
                .value
            let uname = response.first?.username ?? ""
            let ident = response.first?.identifier ?? ""
            return (uname, ident)
        } catch {
            return ("", "")
        }
    }
    
    func fetchAndLoadProfileImage(for userId: String) async throws -> (UIImage, Image)? {
        let manager = ProfileManager(supabaseClient: supabaseClient)
        guard let urlString = try await manager.fetchProfileImageURL(for: userId),
              let url = URL(string: urlString + "?t=\(Int(Date().timeIntervalSince1970))") else {
            return nil
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        if let uiImage = UIImage(data: data) {
            return (uiImage, Image(uiImage: uiImage))
        }
        return nil
    }

    // Fetch friends' usernames for the user
    func fetchFriends(for userId: String) async throws -> [String] {
        // Get all accepted friends where user is either user_id or friend_id
        let friendsResp = try await supabaseClient
            .from("Friends")
            .select("user_id, friend_id, status")
            .or("user_id.eq.\(userId),friend_id.eq.\(userId)")
            .eq("status", value: "accepted")
            .execute()
        struct FriendRow: Decodable { let user_id: String; let friend_id: String }
        let arr = try JSONDecoder().decode([FriendRow].self, from: friendsResp.data)
        // Get the other user's id
        let friendIds = arr.map { $0.user_id == userId ? $0.friend_id : $0.user_id }
        if friendIds.isEmpty { return [] }
        // Fetch usernames for all friendIds
        let usernamesResp = try await supabaseClient
            .from("Username")
            .select("user_id, username")
            .in("user_id", values: friendIds)
            .execute()
        struct UsernameRow: Decodable { let user_id: String; let username: String }
        let usernamesArr = try JSONDecoder().decode([UsernameRow].self, from: usernamesResp.data)
        return usernamesArr.map { $0.username }
    }
}

// A reusable view for displaying static info
struct InfoRow: View {
    let icon: String
    let value: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.white.opacity(0.7))
                .frame(width: 24)
            
            Text(value)
                .font(.system(size: 16))
                .foregroundColor(.white)
                .lineLimit(1)
                .truncationMode(.middle)
            
            Spacer()
        }
        .padding(16)
        .background(Color.white.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal, 24)
    }
}

// A reusable view for editable fields
struct EditableInfoRow: View {
    let title: String
    @Binding var value: String
    @Binding var isEditing: Bool
    let onSave: (String) -> Void
    var identifier: String? = nil
    
    @State private var draftValue: String = ""

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white.opacity(0.7))
                .frame(width: 80, alignment: .leading)

            if isEditing {
                TextField(title, text: $draftValue)
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: {
                    onSave(draftValue)
                    isEditing = false
                }) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
                
                Button(action: {
                    isEditing = false
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                }
            } else {
                if title == "Email" {
                    Text(value)
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                } else if let identifier = identifier, !identifier.isEmpty {
                    Text("\(value)#\(identifier)")
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                } else {
                    Text(value)
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                }
                Spacer()
                Button(action: {
                    draftValue = value
                    isEditing = true
                }) {
                    Text("Edit")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.blue)
                }
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal, 24)
    }
}

// A reusable view for an editable password field
struct EditablePasswordRow: View {
    @Binding var isEditing: Bool
    @Binding var password: String
    let onSave: (String) -> Void
    
    @State private var isPasswordVisible = false

    var body: some View {
        HStack(spacing: 12) {
            Text("Password")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white.opacity(0.7))
                .frame(width: 80, alignment: .leading)

            if isEditing {
                if isPasswordVisible {
                    TextField("New Password", text: $password)
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                } else {
                    SecureField("New Password", text: $password)
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                }

                Button(action: { isPasswordVisible.toggle() }) {
                    Image(systemName: isPasswordVisible ? "eye.slash.fill" : "eye.fill")
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Spacer()

                Button(action: {
                    onSave(password)
                }) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.green)
                }
                
                Button(action: {
                    isEditing = false
                    password = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.red)
                }
            } else {
                Text("••••••••••")
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: {
                    password = ""
                    isEditing = true
                }) {
                    Text("Edit")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.blue)
                }
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal, 24)
    }
}

#Preview {
    // This preview will require a mock navigation path to work correctly.
    // For now, it shows the basic layout.
    ProfileView(
        navPath: .constant(NavigationPath()),
        email: "test@example.com"
    )
}

struct UsernameRow: Codable {
    let username: String?
    let identifier: String?
}
