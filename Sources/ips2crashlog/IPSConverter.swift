import Foundation
import ObjectMapper

// Update the alias to use the correct thread model (defined in Threads.swift).
typealias ThreadType = Threads

struct IPSConverter {
    func convert(inputPath: String, outputPath: String?) throws {
        // Read input file
        let inputURL = URL(fileURLWithPath: inputPath)
        let ipsData = try Data(contentsOf: inputURL)
        let ipsString = String(data: ipsData, encoding: .utf8)!
        
        // Generate crash log format
        let crashLog = try generateCrashLog(from: ipsString)
        
        // Determine output path
        let outputURL: URL
        if let outputPath = outputPath {
            outputURL = URL(fileURLWithPath: outputPath)
        } else {
            outputURL = inputURL.deletingPathExtension().appendingPathExtension("crash")
        }
        
        // Write output
        try crashLog.write(to: outputURL, atomically: true, encoding: .utf8)
    }
    
    func generateCrashLog(from ipsString: String) throws -> String {
        let decoder = JSONDecoder()
        
        // --- Updated header parsing using JSON balancing ---
        let parts = try splitHeaderAndBody(from: ipsString)
        let headerString = parts.header
        let body = parts.body
        guard let headerData = headerString.data(using: .utf8),
              let header = try? decoder.decode(IPSHeader.self, from: headerData) else {
            throw ConversionError.invalidFormat(message: "Failed to decode header. Header string: \(headerString)")
        }
		
        // Parse entire body with Json4Swift_Base
        let bodyModel = Mapper<Json4Swift_Base>().map(JSONString: body)
        
        // Use values from header, falling back to the body model
        let crashKey         = header.crashReporterKey ?? bodyModel?.crashReporterKey ?? "Unknown"
        let procPath         = header.procPath        ?? bodyModel?.procPath        ?? "Unknown"
        let procRole         = header.procRole        ?? bodyModel?.procRole        ?? "Unknown"
        let parentProc       = header.parentProc      ?? bodyModel?.parentProc      ?? "Unknown"
        let parentPid        = header.parentPid       ?? bodyModel?.parentPid       ?? 0
        let coalitionName    = header.coalitionName   ?? bodyModel?.coalitionName   ?? "Unknown"
        let coalitionID      = header.coalitionID     ?? bodyModel?.coalitionID     ?? 0
        let responsibleProc  = header.responsibleProc ?? bodyModel?.responsibleProc ?? "Unknown"
        let responsiblePid   = header.responsiblePid  ?? bodyModel?.responsiblePid  ?? 0
        let dateTime         = header.captureTime     ?? bodyModel?.captureTime     ?? "Unknown"
        let launchTime       = header.procLaunch      ?? bodyModel?.procLaunch      ?? "Unknown"
        var finalTriggeredThread = header.triggeredThread ?? "Unknown"
        if finalTriggeredThread == "Unknown", let faultThread = bodyModel?.faultingThread, faultThread != 0 {
            finalTriggeredThread = "\(faultThread)"
        }
        let hardwareModel    = header.modelCode       ?? bodyModel?.modelCode       ?? "Unknown"
        let processID        = header.pid             ?? bodyModel?.pid             ?? 0
        
        // Exception fields – assuming bodyModel.exception exists
        let exceptionType    = header.exceptionType ?? bodyModel?.exception?.type  ?? "Unknown"
        let exceptionCodes   = header.exceptionCodes ?? bodyModel?.exception?.codes ?? "Unknown"
        let exceptionSignal  = bodyModel?.exception?.signal ?? "Unknown"
        
        // Termination fields – assuming bodyModel.termination exists
        let termNamespace    = bodyModel?.termination?.namespace ?? "Unknown"
        let termCode         = bodyModel?.termination?.code.map { "\($0)" } ?? "Unknown"
        let termIndicator    = bodyModel?.termination?.indicator    ?? "Unknown"
        let terminationByProc = bodyModel?.termination?.byProc        ?? "Unknown"
        let terminationByPid  = bodyModel?.termination?.byPid         ?? 0

        var output = """
        -------------------------------------
        Translated Report (Full Report Below)
        -------------------------------------

        Incident Identifier: \(header.incident_id)
        CrashReporter Key:   \(crashKey)
        Hardware Model:      \(hardwareModel)
        Process:             \(header.app_name) [\(processID)]
        Path:                \(procPath)
        Identifier:          \(header.bundleID)
        Version:             \(header.app_version) (\(header.build_version))
        Code Type:           \(header.cpuType ?? "ARM-64") (Native)
        Role:                \(procRole)
        Parent Process:      \(parentProc) [\(parentPid)]
        Coalition:           \(coalitionName) [\(coalitionID)]
        Responsible Process: \(responsibleProc) [\(responsiblePid)]

        Date/Time:           \(dateTime)
        Launch Time:         \(launchTime)
        OS Version:          \(header.os_version)
        Release Type:        \(header.releaseType ?? "User")
        Report Version:      104

        """
        
        if exceptionType != "Unknown" && exceptionCodes != "Unknown" {
            output += """
            
            Exception Type:  \(exceptionType)\(exceptionSignal != "Unknown" ? " (\(exceptionSignal))" : "")
            Exception Codes: \(exceptionCodes)
            """
        }
        
        if termIndicator != "Unknown" {
            output += """
            
            Termination Reason: \(termNamespace) \(termCode) \(termIndicator)
            Terminating Process: \(terminationByProc) [\(terminationByPid)]
            """
        }
        
        if finalTriggeredThread != "Unknown" {
            output += "\n\nTriggered by Thread:  \(finalTriggeredThread)"
        }
        
        // Use helper to generate thread dump and capture crashed thread number.
        let (threadDump, crashedThreadNumber) = generateThreadDump(from: bodyModel)
        output += "\n\n\(threadDump)"
        
        // Generate thread state if available.
        if let triggeredThread = bodyModel?.threads?.first(where: { $0.triggered }) {
            let threadStateString = generateThreadState(for: triggeredThread, crashedThreadNumber: crashedThreadNumber)
            output += "\n\(threadStateString)\n"
        }
        
        output += "\nBinary Images:"
        // Updated loop with formatted spacing
        for image in bodyModel?.usedImages ?? [] {
            var imageLine = ""
            let base = image.base ?? 0
            let size = image.size ?? 0
            let startHex = base == 0 ? "0x0" : String(format: "0x%08llx", base)
            let endHex = String(format: "0x%08llx", base + size - 1)
            let name = image.cFBundleIdentifier ?? image.name ?? "???"
            let uuid = image.uuid ?? ""
            let path = image.path ?? "???"
            let version = image.cFBundleShortVersionString ?? "*"
            
            // print name base and size
            //print("Name: \(name) Base: \(base) Size: \(size)")

            let paddedStartHex = startHex//.padding(toLength: 20, withPad: " ", startingAt: 0)
            let paddedEndHex   = endHex//.padding(toLength: 19, withPad: " ", startingAt: 0)

            
            imageLine += "\n\(String(repeating: " ", count: 18 - paddedStartHex.count))\(paddedStartHex) - \(String(repeating: " ", count: 18 - paddedEndHex.count))"


            imageLine += "\(paddedEndHex) \(name) (\(version)) <\(uuid)> \(path)"

            output += imageLine
        }

        output += "\n\nEOF\n\n-----------\nFull Report\n-----------\n\n"
        output += ipsString
        
        return output
    }
    
