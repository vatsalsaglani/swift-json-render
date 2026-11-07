/// Largest-Triangle-Three-Buckets downsampling (Steinarsson 2013).
///
/// A pure function: it keeps the first and the last point, returns exactly `threshold`
/// points when the input is longer, and keeps the input order (so a monotone x stays
/// monotone). Shorter inputs and thresholds below 3 return the input unchanged.
public enum LTTB {
    /// The indices of the points to keep, ascending.
    public static func indices(x: [Double], y: [Double], threshold: Int) -> [Int] {
        let count = Swift.min(x.count, y.count)
        guard threshold >= 3, count > threshold else { return Array(0..<count) }
        var kept: [Int] = [0]
        kept.reserveCapacity(threshold)
        let bucketSize = Double(count - 2) / Double(threshold - 2)
        var previous = 0
        for bucket in 0..<(threshold - 2) {
            let start = Int(Double(bucket) * bucketSize) + 1
            let end = Swift.min(Int(Double(bucket + 1) * bucketSize) + 1, count - 1)
            // Average of the next bucket (the last point for the final bucket).
            let nextStart = end
            let nextEnd = Swift.min(Int(Double(bucket + 2) * bucketSize) + 1, count)
            var averageX = 0.0
            var averageY = 0.0
            let span = Swift.max(nextEnd - nextStart, 1)
            for index in nextStart..<Swift.max(nextEnd, nextStart + 1) where index < count {
                averageX += x[index]
                averageY += y[index]
            }
            averageX /= Double(span)
            averageY /= Double(span)
            var best = start
            var bestArea = -1.0
            for index in start..<Swift.max(end, start + 1) {
                let area = abs(
                    (x[previous] - averageX) * (y[index] - y[previous])
                        - (x[previous] - x[index]) * (averageY - y[previous]))
                if area > bestArea {
                    bestArea = area
                    best = index
                }
            }
            kept.append(best)
            previous = best
        }
        kept.append(count - 1)
        return kept
    }

    /// The downsampled points.
    public static func downsample<Point>(
        _ points: [Point], threshold: Int, x: (Point) -> Double, y: (Point) -> Double
    ) -> [Point] {
        let picked = indices(x: points.map(x), y: points.map(y), threshold: threshold)
        return picked.map { points[$0] }
    }
}
