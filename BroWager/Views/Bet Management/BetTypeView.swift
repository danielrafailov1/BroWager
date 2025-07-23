import SwiftUI

struct BetTypeView: View {
    @Binding var navPath: NavigationPath
    @Environment(\.dismiss) private var dismiss
    @State private var selectedBetType: BetType?
    let email: String
    @State private var showProfile = false
    @State private var profileImage: Image? = nil
    @Environment(\.supabaseClient) private var supabaseClient
    @State private var tutorialBetType: BetType? = nil
    
    enum BetType: String, CaseIterable, Identifiable {
        case sports = "Sports"
        case politics = "Politics"
        case food = "Food"
        case lifeEvents = "Life Events"
        case custom = "Create Your Own"
        
        var id: String { rawValue }
        
        var icon: String {
            switch self {
            case .sports: return "sportscourt.fill"
            case .politics: return "building.columns.fill"
            case .food: return "fork.knife"
            case .lifeEvents: return "heart.fill"
            case .custom: return "wand.and.stars"
            }
        }
        
        var description: String {
            switch self {
            case .sports: return "Bet on sports games and events"
            case .politics: return "Bet on political events and outcomes"
            case .food: return "Bet on food challenges and competitions"
            case .lifeEvents: return "Bet on personal life milestones"
            case .custom: return "Create your own custom bet type"
            }
        }
        
        var isEnabled: Bool {
            switch self {
            case .sports: return true
            case .politics: return true
            case .food: return true
            case .lifeEvents: return true
            case .custom: return true
            }
        }
    }
    
    enum BetTypePath: Hashable {
        case sports
        case politics
        case food
        case lifeEvents
        case custom
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
            
            VStack(spacing: 32) {
                // Header
                VStack(spacing: 8) {
                    Text("Choose Bet Type")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("Select the type of bet you want to make")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.top, 16)
                
                // Bet Type Options
                ScrollView {
                    VStack(spacing: 24) {
                        ForEach(BetType.allCases, id: \ .self) { betType in
                            if betType.isEnabled {
                                switch betType {
                                case .sports:
                                    NavigationLink(value: BetTypePath.sports) {
                                        BetTypeCard(betType: betType, showTutorial: { tutorialBetType = betType })
                                    }
                                case .politics:
                                    NavigationLink(value: BetTypePath.politics) {
                                        BetTypeCard(betType: betType, showTutorial: { tutorialBetType = betType })
                                    }
                                case .food:
                                    NavigationLink(value: BetTypePath.food) {
                                        BetTypeCard(betType: betType, showTutorial: { tutorialBetType = betType })
                                    }
                                case .lifeEvents:
                                    NavigationLink(value: BetTypePath.lifeEvents) {
                                        BetTypeCard(betType: betType, showTutorial: { tutorialBetType = betType })
                                    }
                                case .custom:
                                    NavigationLink(value: BetTypePath.custom) {
                                        BetTypeCard(betType: betType, showTutorial: { tutorialBetType = betType })
                                    }
                                }
                            } else {
                                BetTypeCard(betType: betType, showTutorial: { tutorialBetType = betType })
                                    .opacity(0.5)
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                }
                
                Spacer()
            }
            .navigationDestination(for: BetTypePath.self) { path in
                switch path {
                case .sports:
                    SportSelectionView(navPath: $navPath, email: email)
                case .politics:
                    PoliticsBetView()
                case .food:
                    TimedBetSettingView()
                case .lifeEvents:
                    LifeEventsBetView()
                case .custom:
                    CustomBetView(email: email)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
        }
        .sheet(isPresented: $showProfile) {
            ProfileView(navPath: $navPath, email: email)
        }
        .sheet(item: $tutorialBetType) { betType in
            VStack(spacing: 24) {
                Image(systemName: betType.icon)
                    .font(.system(size: 48))
                    .foregroundColor(.blue)
                    .padding(.top, 32)
                Text(betType.rawValue)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                Text(betType.description)
                    .font(.system(size: 18))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                Spacer()
                Button("Got it!") { tutorialBetType = nil }
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.vertical, 14)
                    .padding(.horizontal, 48)
                    .background(Color.blue)
                    .cornerRadius(14)
                    .padding(.bottom, 32)
            }
            .presentationDetents([.medium, .large])
        }
        .onAppear {
            Task {
                profileImage = await fetchProfileImage(for: email, supabaseClient: supabaseClient)
            }
        }
    }
}

struct BetTypeCard: View {
    let betType: BetTypeView.BetType
    var showTutorial: () -> Void = {}
    
    var body: some View {
        HStack(alignment: .top, spacing: 20) {
            Image(systemName: betType.icon)
                .font(.system(size: 32))
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.blue,
                            Color.blue.opacity(0.8)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .center, spacing: 8) {
                    Text(betType.rawValue)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    Button(action: showTutorial) {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.blue)
                            .font(.system(size: 20))
                    }
                    .buttonStyle(.plain)
                }
                Text(betType.description)
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.8))
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            if betType.isEnabled {
                Image(systemName: "chevron.right")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
            } else {
                Image(systemName: "lock.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.07))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.13), lineWidth: 1.5)
                )
        )
        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
    }
}

#Preview {
    NavigationView {
        BetTypeView(navPath: .constant(NavigationPath()), email: "test@example.com")
    }
} 
