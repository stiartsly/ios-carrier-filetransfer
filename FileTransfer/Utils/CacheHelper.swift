
import Foundation

let time = Timestamp.getTimeAtNow()
var sendPath = NSHomeDirectory() + "/Library/Caches/" + "send_\(time)"
var receivePath = NSHomeDirectory() + "/Library/Caches/" + "receive_\(time)"

class CacheHelper: NSObject {


    class func saveCache(_ path: String, _ data: Data) {
        let fileManager = FileManager.default
        let exist = fileManager.fileExists(atPath: path)
        if !exist {
            fileManager.createFile(atPath: path, contents: nil, attributes: nil)
            let writeHandle = FileHandle(forWritingAtPath: path)
            writeHandle?.seek(toFileOffset: 0)
            writeHandle?.write(data)
        }
    }

    class func saveCache(_ path: String, offset: Int, _ data: Data) {
        let fileManager = FileManager.default
        let exist = fileManager.fileExists(atPath: path)
        if !exist {
            fileManager.createFile(atPath: path, contents: nil, attributes: nil)
        }
        let writeHandle = FileHandle(forWritingAtPath: path)
        writeHandle?.seek(toFileOffset: UInt64(offset))
        writeHandle?.write(data)
    }

    class func readCache(_ path: String, _ size: Int, index: Int, count: Int) -> Data {
        let offset = index * size
        let readHandle = FileHandle(forReadingAtPath: path)
        readHandle?.seek(toFileOffset: UInt64(offset))
        var data = Data()
        if index == count - 1 {
            data = (readHandle?.readDataToEndOfFile())!
        }
        else {
            data = (readHandle?.readData(ofLength: size))!
        }
        return data
    }

    class func readCache(_ path: String) -> Data {
        let readHandle = FileHandle(forReadingAtPath: receivePath)
        readHandle!.seek(toFileOffset: 0)
        let data = (readHandle?.readDataToEndOfFile())!
        return data
    }

    class func clearCache(_ path: String) {
        let fileManager = FileManager.default
        let exist: Bool = fileManager.fileExists(atPath: path)
        if exist {
            do {
                try fileManager.removeItem(atPath: path)
            }
            catch {}
        }
    }
}
