import Testing
@testable import ScanEngine

struct MACAddressTests {
    @Test func normalizesSeparators() {
        #expect(MACAddress("AA-BB-CC-DD-EE-FF")?.canonical == "aa:bb:cc:dd:ee:ff")
        #expect(MACAddress("aa:bb:cc:dd:ee:ff")?.canonical == "aa:bb:cc:dd:ee:ff")
        #expect(MACAddress("aabbccddeeff")?.canonical == "aa:bb:cc:dd:ee:ff")
        #expect(MACAddress("aa:bb:cc:dd:ee:ff")?.ouiPrefix == "aa:bb:cc")
    }

    @Test func rejectsInvalid() {
        #expect(MACAddress("zz:zz:zz:zz:zz:zz") == nil)
        #expect(MACAddress("aa:bb") == nil)
        #expect(MACAddress("") == nil)
    }
}
