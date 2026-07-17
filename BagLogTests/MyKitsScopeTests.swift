import Persistence
import Testing
@testable import BagLog

struct MyKitsScopeTests {
    @Test("Scopes include the intended kit statuses")
    func statusFiltering() {
        #expect(MyKitsScope.all.includes(.draft))
        #expect(MyKitsScope.all.includes(.published))
        #expect(MyKitsScope.all.includes(.archived))

        #expect(MyKitsScope.drafts.includes(.draft))
        #expect(!MyKitsScope.drafts.includes(.published))
        #expect(!MyKitsScope.drafts.includes(.archived))

        #expect(MyKitsScope.published.includes(.published))
        #expect(!MyKitsScope.published.includes(.draft))
        #expect(!MyKitsScope.published.includes(.archived))
    }
}
