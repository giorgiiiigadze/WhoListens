import SwiftUI

struct TermsDisclaimer: View {
    let color: Color

    var body: some View {
        (Text("By continuing, you agree to our ")
         + Text("Terms of Use").underline()
         + Text(" and have read and agreed to our ")
         + Text("Privacy Policy").underline()
         + Text("."))
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(color)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
    }
}