    // Define the splitHeaderAndBody function
    func splitHeaderAndBody(from ipsString: String) throws -> (header: String, body: String) {
        let components = ipsString.components(separatedBy: "\n")
        guard components.count >= 2 else {
            throw ConversionError.invalidFormat(message: "Invalid IPS format. Expected header and body.")
        }
        // In case the body spans multiple paragraphs, join them back.
        return (header: components[0], body: components.dropFirst().joined(separator: "\n"))
    }

    // MARK: - Private Helpers
    
    // Generates the thread dump and captures the crashed thread number.
    private func generateThreadDump(from bodyModel: Json4Swift_Base?) -> (String, Int?) {
        var allThreadsDump = ""
        var crashedThreadNumber: Int?
        var currentThreadNumber = 0
        
        for thread in bodyModel?.threads ?? [] {
            // Updated header: always use a double colon and omit " Crashed"
            var currentThread = "Thread \(currentThreadNumber)"
            if thread.triggered {
                crashedThreadNumber = currentThreadNumber
                currentThread += " Crashed"
            }
            
            currentThread += ":"
            if let threadQueue = thread.queue {
                currentThread += ":  Dispatch queue: \(threadQueue)"
            } else if let threadName = thread.name {
                currentThread += ": \(threadName)"
            }

            
            // Append frames for current thread.
            var frameNumber = 0
            for frame in thread.frames ?? [] {
                if let imageOffset = frame.imageOffset,
                   let imageIndex = frame.imageIndex {
                    let image = bodyModel?.usedImages?[imageIndex]
                    var frameLine = "\n\(frameNumber)"
                    // Align first column.
                    let spaces1 = max(4 - frameLine.count, 0)
                    frameLine += String(repeating: " ", count: spaces1)
                    frameLine += " \(image?.name ?? "Unknown")"
                    let spaces2 = max(35 - frameLine.count, 0)
                    frameLine += String(repeating: " ", count: spaces2)
                    frameLine += "\t       "
                    
                    let imageBase = image?.base ?? 0
                    let imageLocation = imageBase + imageOffset
                    let imageLocationHex = String(format: "0x%llx", imageLocation)
                    
                    frameLine += imageLocationHex
                    if let symbol = frame.symbol {
                        frameLine += " \(symbol)"
                        if let symbolLocation = frame.symbolLocation {
                            frameLine += " + \(symbolLocation)"
                        }
                    } else if let imageBase = image?.base {
                        let imageBaseHex = String(format: "0x%llx", imageBase)
                        frameLine += " \(imageBaseHex)"
                        frameLine += " + \(imageOffset)"
                    }
                    
                    if let sourceFile = frame.sourceFile,
                       let sourceLine = frame.sourceLine {
                        frameLine += " (\(sourceFile):\(sourceLine))"
                    } else if frame.inline {
                        frameLine += " [inlined]"
                    }
                    
                    currentThread += frameLine
                    frameNumber += 1
                }
            }
            allThreadsDump += currentThread + "\n\n"
            currentThreadNumber += 1
        }
        return (allThreadsDump, crashedThreadNumber)
    }
    
