const std = @import("std");
const curl = @import("curl");
const iowrap = @import("iowrap.zig");

const modrinth = @import("modrinth.zig");
pub const modrinth_host =  modrinth.generic_host();

pub const hosts = [1]GenericHost{ modrinth_host };

// a generic API for interacting with host
pub const GenericHost = struct {
    id: []const u8,
    vtable: VTable,

    pub const VTable = struct {
        about: *const fn (easy: *const curl.Easy, args: *std.process.ArgIterator, io: iowrap.IO) void, // print project information about a mod
    };
};