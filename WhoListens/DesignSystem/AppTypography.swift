import SwiftUI

enum AppTypography {
    private static let brandFontName = "BowlbyOne-Regular"

    static let welcomeLogo = Font.custom(brandFontName, size: 54, relativeTo: .largeTitle)
    static let display = Font.custom(brandFontName, size: 32, relativeTo: .largeTitle)
    static let title = Font.custom(brandFontName, size: 24, relativeTo: .title)
    static let body = Font.custom(brandFontName, size: 17, relativeTo: .body)
}
