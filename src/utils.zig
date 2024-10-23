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

    pub fn get(self: @This(), id: []u8) ?McVersion {
        for(self.versions) | ver | {
            if(std.mem.eql(u8, ver.id, id)) return ver;
        }
        return null;
    }
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

pub const SemVer = struct {
    major: i32,
    minor: i32,
    patch: i32,
    extended: []const u8, 
}; // not sure this is "correct" but its good enough for packme's usecase
pub const SemVerError = error {
    InvalidString,
    FailedToParseInt
};
// small but important note, if your original string gets deallocated the "extended" portion of the SemVer will as well!
pub fn string_to_semver(str: []const u8) SemVerError!SemVer {
    const ParsingStages = enum {
        major, minor, patch,
        extended, complete,

        pub fn next(stage: @This()) @This() {
            switch (stage) {
                .major => { return @This().minor; },
                .minor => { return @This().patch; },
                .patch => { return @This().extended; },
                .extended => { return @This().complete; },
                .complete => unreachable,
            }
        }
    };

    var bookmark: usize = 0; // used for slicing the string without creating extra memory allocations
    var parse_stage = ParsingStages.major;
    var sem_ver: SemVer = undefined;
    for(str, 0..) | c, i | {
        if(parse_stage != .extended and parse_stage != .complete) {
            if(c == '.' or c == '-' or i == str.len-1) {
                const sliced = if(i == str.len-1) str[bookmark..(i+1)] else str[bookmark..i];
                const int = std.fmt.parseInt(i32, sliced, 10) catch { return SemVerError.FailedToParseInt; };

                switch (parse_stage) {
                    .major => { sem_ver.major = int; },
                    .minor => { sem_ver.minor = int; },
                    .patch => { sem_ver.patch = int; },
                    else => unreachable,
                }

                bookmark = i+1;
                parse_stage = parse_stage.next();
            }
        } 
        if(parse_stage == .extended) {
            if(i != str.len-1) {
                sem_ver.extended = str[i..str.len];
            } else {
                sem_ver.extended = str[str.len..str.len];
            }
            parse_stage = parse_stage.next();
        }
    }
    if(parse_stage != .complete) return SemVerError.InvalidString; //TODO better erroring?
    return sem_ver;
}