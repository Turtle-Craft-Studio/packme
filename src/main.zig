const std = @import("std");
const curl = @import("curl");
const http = @import("http.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer if (gpa.deinit() != .ok) @panic("leak");
    const allocator = gpa.allocator();

    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();
    
    const easy = try curl.Easy.init(allocator, .{});
    defer easy.deinit();

    const resp = try easy.get("https://staging-api.modrinth.com/");
    defer resp.deinit();

    if(resp.status_code == @intFromEnum(http.Status.ok)) {
        try stdout.print("Modrinth response: {s}\n", .{ resp.body.?.items });

    } else {
        try stdout.print("Modrinth status: {d}\n", .{ resp.status_code });
    }
    
    try bw.flush();
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
