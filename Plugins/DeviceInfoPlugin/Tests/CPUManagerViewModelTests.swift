import Testing
@testable import DeviceInfoPlugin

@MainActor
struct CPUManagerViewModelTests {
    @Test
    func formattedLoadAverage() {
        let vm = CPUManagerViewModel(monitorsProcesses: false)
        vm.loadAverage = [1.5, 2.345, 0.8]
        #expect(vm.formattedLoadAverage == "1.50  2.35  0.80")
    }

    @Test
    func formattedLoadAverageZeros() {
        let vm = CPUManagerViewModel(monitorsProcesses: false)
        vm.loadAverage = [0, 0, 0]
        #expect(vm.formattedLoadAverage == "0.00  0.00  0.00")
    }
}
