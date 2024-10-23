const std = @import("std");
const curl = @import("curl");
const iowrap = @import("iowrap.zig");
const http = @import("http.zig");
const utils = @import("utils.zig");

const GenericLoader = @import("loaders.zig").GenericLoader;

// gets the modrinth commands as a generichost
pub fn generic_loader() GenericLoader {
    return GenericLoader {
        .id = "neoforge",
        .vtable = .{
            .versions = versions,
            .latest = latest,
        }
    };
}

const NeoforgeVersions = struct {
    isSnapshot: bool,
    versions: [][]u8,
};
pub fn versions(alloc: std.mem.Allocator, easy: *const curl.Easy, io: iowrap.IO) [][]u8 {
    const neoforge_resp = easy.get("https://maven.neoforged.net/api/maven/versions/releases/net/neoforged/neoforge") catch {
        io.errorl("left on read by neoforge :(", .{});
        @panic("left on read by neoforge :(");
    };
    defer neoforge_resp.deinit();

    if(http.Status.expect(neoforge_resp.status_code, .ok)) {
        const versions_parsed = std.json.parseFromSliceLeaky(NeoforgeVersions, alloc, neoforge_resp.body.?.items, .{ .ignore_unknown_fields = true }) 
        catch | err |{
            io.errorl("failed to parse neoforge versions : {}", .{ err });
            @panic("failed to parse neoforge versions");
        };
        return versions_parsed.versions;
    } else {
        io.errorl("failed to get neoforge versions! status code: {}", .{ neoforge_resp.status_code });
        @panic("neoforge invalid response!");
    }
}

pub fn latest(io: iowrap.IO, mc_ver: utils.McVersion, available_versions: [][]const u8) ?[]const u8 {
    if(!std.mem.eql(u8, mc_ver.type, "release")) {
        io.errorl("neoforge only supports release versions of minecraft!", .{});
        return null;
    }
    const mc_semver = utils.string_to_semver(mc_ver.id) catch | err |{
        io.errorl("could not parse {s} semver! {}", .{ mc_ver.id, err });
        return null;
    };
    
    var version : ?[]const u8 = null;
    for(available_versions) | neo_version | {
        const neo_semver = utils.string_to_semver(neo_version) catch utils.SemVer { .major = 0, .minor = 0, .patch = 0, .extended = "" };
        if(neo_semver.major == mc_semver.minor and neo_semver.minor == mc_semver.patch) {
            version = neo_version;
        }
    }
    return version;
}