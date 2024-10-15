const std = @import("std");

pub fn color_red(writer: anytype) !void {
    try writer.print("\x1b[31m", .{});
}
pub fn color_reset(writer: anytype) !void {
    try writer.print("\x1b[0m", .{});
}
pub fn print_err(writer: anytype, comptime format: []const u8, args: anytype) !void {
    try color_red(writer);
    try writer.print(format, args);
    try color_reset(writer);
}