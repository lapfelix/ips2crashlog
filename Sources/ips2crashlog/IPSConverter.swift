import Foundation
import ObjectMapper

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
        
        var crashedThreadNumber: Int?

        // Updated thread dump extraction: try to use thread info from header or bodyModel.
        let threadDump: String = {
            // match this format:
            // Thread 0::  Dispatch queue: com.apple.main-thread
            var allThreadsDump = ""

            // count and print the threads
            let threadCount = bodyModel?.threads?.count ?? 0
            
            var currentThreadNumber = 0
            for thread in bodyModel?.threads ?? [] {
                var currentThread = ""

                currentThread += "Thread \(currentThreadNumber)"
                
                if thread.triggered {
                    currentThread += " Crashed"
                    crashedThreadNumber = currentThreadNumber
                }

                currentThread += ":"
                
                if let threadQueue = thread.queue {
                    currentThread += ":  Dispatch queue: \(threadQueue)"
                } else if let threadName = thread.name {
                    currentThread += ": \(threadName)"
                }           

                // todo: frames in the thread
                var currentFrameNumber = 0
                for frame in thread.frames ?? [] {
                    // we have
                    /*
                    var imageOffset : Int?
                    var symbol : String?
                    var symbolLocation : Int?
                    var imageIndex : Int?
                    */
                    
                    // and we want to show it in this format:
                    // 0   libobjc.A.dylib               	       0x180069ee8 objc_release + 116

                    if let imageOffset = frame.imageOffset,
                       let imageIndex = frame.imageIndex {
                        let symbolLocation = frame.symbolLocation 
                        let imageOffset = frame.imageOffset

                        let image = bodyModel?.usedImages?[imageIndex]
                        var currentFrame = "\n\(currentFrameNumber)"
                        // add spaces so the next column is at 4 characters
                        var spacesToAdd = 4 - currentFrame.count
                        if spacesToAdd > 0 {
                            currentFrame += String(repeating: " ", count: spacesToAdd)
                        }
                        currentFrame += " \(image?.name ?? "Unknown")"
                        
                        // add spaces so the next column is at 44 characters
                        spacesToAdd = 35 - currentFrame.count
                        if spacesToAdd > 0 {
                            currentFrame += String(repeating: " ", count: spacesToAdd)
                        }
                        currentFrame += "\t       "

                        let imageBase = image?.base ?? 0
                        let imageBaseHex = String(format: "0x%llx", imageBase)

                        let imageLocation = imageBase + (imageOffset ?? 0)
                        let imageLocationHex = String(format: "0x%llx", imageLocation)

                        currentFrame += "\(imageLocationHex)"
                        
                        if let symbol = frame.symbol {
                            currentFrame += " \(symbol)"
                            if let symbolLocation {
                                currentFrame += " + \(symbolLocation)"
                            }
                        } else if let imageBase = image?.base {
                           currentFrame += " \(imageBaseHex)"
                           if let imageOffset {
                             currentFrame += " + \(imageOffset)"
                           }
                        }

                        if let sourceFile = frame.sourceFile,
                           let sourceLine = frame.sourceLine {
                            currentFrame += " (\(sourceFile):\(sourceLine))"
                        } else if frame.inline {
                            currentFrame += " [inlined]"
                        }

                        currentThread += currentFrame
                        currentFrameNumber += 1
                    }
                }

                allThreadsDump += currentThread + "\n\n"
                currentThreadNumber += 1
            }

            return allThreadsDump
        }()
        output += "\n\n\(threadDump)"
        
        // Crashed thread ARM Thread State (64-bit):
        // Thread 13 crashed with ARM Thread State (64-bit):
        if let triggeredThread = bodyModel?.threads?.first(where: { $0.triggered }) {
            var threadStateString: String
            var flavorString = triggeredThread.threadState?.flavor ?? ""
            switch flavorString {
                case "ARM_THREAD_STATE":
                    flavorString = "ARM Thread State"
                case "ARM_THREAD_STATE64":
                    flavorString = "ARM Thread State (64-bit)"
                default:
                    break
            }

            threadStateString = "Thread \(crashedThreadNumber ?? triggeredThread.id ?? 0) crashed with \(flavorString):"

            output += "\n\(threadStateString)\n"

            var stateDict = [String: String]()

            // x registers
            var xIndex = 0
            for xObject in triggeredThread.threadState?.x ?? [] {
                // append in this format
                // x0: 0x0000000000000001
                let valueHex = String(format: "0x%016llx", xObject.value ?? 0)
                stateDict["x\(xIndex)"] = valueHex
                xIndex += 1
            }

            // fp: 0x00000001702487e0   lr: 0x000000011ecc5ab0
            // sp: 0x00000001702487c0   pc: 0x000000011ecc5adc cpsr: 0xa0001000
            // far: 0x0000000000000000  esr: 0xf2000001 (Breakpoint) brk 1

            if let fpValue = triggeredThread.threadState?.fp?.value {
                let fpHex = String(format: "0x%016llx", fpValue)
                stateDict["fp"] = fpHex
            }

            if let lrValue = triggeredThread.threadState?.lr?.value {
                let lrHex = String(format: "0x%016llx", lrValue)
                stateDict["lr"] = lrHex
            }

            if let spValue = triggeredThread.threadState?.sp?.value {
                let spHex = String(format: "0x%016llx", spValue)
                stateDict["sp"] = spHex
            }

            if let pcValue = triggeredThread.threadState?.pc?.value {
                let pcHex = String(format: "0x%016llx", pcValue)
                stateDict["pc"] = pcHex
            }

            if let cpsrValue = triggeredThread.threadState?.cpsr?.value {
                let cpsrHex = String(format: "0x%08x", cpsrValue)
                stateDict["cpsr"] = cpsrHex
            }

            if let farValue = triggeredThread.threadState?.far?.value {
                let farHex = String(format: "0x%016llx", farValue)
                stateDict["far"] = farHex
            }

            if let esrValue = triggeredThread.threadState?.esr?.value {
                let esrHex = String(format: "0x%08x", esrValue)
                stateDict["esr"] = "\(esrHex) \(triggeredThread.threadState?.esr?.description ?? "")"
            }

            // 4 rows
            var rowIndex = 0
            var rowString = ""
            var keyOrder = ["x", "fp", "lr", "sp", "pc", "cpsr", "far", "esr"]
            // sort the stateDict's keys with our key order, where the x registers are first and ordered from 0 to 999
            let sortedKeys = stateDict.keys.sorted { (key1, key2) -> Bool in
                let key1Prefix = key1.prefix(1)
                let key2Prefix = key2.prefix(1)
                if key1Prefix == key2Prefix && key1Prefix == "x" {
                    let key1Int = Int(key1.dropFirst()) ?? 0
                    let key2Int = Int(key2.dropFirst()) ?? 0
                    return key1Int < key2Int
                } else {
                    // x keys go before the non x keys, follow the keyOrder
                    let processedKey1Prefix = key1Prefix == "x" ? "x" : key1
                    let processedKey2Prefix = key2Prefix == "x" ? "x" : key2

                    if let key1Index = keyOrder.firstIndex(of: processedKey1Prefix),
                       let key2Index = keyOrder.firstIndex(of: processedKey2Prefix) {
                        return key1Index < key2Index
                    } else {
                        return key1 < key2
                    }                
                }
            }

            for key in sortedKeys {
                let value = stateDict[key]
                let desiredColonIndex = 6 + 25 * rowIndex

                // add spaces so the next column is at the desired index
                let spacesToAdd = desiredColonIndex - rowString.count - key.count
                if spacesToAdd > 0 {
                    rowString += String(repeating: " ", count: spacesToAdd)
                }

                if let rowValue = stateDict[key] {
                    rowString += "\(key): \(rowValue)"
                }

                rowIndex += 1

                let desiredRowCount = key.prefix(1) == "x" ? 4 : 3
                if rowIndex == desiredRowCount {
                    rowIndex = 0
                    output += "\(rowString)\n"
                    rowString = ""
                }
            }
            output += "\(rowString)\n"
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
    
    // Note: Add any additional keys that Json4Swift_Base might need to mirror.
}