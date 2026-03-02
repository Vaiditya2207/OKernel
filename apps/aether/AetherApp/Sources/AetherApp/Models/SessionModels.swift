import Foundation
import SwiftUI

// Represents the entire state of a saved session window
struct SavedSessionState: Codable, Identifiable {
    var id: UUID = UUID()
    let timestamp: Date
    let tabs: [SavedTab]
    let activeTabId: UUID?
}

struct SavedTab: Codable, Identifiable {
    let id: UUID
    let title: String
    let root: SavedPaneNode
    let activePaneId: UUID?
}

indirect enum SavedPaneNode: Codable {
    case pane(SavedPane)
    case split(id: UUID, axis: Axis, first: SavedPaneNode, second: SavedPaneNode, splitLocation: CGFloat)
}

struct SavedPane: Codable, Identifiable {
    static let maxHistoryRows = 500
    
    let id: UUID
    let cwd: String
    let title: String
    // History stored as binary-packed rows for compactness
    var history: [SavedRow]?
}

/// Each row stores cells as a packed binary Data blob instead of an array of Codable objects.
/// This reduces per-cell overhead from ~60 bytes (JSON) to exactly 14 bytes (binary).
struct SavedRow: Codable {
    /// Binary-packed cell data. Each cell is 14 bytes: UInt32 cp + UInt32 fg + UInt32 bg + UInt16 flags (little-endian).
    let cellData: Data
    let wrapped: Bool
    
    /// Pack an array of SavedCell into binary Data.
    static func pack(cells: [SavedCell]) -> Data {
        var data = Data(capacity: cells.count * 14)
        for cell in cells {
            var cp = cell.cp.littleEndian
            var fg = cell.fg.littleEndian
            var bg = cell.bg.littleEndian
            var f = cell.f.littleEndian
            data.append(Data(bytes: &cp, count: 4))
            data.append(Data(bytes: &fg, count: 4))
            data.append(Data(bytes: &bg, count: 4))
            data.append(Data(bytes: &f, count: 2))
        }
        return data
    }
    
    /// Unpack binary Data back into SavedCell array.
    func unpackCells() -> [SavedCell] {
        let cellSize = 14
        let count = cellData.count / cellSize
        var cells: [SavedCell] = []
        cells.reserveCapacity(count)
        
        for i in 0..<count {
            let offset = i * cellSize
            let cp = cellData.subdata(in: offset..<offset+4).withUnsafeBytes { $0.load(as: UInt32.self) }.littleEndian
            let fg = cellData.subdata(in: offset+4..<offset+8).withUnsafeBytes { $0.load(as: UInt32.self) }.littleEndian
            let bg = cellData.subdata(in: offset+8..<offset+12).withUnsafeBytes { $0.load(as: UInt32.self) }.littleEndian
            let f = cellData.subdata(in: offset+12..<offset+14).withUnsafeBytes { $0.load(as: UInt16.self) }.littleEndian
            cells.append(SavedCell(cp: cp, fg: fg, bg: bg, f: f))
        }
        
        return cells
    }
}

/// In-memory representation of a terminal cell. Not directly Codable for serialization —
/// use SavedRow.pack/unpack instead.
struct SavedCell {
    let cp: UInt32
    let fg: UInt32
    let bg: UInt32
    let f: UInt16
}

// Axis needs to be Codable
extension Axis: @retroactive Codable { }
