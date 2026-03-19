const std = @import("std");
const Terminal = @import("aether_lib").Terminal;

test "Line Drawing Charset (ESC ( 0)" {
    var term = try Terminal.init(std.testing.allocator, 24, 80, 100);
    defer term.deinit();

    // Enable Line Drawing on G0
    try term.writeInput("\x1B(0");
    // Print 'q' (should be horizontal line '─')
    try term.writeInput("q");
    
    if (term.grid.getCell(0, 0)) |cell| {
        try std.testing.expectEqual(@as(u32, '─'), cell.codepoint);
    }
    
    // Switch back to US ASCII
    try term.writeInput("\x1B(Bq");
    if (term.grid.getCell(0, 1)) |cell| {
        try std.testing.expectEqual(@as(u32, 'q'), cell.codepoint);
    }
}

test "Alt Buffer Swapping and Restore" {
    var term = try Terminal.init(std.testing.allocator, 24, 80, 100);
    defer term.deinit();

    // Write something to main buffer
    try term.writeInput("Main Content");
    
    // Enter Alt Buffer
    try term.writeInput("\x1B[?1049h");
    
    // Grid should be empty
    if (term.grid.getCell(0, 0)) |cell| {
        try std.testing.expectEqual(@as(u32, ' '), cell.codepoint);
    }
    
    try term.writeInput("Alt Content");
    
    // Exit Alt Buffer
    try term.writeInput("\x1B[?1049l");
    
    // Main Content should be restored
    const expected = "Main Content";
    for (expected, 0..) |c, i| {
        if (term.grid.getCell(0, @intCast(i))) |cell| {
            try std.testing.expectEqual(@as(u32, c), cell.codepoint);
        }
    }
}

test "DA2 (Secondary Device Attributes)" {
     var term = try Terminal.init(std.testing.allocator, 24, 80, 100);
     defer term.deinit();
     
     // This would require a mock PTY to check output, but we can verify it doesn't crash
     try term.writeInput("\x1B[>c");
}
