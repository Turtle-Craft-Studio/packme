const std = @import("std");
const curl = @import("curl");
const iowrap = @import("iowrap.zig");
const utils = @import("utils.zig");

const neoforge = @import("neoforge.zig");
pub const neoforge_loader =  neoforge.generic_loader();

pub const loaders = [1]GenericLoader { neoforge_loader };

pub const LoaderNotFounderror = error { LoaderNotFound };
pub fn get(id: []const u8) LoaderNotFounderror!GenericLoader {
    for(loaders) | loader | if(std.mem.eql(u8, loader.id, id)) return loader;
    return error.LoaderNotFound;
}

// a generic API for getting loader info
pub const GenericLoader= struct {
    id: []const u8,
    vtable: VTable,

    pub const VTable = struct {
        versions: *const fn (alloc: std.mem.Allocator, easy: *const curl.Easy, io: iowrap.IO) [][]u8, // get all available versions of a loader //NOTE: this return type is likely to change when more loaders are implemented
        latest: *const fn (io: iowrap.IO, mc_ver: utils.McVersion, available_versions: [][]const u8) ?[]const u8, // gets the latest version of the loader for a given minecraft version
    };
};