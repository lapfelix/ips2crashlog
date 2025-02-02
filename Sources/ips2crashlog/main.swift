import Foundation
import ArgumentParser

struct IPS2CrashLog: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "ips2crashlog",
        abstract: "Convert Apple's IPS crash reports to human readable crash logs"
    )

    @Argument(help: "Path to the IPS crash report file")
    var input: String

    @Option(name: .shortAndLong, help: "Output path (optional)")
    var output: String?

    func run() throws {
        let converter = IPSConverter()
        try converter.convert(inputPath: input, outputPath: output)
    }
}

IPS2CrashLog.main()