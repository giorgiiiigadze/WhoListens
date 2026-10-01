import SwiftUI

struct AgeConfirmationView: View {
    var onBack: (() -> Void)? = nil
    @AppStorage("pendingBirthMonth") private var pendingBirthMonth = 0
    @AppStorage("pendingBirthYear") private var pendingBirthYear = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedMonth = Calendar.current.component(.month, from: Date())
    @State private var selectedYear = Calendar.current.component(.year, from: Date()) - 18
    @State private var didContinue = false

    private var age: Int {
        let now = Date()
        let year = Calendar.current.component(.year, from: now)
        let month = Calendar.current.component(.month, from: now)
        return year - selectedYear - (month < selectedMonth ? 1 : 0)
    }

    var body: some View {
        ZStack {
            if didContinue {
                DisplayNameView(onBack: { didContinue = false })
                    .transition(OnboardingMotion.transition(reduceMotion: reduceMotion))
            } else {
                ageContent
                    .transition(OnboardingMotion.transition(reduceMotion: reduceMotion))
            }
        }
        .animation(OnboardingMotion.animation(reduceMotion: reduceMotion), value: didContinue)
    }

    private var ageContent: some View {
        VStack(spacing: 0) {
            Text("Confirm your age")
                .font(AppTypography.title)
                .multilineTextAlignment(.center)
                .padding(.top, AppSpacing.large)

            Spacer()

            MonthYearPicker(month: $selectedMonth, year: $selectedYear)
                .frame(height: 180)

            Spacer()

            Text("\(age) years old")
                .font(.system(size: 18, weight: .semibold))
                .padding(.bottom, AppSpacing.large)

            Button {
                pendingBirthMonth = selectedMonth
                pendingBirthYear = selectedYear
                didContinue = true
            } label: {
                Text("Continue")
                    .font(AppTypography.body)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.medium)
                    .background(.black, in: Capsule())
            }
            .buttonStyle(.plain)

            TermsDisclaimer(color: .secondary)
                .padding(.top, AppSpacing.large)
        }
        .foregroundStyle(AppColors.text)
        .padding(.horizontal, AppSpacing.xLarge)
        .padding(.bottom, AppSpacing.xLarge)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(onBack != nil)
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
            if let onBack {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .accessibilityLabel("Back to welcome")
                }
            }
        }
    }
}
