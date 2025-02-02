/* 
Copyright (c) 2025 Swift Models Generated from JSON powered by http://www.json4swift.com

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

For support, please feel free to contact me at https://www.linkedin.com/in/syedabsar

*/

import Foundation
import ObjectMapper

struct Json4Swift_Base : Mappable {
	var uptime : Int?
	var procRole : String?
	var version : Int?
	var userID : Int?
	var deployVersion : Int?
	var modelCode : String?
	var coalitionID : Int?
	var osVersion : OsVersion?
	var captureTime : String?
	var codeSigningMonitor : Int?
	var incident : String?
	var pid : Int?
	var translated : Bool?
	var cpuType : String?
	var roots_installed : Int?
	var bug_type : String?
	var procLaunch : String?
	var procStartAbsTime : Int?
	var procExitAbsTime : Int?
	var procName : String?
	var procPath : String?
	var bundleInfo : BundleInfo?
	var storeInfo : StoreInfo?
	var parentProc : String?
	var parentPid : Int?
	var coalitionName : String?
	var crashReporterKey : String?
	var responsiblePid : Int?
	var responsibleProc : String?
	var codeSigningID : String?
	var codeSigningTeamID : String?
	var codeSigningFlags : Int?
	var codeSigningValidationCategory : Int?
	var codeSigningTrustLevel : Int?
	var instructionByteStream : InstructionByteStream?
	var bootSessionUUID : String?
	var wakeTime : Int?
	var sleepWakeUUID : String?
	var sip : String?
	var exception : Exception?
	var termination : Termination?
	var os_fault : Os_fault?
	var extMods : ExtMods?
	var faultingThread : Int?
	var threads : [Threads]?
	var usedImages : [UsedImages]?
	var sharedCache : SharedCache?
	var vmSummary : String?
	var legacyInfo : LegacyInfo?
	var logWritingSignature : String?
	var trialInfo : TrialInfo?

	init?(map: Map) {

	}

	mutating func mapping(map: Map) {

		uptime <- map["uptime"]
		procRole <- map["procRole"]
		version <- map["version"]
		userID <- map["userID"]
		deployVersion <- map["deployVersion"]
		modelCode <- map["modelCode"]
		coalitionID <- map["coalitionID"]
		osVersion <- map["osVersion"]
		captureTime <- map["captureTime"]
		codeSigningMonitor <- map["codeSigningMonitor"]
		incident <- map["incident"]
		pid <- map["pid"]
		translated <- map["translated"]
		cpuType <- map["cpuType"]
		roots_installed <- map["roots_installed"]
		bug_type <- map["bug_type"]
		procLaunch <- map["procLaunch"]
		procStartAbsTime <- map["procStartAbsTime"]
		procExitAbsTime <- map["procExitAbsTime"]
		procName <- map["procName"]
		procPath <- map["procPath"]
		bundleInfo <- map["bundleInfo"]
		storeInfo <- map["storeInfo"]
		parentProc <- map["parentProc"]
		parentPid <- map["parentPid"]
		coalitionName <- map["coalitionName"]
		crashReporterKey <- map["crashReporterKey"]
		responsiblePid <- map["responsiblePid"]
		responsibleProc <- map["responsibleProc"]
		codeSigningID <- map["codeSigningID"]
		codeSigningTeamID <- map["codeSigningTeamID"]
		codeSigningFlags <- map["codeSigningFlags"]
		codeSigningValidationCategory <- map["codeSigningValidationCategory"]
		codeSigningTrustLevel <- map["codeSigningTrustLevel"]
		instructionByteStream <- map["instructionByteStream"]
		bootSessionUUID <- map["bootSessionUUID"]
		wakeTime <- map["wakeTime"]
		sleepWakeUUID <- map["sleepWakeUUID"]
		sip <- map["sip"]
		exception <- map["exception"]
		termination <- map["termination"]
		os_fault <- map["os_fault"]
		extMods <- map["extMods"]
		faultingThread <- map["faultingThread"]
		threads <- map["threads"]
		usedImages <- map["usedImages"]
		sharedCache <- map["sharedCache"]
		vmSummary <- map["vmSummary"]
		legacyInfo <- map["legacyInfo"]
		logWritingSignature <- map["logWritingSignature"]
		trialInfo <- map["trialInfo"]
	}

}