const std = @import("std");
const curl = @import("curl");
const iowrap = @import("iowrap.zig");
const http = @import("http.zig");

const GenericLoader = @import("loaders.zig").GenericLoader;

// gets the modrinth commands as a generichost
pub fn generic_loader() GenericLoader {
    return GenericLoader {
        .id = "modrinth",
        .vtable = .{
            .versions = versions,
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