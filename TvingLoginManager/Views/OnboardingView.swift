import SwiftUI

struct OnboardingPage: Identifiable, Sendable {
    let id: Int
    let imageName: String
    let titleKey: String
    let descriptionKey: String
}

private let onboardingPages: [OnboardingPage] = [
    OnboardingPage(
        id: 0,
        imageName: "onboarding_welcome",
        titleKey: "Welcome",
        descriptionKey: "onboarding.welcome.description"
    ),
    OnboardingPage(
        id: 1,
        imageName: "onboarding_add_account",
        titleKey: "onboarding.addAccount.title",
        descriptionKey: "onboarding.addAccount.description"
    ),
    OnboardingPage(
        id: 2,
        imageName: "onboarding_login",
        titleKey: "onboarding.login.title",
        descriptionKey: "onboarding.login.description"
    ),
    OnboardingPage(
        id: 3,
        imageName: "onboarding_otp",
        titleKey: "onboarding.otp.title",
        descriptionKey: "onboarding.otp.description"
    ),
    OnboardingPage(
        id: 4,
        imageName: "onboarding_settings",
        titleKey: "onboarding.settings.title",
        descriptionKey: "onboarding.settings.description"
    ),
    OnboardingPage(
        id: 5,
        imageName: "onboarding_presets",
        titleKey: "onboarding.import.title",
        descriptionKey: "onboarding.import.description"
    ),
]

struct OnboardingView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @Environment(\.dismissWindow) private var dismissWindow
    @State private var currentPage = 0
    @State private var dontShowAgain = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            HStack(spacing: 0) {
                Button {
                    withAnimation { currentPage -= 1 }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.title)
                        .frame(width: 48, height: 48)
                }
                .buttonStyle(.plain)
                .disabled(currentPage == 0)
                .opacity(currentPage == 0 ? 0.3 : 1)

                pageContent(onboardingPages[currentPage])
                    .frame(maxWidth: .infinity)

                Button {
                    withAnimation { currentPage += 1 }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.title)
                        .frame(width: 48, height: 48)
                }
                .buttonStyle(.plain)
                .disabled(currentPage == onboardingPages.count - 1)
                .opacity(currentPage == onboardingPages.count - 1 ? 0.3 : 1)
            }
            .padding(.horizontal, 16)

            Spacer()

            pageIndicator()
                .padding(.bottom, 16)

            Toggle(isOn: $dontShowAgain) {
                Text("Don't show again")
                    .font(.caption)
            }
            .toggleStyle(.checkbox)
            .onChange(of: dontShowAgain) { _, newValue in
                hasSeenOnboarding = newValue
            }
            .padding(.bottom, 24)
        }
        .frame(width: 720, height: 560)
        .onKeyPress(.leftArrow) {
            if currentPage > 0 {
                withAnimation { currentPage -= 1 }
            }
            return .handled
        }
        .onKeyPress(.rightArrow) {
            if currentPage < onboardingPages.count - 1 {
                withAnimation { currentPage += 1 }
            }
            return .handled
        }
    }

    @ViewBuilder
    private func pageContent(_ page: OnboardingPage) -> some View {
        VStack(spacing: 16) {
            Image(page.imageName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxHeight: 300)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .shadow(color: .black.opacity(0.15), radius: 4, y: 2)

            Text(LocalizedStringKey(page.titleKey))
                .font(.title2)
                .fontWeight(.semibold)

            Text(LocalizedStringKey(page.descriptionKey))
                .font(.callout)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .lineSpacing(5)
                .frame(maxWidth: 480)
        }
        .transition(.opacity)
        .id(page.id)
    }

    private func pageIndicator() -> some View {
        HStack(spacing: 10) {
            ForEach(onboardingPages) { page in
                Circle()
                    .fill(page.id == currentPage ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(width: 9, height: 9)
                    .onTapGesture {
                        withAnimation { currentPage = page.id }
                    }
            }
        }
    }
}
