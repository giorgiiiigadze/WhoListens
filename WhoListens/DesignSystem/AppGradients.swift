import SwiftUI

enum AppGradients {
    static let brand = LinearGradient(
        stops: [
            .init(color: AppColors.electricPurple, location: 0),
            .init(color: AppColors.hotPink, location: 0.52),
            .init(color: AppColors.warmOrange, location: 1)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let welcome = LinearGradient(
        stops: [
            .init(color: AppColors.electricPurple, location: 0),
            .init(color: AppColors.hotPink, location: 0.25),
            .init(color: AppColors.hotPink, location: 0.43),
            .init(color: AppColors.warmOrange, location: 1)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}
