import SwiftUI

struct SetupView: View {
    @AppStorage("mocoDomain") private var mocoDomain: String = ""
    @AppStorage("mocoApiKey") private var apiKey: String = ""
    @Environment(\.dismiss) private var dismiss  // <-- Add this

    var body: some View {
        VStack(spacing: 16) {
            Text("MOCO Setup")
                .font(.title2)

            TextField("MOCO Company Domain (e.g., mycompany.mocoapp.com)", text: $mocoDomain)
                .textFieldStyle(RoundedBorderTextFieldStyle())

            SecureField("Personal API Key", text: $apiKey)
                .textFieldStyle(RoundedBorderTextFieldStyle())

            Button(action: save) {
                Image(systemName: "square.and.arrow.down")
                    .foregroundColor(.white)
                    .padding(10)
                    .font(.system(size: 20)) // Set the desired size
            }
            .buttonStyle(.borderedProminent)
            .cornerRadius(50)
            

        }
        .padding()
        .frame(width: 300)
    }

    func save() {
        UserDefaults.standard.set(mocoDomain, forKey: "mocoDomain")
        UserDefaults.standard.set(apiKey, forKey: "mocoApiKey")
        dismiss()  // <-- Close the window properly
    }
}
