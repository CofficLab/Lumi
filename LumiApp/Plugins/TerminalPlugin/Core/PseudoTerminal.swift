import Foundation

enum TerminalError: Error {
    case ptyCreationFailed
    case processLaunchFailed
}

class PseudoTerminal: @unchecked Sendable {
    private var masterFileHandle: FileHandle?
    private var childProcess: Process?
    
    // Callbacks need to be thread-safe or dispatched to known queue
    // We will ensure they are called on MainActor or handled appropriately
    var onOutput: ((Data) -> Void)?
    var onProcessTerminated: (() -> Void)?
    
    init() {}
    
    func start() throws {
        // 1. Create PTY
        var masterFD: Int32 = 0
        masterFD = posix_openpt(O_RDWR | O_NOCTTY)
        guard masterFD != -1 else { throw TerminalError.ptyCreationFailed }
        
        guard grantpt(masterFD) != -1 else { throw TerminalError.ptyCreationFailed }
        guard unlockpt(masterFD) != -1 else { throw TerminalError.ptyCreationFailed }
        
        let slavePathC = ptsname(masterFD)
        guard let slavePathC = slavePathC else { throw TerminalError.ptyCreationFailed }
        let slavePath = String(cString: slavePathC)
        
        // 2. Setup Process
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.environment = [
            "TERM": "xterm-256color",
            "LANG": "en_US.UTF-8",
            "PATH": "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        ]
        
        // Connect slave PTY to process stdin/out/err
        let slaveFileHandle = FileHandle(forUpdatingAtPath: slavePath)
        guard let slaveFileHandle = slaveFileHandle else { throw TerminalError.ptyCreationFailed }
        
        process.standardInput = slaveFileHandle
        process.standardOutput = slaveFileHandle
        process.standardError = slaveFileHandle
        
        // 3. Launch
        process.terminationHandler = { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.onProcessTerminated?()
            }
        }
        
        try process.run()
        self.childProcess = process
        
        // 4. Setup Master Read
        self.masterFileHandle = FileHandle(fileDescriptor: masterFD, closeOnDealloc: true)
        self.startReading()
        
        // 5. Set Window Size (Optional, default 80x24)
        var winSize = winsize(ws_row: 24, ws_col: 80, ws_xpixel: 0, ws_ypixel: 0)
        _ = ioctl(masterFD, TIOCSWINSZ, &winSize)
    }
    
    private func startReading() {
        masterFileHandle?.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            
            // Dispatch to main thread to safely access self and call callback
            Task { @MainActor [weak self] in
                // Force UI update
                self?.onOutput?(data)
            }
        }
    }
    
    func write(_ data: Data) {
        masterFileHandle?.write(data)
    }
    
    func resize(rows: UInt16, cols: UInt16) {
        guard let fd = masterFileHandle?.fileDescriptor else { return }
        var winSize = winsize(ws_row: rows, ws_col: cols, ws_xpixel: 0, ws_ypixel: 0)
        _ = ioctl(fd, TIOCSWINSZ, &winSize)
    }
    
    func terminate() {
        masterFileHandle?.readabilityHandler = nil
        childProcess?.terminate()
    }
}
