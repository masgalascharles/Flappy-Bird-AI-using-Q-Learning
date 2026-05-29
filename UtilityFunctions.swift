import SwiftUI

func getDistance(point1: CGPoint, point2: CGPoint) -> CGFloat {
    let xDistance: CGFloat = point1.x - point2.x
    let yDistance: CGFloat = point1.y - point2.y
    let distance: CGFloat = sqrt(pow(xDistance, 2) + pow(yDistance, 2))
    
    return distance
}

func roundToNearestThousandth(_ x: CGFloat) -> CGFloat {
    let rounded: CGFloat = round(x * 1000) / 1000
    
    return rounded
}
