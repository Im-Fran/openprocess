import Foundation

/// Fixed-capacity time series for charts.
struct History<Value: Sendable>: Sendable {
    struct Point: Identifiable, Sendable {
        let id: Int
        let date: Date
        let value: Value
    }

    private(set) var points: [Point] = []
    private var counter = 0
    let capacity: Int

    init(capacity: Int = 120) { self.capacity = capacity }

    mutating func append(_ value: Value, at date: Date) {
        counter += 1
        points.append(Point(id: counter, date: date, value: value))
        if points.count > capacity { points.removeFirst(points.count - capacity) }
    }
}
