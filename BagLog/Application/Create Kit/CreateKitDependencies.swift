import Persistence

struct CreateKitDependencies {
    let persistence: any BagLogPersisting
    let mediaStore: any MediaStoring
}
