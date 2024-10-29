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
        add: *const fn (easy: *const curl.Easy, args: *std.process.ArgIterator, io: iowrap.IO) void, // adds a new mod
        help: *const fn(args: *std.process.ArgIterator, io: iowrap.IO) void,
    };

    pub fn GenericHelpMessage(io: iowrap.IO) void {
        io.printl("packme (modhost) : ", .{});
        io.printl(" - about (mod_id) : prints some basic information about the mod", .{});
        io.printl(" - add (mod_id) : adds the mod to the pack OR adds the host to the mod if you are using multiple host", .{});
    }
};

// used in serialization and in the future indexing
pub const HostedMod = struct {
    host: []const u8,
    id: []const u8,
    version_id: []const u8,

    // extra info to avoid extra API calls, maybe we could make this optional in the future if people want to hand write json for some reason?
    version_name: []const u8,
    date_published: []const u8,
    loaders: [][]const u8,
    game_versions: [][]const u8,
};