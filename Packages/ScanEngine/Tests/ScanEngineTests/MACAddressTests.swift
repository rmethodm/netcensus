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

    @Test func flagsBroadcastAndMulticast() {
        #expect(MACAddress("ff:ff:ff:ff:ff:ff")?.isBroadcast == true)
        #expect(MACAddress("01:00:5e:00:00:fb")?.isMulticast == true)
        #expect(MACAddress("d4:35:1d:eb:24:33")?.isBroadcast == false)
        #expect(MACAddress("d4:35:1d:eb:24:33")?.isMulticast == false)
    }
}