    // Generates the thread state string for a crashed thread.
    private func generateThreadState(for triggeredThread: ThreadType, crashedThreadNumber: Int?) -> String {
        var threadStateOutput = ""
        var flavor = triggeredThread.threadState?.flavor ?? ""
        switch flavor {
            case "ARM_THREAD_STATE":
                flavor = "ARM Thread State"
            case "ARM_THREAD_STATE64":
                flavor = "ARM Thread State (64-bit)"
            default:
                break
        }
        
        let threadID = crashedThreadNumber ?? triggeredThread.id ?? 0
        threadStateOutput += "Thread \(threadID) crashed with \(flavor):\n"
        
        var stateDict = [String: String]()
        // Format x registers.
        var xIndex = 0
        for xObject in triggeredThread.threadState?.x ?? [] {
            let valueHex = String(format: "0x%016llx", xObject.value ?? 0)
            stateDict["x\(xIndex)"] = valueHex
            xIndex += 1
        }
        // Other registers.
        if let fpValue = triggeredThread.threadState?.fp?.value {
            stateDict["fp"] = String(format: "0x%016llx", fpValue)
        }
        if let lrValue = triggeredThread.threadState?.lr?.value {
            stateDict["lr"] = String(format: "0x%016llx", lrValue)
        }
        if let spValue = triggeredThread.threadState?.sp?.value {
            stateDict["sp"] = String(format: "0x%016llx", spValue)
        }
        if let pcValue = triggeredThread.threadState?.pc?.value {
            stateDict["pc"] = String(format: "0x%016llx", pcValue)
        }
        if let cpsrValue = triggeredThread.threadState?.cpsr?.value {
            stateDict["cpsr"] = String(format: "0x%08x", cpsrValue)
        }
        if let farValue = triggeredThread.threadState?.far?.value {
            stateDict["far"] = String(format: "0x%016llx", farValue)
        }
        if let esrValue = triggeredThread.threadState?.esr?.value {
            let esrHex = String(format: "0x%08x", esrValue)
            stateDict["esr"] = "\(esrHex) \(triggeredThread.threadState?.esr?.description ?? "")"
        }
        
        // Order keys.
        var rowIndex = 0
        var rowString = ""
        let keyOrder = ["x", "fp", "lr", "sp", "pc", "cpsr", "far", "esr"]
        let sortedKeys = stateDict.keys.sorted { key1, key2 in
            let isX1 = key1.starts(with: "x")
            let isX2 = key2.starts(with: "x")
            if isX1 && isX2 {
                let int1 = Int(key1.dropFirst()) ?? 0
                let int2 = Int(key2.dropFirst()) ?? 0
                return int1 < int2
            } else {
                let idx1 = keyOrder.firstIndex(where: { key1.starts(with: $0) }) ?? 100
                let idx2 = keyOrder.firstIndex(where: { key2.starts(with: $0) }) ?? 100
                return idx1 < idx2
            }
        }
        
        for key in sortedKeys {
            let desiredColonIndex = 6 + 25 * rowIndex
            let spaces = max(desiredColonIndex - rowString.count - key.count, 0)
            rowString += String(repeating: " ", count: spaces)
            rowString += "\(key): \(stateDict[key]!)"
            rowIndex += 1
            
            let desiredRowCount = key.starts(with: "x") ? 4 : 3
            if rowIndex == desiredRowCount {
                threadStateOutput += "\(rowString)\n"
                rowIndex = 0
                rowString = ""
            }
        }
        threadStateOutput += rowString
        return threadStateOutput
    }
}

// MARK: - Error Types
enum ConversionError: Error {
    case invalidFormat(message: String)
}

// MARK: - Data Structures
struct IPSHeader: Codable {
    let app_name: String
    let timestamp: String
    let app_version: String
    let build_version: String
    let bundleID: String
    let incident_id: String
    let os_version: String
    
    // Optional fields
    let pid: Int?
    let procPath: String?
    let cpuType: String?
    let procRole: String?
    let parentProc: String?
    let parentPid: Int?
    let coalitionName: String?
    let coalitionID: Int?
    let responsibleProc: String?
    let responsiblePid: Int?
    let captureTime: String?
    let procLaunch: String?
    let releaseType: String?
    let modelCode: String?
    let crashReporterKey: String?
    let exceptionType: String?
    let exceptionCodes: String?
    let termination: String?
    let terminatingProcess: String?
    let triggeredThread: String?
    let threads: String?    
}