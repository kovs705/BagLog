import Persistence

extension LoadoutCategory {
    var createKitTitle: String {
        switch self {
        case .everydayCarry: "Everyday Carry"
        case .travel: "Travel"
        case .cycling: "Cycling"
        case .camera: "Camera"
        case .work: "Work"
        case .outdoor: "Outdoor"
        case .emergency: "Emergency"
        case .fitness: "Fitness"
        case .parenting: "Parenting"
        case .other: "Other"
        }
    }

    var createKitSymbol: String {
        switch self {
        case .everydayCarry: "briefcase"
        case .travel: "suitcase"
        case .cycling: "bicycle"
        case .camera: "camera"
        case .work: "laptopcomputer"
        case .outdoor: "figure.hiking"
        case .emergency: "cross.case"
        case .fitness: "dumbbell"
        case .parenting: "figure.and.child.holdinghands"
        case .other: "backpack"
        }
    }
}
