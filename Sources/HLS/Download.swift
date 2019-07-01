import Foundation
import MediaTools
import Executable
import Kwift

func retry<T>(body: @autoclosure () throws -> T, count: UInt = 3,
              onError: (UInt, Error) -> ()) rethrows -> T {
    for i in 0...count {
        do {
            let t = try body()
            return t
        } catch {
            if i == count {
                throw error
            } else {
                onError(i, error)
            }
        }
    }
    fatalError()
}

extension URL {
    
    func replacingLastComponent(_ str: String) -> URL {
        return deletingLastPathComponent().appendingPathComponent(str)
    }
    
}


private struct Aria2BatchDownload: Executable {
    static let executableName: String = "aria2c"
    let arguments: [String]
    
    init(inputFile: String, outputDir: String) {
        arguments = ["-i", inputFile, "-d", outputDir,
                     "-j", "10", "--file-allocation", "trunc", "--continue", "true"]
    }
}

extension Playlist {
    
    public func download(outputPath: String, tempPath: String) throws {
        try? FileManager.default.createDirectory(atPath: tempPath, withIntermediateDirectories: false, attributes: nil)
        switch self {
        case .media(let mediaP):
            let linkFile = tempPath.appendingPathComponent("\(UUID().uuidString).txt")
            try mediaP.segments.map { mediaP.url.deletingLastPathComponent().appendingPathComponent($0.uri).absoluteString}
                .joined(separator: "\n").write(toFile: linkFile, atomically: true, encoding: .utf8)
            let aria = Aria2BatchDownload.init(inputFile: linkFile, outputDir: tempPath)
            _ = try retry(body: try aria.runAndWait(checkNonZeroExitCode: true), onError: { (index, error) in
                
            })
            try MkvmergeMuxer.init(input: mediaP.segments.map { tempPath.appendingPathComponent($0.uri.lastPathComponent) }, output: outputPath, audioLanguages: [], subtitleLanguages: [], chapterPath: nil, extraArguments: [], cleanInputChapter: true).runAndWait(checkNonZeroExitCode: true)
        case .master(let masterP):
            let maxStream = masterP.playlists.max(by: {$0.streamInf.bandwidth < $1.streamInf.bandwidth})!
            let subP = try Playlist.init(url: masterP.url.replacingLastComponent(maxStream.uri))
            try subP.download(outputPath: outputPath, tempPath: tempPath)
            try maxStream.downloadSubtitles(baseURL: masterP.url, outputPrefix: outputPath.deletingPathExtension)
        }
    }
}
import MplsReader

struct Subtitle: Equatable {
    let start: Timestamp
    let end: Timestamp
    let text: String
}

import HTMLEntities

extension SubPlaylist {
    
    func downloadSubtitles(baseURL: URL, outputPrefix: String) throws {
        try subtitles.forEach { (subtitle) in
            
            //            if subtitle.name != "简体中文" { return [] }
            
            let m3u8 = baseURL.replacingLastComponent(subtitle.uri!)
            let playlist = try Playlist.init(url: m3u8)
            guard case .media(let media) = playlist else {
                fatalError()
            }
            var result = [Subtitle]()
            switch media.segments[0].uri.pathExtension {
            case "webvtt":
                try media.segments.forEach { (segment) in
                    let url = m3u8.replacingLastComponent(segment.uri)
                    let content = try String(contentsOf: url)
                    var needSub = false
                    var start: Timestamp?
                    var end: Timestamp?
                    var text = [String]()
                    var getSub = false
                    for line in content.components(separatedBy: .newlines) {
                        if line.isBlank {
                            continue
                        }
                        let parts = line.components(separatedBy: " ")
                        if parts.count >= 3, let s = Timestamp.init(parts[0]),
                            parts[1] == "-->", let e = Timestamp.init(parts[2]) {
                            if getSub {
                                let subtitle = Subtitle.init(start: start!, end: end!, text: text.joined(separator: "\n"))
                                
                                if let last = result.last, subtitle == last {
                                    print("duplicate sub: \(subtitle)")
                                } else {
                                    result.append(subtitle)
                                }
                                getSub = false
                                needSub = false
                                text = []
                            }
                            needSub = true
                            start = s
                            end = e
                        } else if needSub {
                            text.append(line.htmlUnescape())
                            getSub = true
                        }
                    }
                }
            default:
                fatalError()
            }
            
            // write
            try result.enumerated().map {
                """
                \($0.offset+1)
                \($0.element.start) --> \($0.element.end)
                \($0.element.text)
                
                """
                }.joined(separator: "\n").write(toFile: outputPrefix.appendingPathExtension("\(subtitle.name).srt"), atomically: true, encoding: .utf8)
            
//            return result
        }
    }
    
}
