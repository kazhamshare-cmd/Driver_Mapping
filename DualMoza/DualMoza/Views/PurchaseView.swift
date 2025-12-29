import SwiftUI

struct PurchaseView: View {
    @EnvironmentObject var purchaseManager: PurchaseManager
    @Environment(\.dismiss) var dismiss
    @ObservedObject var lang = LanguageManager.shared

    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "star.circle.fill")
                            .font(.system(size: 80))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.yellow, .orange],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )

                        Text("DualMoza PRO")
                            .font(.largeTitle.bold())

                        Text(lang.L("unlock_all_features"))
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 20)

                    // Features
                    VStack(alignment: .leading, spacing: 16) {
                        featureRow(icon: "checkmark.circle.fill", text: lang.L("no_ads"), color: .green)
                        featureRow(icon: "infinity", text: lang.L("unlimited_recording"), color: .blue)
                        featureRow(icon: "xmark.circle.fill", text: lang.L("no_watermark"), color: .purple)
                    }
                    .padding(.horizontal, 32)

                    // Price
                    VStack(spacing: 8) {
                        if purchaseManager.proPriceString.isEmpty {
                            ProgressView()
                                .padding()
                        } else {
                            Text(purchaseManager.proPriceString)
                                .font(.system(size: 48, weight: .bold))
                        }

                        Text(lang.L("one_time_purchase"))
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 16)

                    // Purchase Button
                    Button(action: purchase) {
                        HStack {
                            if purchaseManager.isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text(lang.L("purchase_pro"))
                                    .fontWeight(.bold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundColor(.white)
                        .cornerRadius(16)
                    }
                    .disabled(purchaseManager.isLoading)
                    .padding(.horizontal, 32)

                    // Restore Button
                    Button(action: restore) {
                        Text(lang.L("restore_purchase"))
                            .font(.subheadline)
                            .foregroundColor(.blue)
                    }
                    .padding(.top, 8)

                    // Comparison
                    comparisonTable
                        .padding(.top, 16)

                    Spacer(minLength: 40)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(lang.L("close")) {
                        dismiss()
                    }
                }
            }
            .alert(lang.L("error"), isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    // MARK: - Feature Row
    private func featureRow(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 32)

            Text(text)
                .font(.body)

            Spacer()
        }
    }

    // MARK: - Comparison Table
    private var comparisonTable: some View {
        VStack(spacing: 0) {
            Text(lang.L("feature_comparison"))
                .font(.headline)
                .padding(.bottom, 12)

            // Header
            HStack {
                Text(lang.L("feature"))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(lang.L("free"))
                    .frame(width: 60)
                Text("PRO")
                    .frame(width: 60)
                    .foregroundColor(.yellow)
            }
            .font(.caption.bold())
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .background(Color.gray.opacity(0.2))

            // Rows
            comparisonRow(feature: lang.L("dual_camera"), free: true, pro: true)
            comparisonRow(feature: lang.L("auto_mosaic"), free: true, pro: true)
            comparisonRow(feature: lang.L("pip_display"), free: true, pro: true)
            comparisonRow(feature: lang.L("recording_time"), freeText: lang.L("thirty_seconds"), proText: lang.L("unlimited"))
            comparisonRow(feature: lang.L("ads"), freeText: lang.L("yes"), proText: lang.L("no"))
            comparisonRow(feature: lang.L("watermark"), free: false, pro: true)
        }
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
        .padding(.horizontal, 16)
    }

    private func comparisonRow(feature: String, free: Bool, pro: Bool) -> some View {
        HStack {
            Text(feature)
                .font(.caption)
                .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: free ? "checkmark" : "xmark")
                .foregroundColor(free ? .green : .red)
                .frame(width: 60)
            Image(systemName: pro ? "checkmark" : "xmark")
                .foregroundColor(pro ? .green : .red)
                .frame(width: 60)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
    }

    private func comparisonRow(feature: String, freeText: String, proText: String) -> some View {
        HStack {
            Text(feature)
                .font(.caption)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(freeText)
                .font(.caption)
                .foregroundColor(.gray)
                .frame(width: 60)
            Text(proText)
                .font(.caption)
                .foregroundColor(.yellow)
                .frame(width: 60)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
    }

    // MARK: - Purchase
    private func purchase() {
        Task {
            do {
                try await purchaseManager.purchasePro()
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }

    // MARK: - Restore
    private func restore() {
        Task {
            do {
                try await purchaseManager.restorePurchases()
                if purchaseManager.isPro {
                    dismiss()
                } else {
                    errorMessage = lang.L("no_purchase_to_restore")
                    showError = true
                }
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}
