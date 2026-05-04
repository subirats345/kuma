import CoreFoundation
import CoreGraphics
import CoreText
import Foundation
import ImageIO

let pageWidth: CGFloat = 595
let pageHeight: CGFloat = 842
let leftX: CGFloat = 45
let headingX: CGFloat = 46
let bodyWidth: CGFloat = 505
let headingWidth: CGFloat = bodyWidth - (headingX - leftX)
let bulletTextX: CGFloat = 62
let bulletWidth: CGFloat = 480
let bulletDotX: CGFloat = 53
let listLevelIndent: CGFloat = 15
let bodyLineHeight: CGFloat = 20
let pageStartY: CGFloat = 64
let firstPageStartY: CGFloat = 72
let maxBaselineY: CGFloat = 790
let accentColor = CGColor(red: 0.8666667, green: 0.2980392, blue: 0.3098039, alpha: 1)
let blackColor = CGColor(gray: 0, alpha: 1)
let captionColor = CGColor(gray: 0.35, alpha: 1)
let codeTextColor = CGColor(red: 0.12, green: 0.11, blue: 0.10, alpha: 1)
let codeBackgroundColor = CGColor(red: 0.965, green: 0.955, blue: 0.935, alpha: 1)
let codeBorderColor = CGColor(red: 0.88, green: 0.86, blue: 0.82, alpha: 1)
let tableHeaderColor = CGColor(red: 0.975, green: 0.968, blue: 0.948, alpha: 1)
let tableLineColor = CGColor(red: 0.82, green: 0.80, blue: 0.76, alpha: 1)
let kumaStrikethroughAttribute = NSAttributedString.Key("KumaStrikethrough")
let kumaLinkAttribute = NSAttributedString.Key("KumaLinkURL")
let appName = "Kuma"
let appVersion = "0.10.2"
let defaultBodyFontName = "AvenirNext-Regular"
let defaultHeadingFontName = "AvenirNext-DemiBold"
let defaultCodeFontName = "Menlo-Regular"
