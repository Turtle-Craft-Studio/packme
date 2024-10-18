// a wrapper around IO to make it a bit simpler for our usecase!
const std = @import("std");

pub const IO = struct {
    const Self = @This();

    stdout_file: std.fs.File.Writer,

    pub fn init() Self {
        return .{
            .stdout_file = std.io.getStdOut().writer()
        };
    }

    pub fn print(self: Self, comptime format: []const u8, args: anytype) void {
        self.stdout_file.print(format, args) catch @panic("stdout failure");
    }
    pub fn printl(self: Self, comptime format: []const u8, args: anytype) void {
        self.stdout_file.print(format, args) catch @panic("stdout failure");
        self.stdout_file.print("\n", .{}) catch @panic("stdout failure");
    }
    pub fn errorl(self: Self, comptime format: []const u8, args: anytype) void {
        self.color_red();
        self.printl(format, args);
        self.reset();
    }
    
    pub fn color_red(self: Self) void {
        self.stdout_file.print("\x1b[31m", .{}) catch @panic("stdout failure");
    }
    pub fn color_green(self: Self) void {
        self.stdout_file.print("\x1b[32m", .{}) catch @panic("stdout failure");
    }
    pub fn color_yellow(self: Self) void {
        self.stdout_file.print("\x1b[33m", .{}) catch @panic("stdout failure");
    }

    // reset all formatting
    pub fn reset(self: Self) void {
        self.stdout_file.print("\x1b[0m", .{}) catch @panic("stdout failure");
    }
};