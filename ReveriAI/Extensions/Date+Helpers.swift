import Foundation

extension Date {
    var isToday: Bool {
        Calendar.current.isDateInToday(self)
    }

    var isThisWeek: Bool {
        Calendar.current.isDate(self, equalTo: .now, toGranularity: .weekOfYear)
    }

    var isThisMonth: Bool {
        Calendar.current.isDate(self, equalTo: .now, toGranularity: .month)
    }

    var isDayTime: Bool {
        let hour = Calendar.current.component(.hour, from: self)
        return hour >= 5 && hour < 21
    }

    private static let dreamFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy, hh:mma"
        f.amSymbol = "am"
        f.pmSymbol = "pm"
        return f
    }()

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "hh:mma"
        f.amSymbol = "am"
        f.pmSymbol = "pm"
        return f
    }()

    var dreamFormatted: String {
        Self.dreamFormatter.string(from: self)
    }

    var timeFormatted: String {
        Self.timeFormatter.string(from: self)
    }
}
