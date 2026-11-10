import SwiftUI

/// OTP 입력칸 (메인 창·메뉴바 공용). 걸러진 값(숫자 6자리)을 그대로 다시 보여 준다.
/// store 바인딩만 쓰면 걸러져 값이 안 바뀐 입력(글자, 7번째 숫자)이 칸에 그대로 남는다.
struct OTPField: View {
    @EnvironmentObject var store: AccountStore
    @State private var text = ""

    var body: some View {
        TextField("Enter 6-digit code", text: $text)
            .onAppear { text = store.state.otpCode }
            .onChange(of: text) { _, newValue in
                store.send(.setOtpCode(newValue))
                if text != store.state.otpCode { text = store.state.otpCode }
            }
            .onChange(of: store.state.otpCode) { _, newValue in
                if text != newValue { text = newValue }   // 로그인 성공 후 비워질 때, 다른 창에서 입력할 때
            }
            .help(Text("The 6-digit pairing code shown on the TV. Digits only."))
    }
}
