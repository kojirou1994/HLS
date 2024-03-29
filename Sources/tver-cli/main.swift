import ArgumentParser
import Foundation
import URLFileManager
import SQLite

enum TverCategory: String, CustomStringConvertible {
  case feature
  case corner

  var description: String { rawValue }
}

enum TverArea: String, CustomStringConvertible, CaseIterable, ExpressibleByArgument {
  case drama
  case variety
  case documentary
  case anime
  case sport
  case other

  var description: String { rawValue }

  var name: String {
    switch self {
    case .drama:
      return "ドラマ"
    case .variety:
      return "バラエティ"
    case .documentary:
      return "報道・ドキュメンタリー"
    case .anime:
      return "アニメ"
    case .sport:
      return "スポーツ"
    case .other:
      return "その他"
    }
  }
}

struct TverCli: ParsableCommand {
  static var configuration: CommandConfiguration {
    .init(subcommands: [
      Batch.self,
      Download.self,
    ])
  }
}

extension TverCli {
  struct Batch: ParsableCommand {

    @Option
    var tmp: String?

    @Option
    var db: String?

    @Option(help: "Records expire days.")
    var cleanDbDay: Int?

    @Flag
    var reverse: Bool = false

    @Argument
    var areas: [TverArea] = TverArea.allCases

    func run() throws {

      let downloader = try TverDownloader(tmp: tmp)

      if let dbFile = db {
        let db = try Connection(dbFile)
        let tver = Table("tver")

        let id = Expression<String>("id")
        let date = Expression<Date>("date")
        let filename = Expression<String?>("filename")

        print("creating table if not exists.")
        try db.run(tver.create(ifNotExists: true) { t in
          t.column(id, primaryKey: true)
          t.column(date)
        })

        do { // migration 1: add filename column
          let stmt = try db.prepare("PRAGMA table_info(tver)")

          let columnNames = stmt.makeIterator().map { (row) -> String in
            return row[1] as? String ?? ""
          }

          let existed = columnNames.contains(where: { dbColumn -> Bool in
            dbColumn.caseInsensitiveCompare("filename") == .orderedSame
          })

          if !existed {
            print("adding filename column")
            try db.run(tver.addColumn(filename))
          }
        }

        // clean
        if let cleanDbDay = cleanDbDay {
          let query = tver
            .filter(date < Date().addingTimeInterval(-TimeInterval(cleanDbDay) * 3600 * 24))
            .delete()
          print("Cleaning expired records...")
          print(query.asSQL())
          try db.run(query)
          print("Run vacuum...")
          try db.vacuum()
        }

        downloader.shouldDownloadHref = { href in
          let query = tver
            .filter(id == href)
          let array = try! Array(db.prepareRowIterator(query))
          if array.count == 0 {
            // not existed
            return true
          } else {
            if (array.count != 1) {
              print("warning: why duplicate href id?")
            }
            print("already downloaded on \(try! array[0].get(date))")
            return false
          }
        }

        downloader.fileAlreadyExisted = { checkFilename in
          let query = tver
            .filter(filename == checkFilename)
            .count
          let count = try! db.scalar(query)
          return count != 0
        }

        downloader.didDownloadHref = { href, outputFilename in
          do {
            let query = tver.insert(id <- href, date <- Date(), filename <- outputFilename)
            try db.run(query)
          } catch {
            fatalError("\(error)")
          }
        }
      }

      for area in areas {
        do {
          let areaInfo = try downloader.load(area: area)
          let data = reverse ? areaInfo.data.reversed() : areaInfo.data
          print("totally \(data.count) medias")
          data.forEach { data in
            print(data)
          }
          data.forEach { data in
            do {
              try downloader.download(url: "https://tver.jp\(data.href)", area: area)
            } catch {
              print("Failed to download media \(data): \(error)")
            }
          }
        } catch {
          print("Failed to load area \(area)", error)
        }

      }

    }

  }

  struct Download: ParsableCommand {

    @Argument
    var urls: [String]

    func run() throws {

      let downloader = try TverDownloader(tmp: nil)

      for url in urls {
        do {
          try downloader.download(url: url, area: nil)
        } catch {
          print("Failed input: \(url)", error)
        }
      }

    }

  }
}
#if DEBUG
//dump(try JSONDecoder().decode(TverAreaInfo.self, from: Data(contentsOf: URL(fileURLWithPath: "/Volumes/KIOXIA/Tver/hls-download/tver_drama.txt"))))
let db = try Connection("/Volumes/T7_COMPILE/super_rich/tver.db")
let tver = Table("tver")

let id = Expression<String>("id")
let date = Expression<Date>("date")

try db.run(tver.create(ifNotExists: true) { t in
  t.column(id, primaryKey: true)
  t.column(date)
})

func find(href: String) -> Bool {
  let query = tver
    .filter(id == href)
  let array = try! Array(db.prepareRowIterator(query))
  if array.count == 0 {
    // not existed
    return true
  } else {
    if (array.count != 1) {
      print("warning: why duplicate href id?")
    }
    print("already downloaded on \(try! array[0].get(date))")
    return false
  }
}

func save(href: String) {
  do {
    let query = tver.insert(id <- href, date <- Date())
    try db.run(query)
  } catch {
    print("failed to insert the record: \(error), maybe re-download the media.")
  }
}

print(find(href: "a"))
save(href: "a")
print(find(href: "a"))
#endif

TverCli.main()
