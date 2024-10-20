const std = @import("std");
const curl = @import("curl");
const iowrap = @import("iowrap.zig");

const neoforge = @import("neoforge.zig");
pub const neoforge_loader =  neoforge.generic_loader();

pub const loaders = [1]GenericLoader { neoforge_loader };

// a generic API for getting loader info
pub const GenericLoader= struct {
    id: []const u8,
    vtable: VTable,

    pub const VTable = struct {
        versions: *const fn (alloc: std.mem.Allocator, easy: *const curl.Easy, io: iowrap.IO) [][]u8, // get all available versions of a loader
    };
};