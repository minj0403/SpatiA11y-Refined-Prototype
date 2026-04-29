import Foundation

enum WidgetID: String, CaseIterable, Identifiable {
    case widget1 = "Widget 1"
    case widget2 = "Widget 2"
    case widget3 = "Widget 3"
    case widget4 = "Widget 4"
    case widget5 = "Widget 5"
    case widget6 = "Widget 6"
    case widget7 = "Widget 7"
    case widget8 = "Widget 8"
    case widget9 = "Widget 9"
    case widget10 = "Widget 10"

    var id: String { rawValue }

    var index: Int {
        switch self {
        case .widget1: return 1
        case .widget2: return 2
        case .widget3: return 3
        case .widget4: return 4
        case .widget5: return 5
        case .widget6: return 6
        case .widget7: return 7
        case .widget8: return 8
        case .widget9: return 9
        case .widget10: return 10
        }
    }
}
