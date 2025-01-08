#if os(macOS)
import IOKit.pwr_mgt

class ScreenSleep {
    private var assertionID: IOPMAssertionID = 0
    
    func prevent() {
        var assertionID = self.assertionID
        IOPMAssertionCreateWithName(
            kIOPMAssertionTypeNoDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "Stage Timer is running" as CFString,
            &assertionID
        )
        self.assertionID = assertionID
    }
    
    func allow() {
        IOPMAssertionRelease(assertionID)
    }
}
#endif
