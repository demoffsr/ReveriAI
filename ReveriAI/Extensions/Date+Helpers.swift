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

    var dreamFormatted: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy, hh:mma"
        formatter.amSymbol = "am"
        formatter.pmSymbol = "pm"
        return formatter.string(from: self)
    }

    var timeFormatted: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "hh:mma"
        formatter.amSymbol = "am"
        formatter.pmSymbol = "pm"
        return formatter.string(from: self)
    }
}
