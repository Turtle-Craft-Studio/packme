const std = @import("std");
const curl = @import("curl");
const http = @import("http.zig");
const modrinth = @import("modrinth.zig");
const iowrap = @import("iowrap.zig");

const GenericHost = @import("mod_hosts.zig").GenericHost;

// gets the modrinth commands as a generichost
pub fn generic_host() GenericHost {
    return GenericHost {
        .id = "modrinth",
        .vtable = .{
            .about = about,
            .help = help,
        }
    };
}

fn help(args: *std.process.ArgIterator,  io: iowrap.IO) void {
    _ = args;
    GenericHost.GenericHelpMessage(io);
}


pub const Project = struct {
    slug: []const u8,
    title: []const u8,
    description: []const u8,
    game_versions: [][]const u8,
    loaders: [][]const u8,
    versions: [][]const u8,
};

fn about(easy: *const curl.Easy, args: *std.process.ArgIterator,  io: iowrap.IO) void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    if(args.next()) | project_arg |{
        const project_url = std.fmt.allocPrintZ(allocator, "https://api.modrinth.com/v2/project/{s}", .{ project_arg }) catch @panic("OOM");
        defer allocator.free(project_url);

        const project_resp = easy.get(project_url) catch {
            io.errorl("didn't recieve a response from {s}", .{ project_url });
            return;    
        };

        defer project_resp.deinit();

        if(http.Status.expect(project_resp.status_code, .ok)) {
            const project_parsed = std.json.parseFromSliceLeaky(modrinth.Project, allocator, project_resp.body.?.items, .{ .ignore_unknown_fields = true }) 
            catch | err |{
                io.errorl("failed to parse json returned from {s} : {}", .{ project_url, err });
                return;
            };

            io.printl("About {s}:", .{ project_parsed.title }); 
            io.printl("{s}", .{ project_parsed.description }); 
            io.print("Suported Loaders: \n", .{}); 
            for(project_parsed.loaders) | loader | {
                io.printl("  {s}", .{ loader });
            }
            io.printl("Supported Versions:", .{}); 
            for(project_parsed.game_versions) | version | {
                io.printl("  {s}", .{ version });
            }
        } else {
            io.errorl("modrinth project {s} not found. error {d}", .{ project_arg, project_resp.status_code });
        }
    } else {
        io.errorl("no project specified please pass a poject id/slug 'packme modrinth about pojectid'", .{});
    }
}