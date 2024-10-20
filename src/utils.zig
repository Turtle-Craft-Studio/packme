const std = @import("std");
const Allocator = std.mem.Allocator;

const http = @import("http.zig");
const curl = @import("curl");
const iowrap = @import("iowrap.zig");

const fallback_mc_ver = "1.21.1";


pub const LatestVersions = struct {
    release: []u8,
    snapshot: []u8,
};
pub const McVersion = struct {
    id: []u8,
    type: []u8,
    url: []u8,
    time: []u8,
    releaseTime: []u8,
};
pub const McVersions = struct {
    latest: LatestVersions,
    versions: []McVersion,
};

pub fn get_mc_versions(alloc: Allocator, easy: *const curl.Easy, io: iowrap.IO) !McVersions {
    const mojang_resp = try easy.get("https://launchermeta.mojang.com/mc/game/version_manifest.json");
    defer mojang_resp.deinit();
    if(http.Status.expect(mojang_resp.status_code, .ok)) {
        const versions_parsed = std.json.parseFromSliceLeaky(McVersions, alloc, mojang_resp.body.?.items, .{ .ignore_unknown_fields = true }) 
        catch | err |{
            io.errorl("failed to parse version_manifest : {}", .{ err });
            return err;
        };
        return versions_parsed;
    } else {
        return error.invalid_response_from_mojang;
    }
}