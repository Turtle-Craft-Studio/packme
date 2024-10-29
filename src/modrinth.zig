const std = @import("std");
const curl = @import("curl");
const http = @import("http.zig");
const modrinth = @import("modrinth.zig");
const iowrap = @import("iowrap.zig");
const pack = @import("pack.zig");
const mod_hosts = @import("mod_hosts.zig");

const GenericHost = @import("mod_hosts.zig").GenericHost;
const HostedMod = @import("mod_hosts.zig").HostedMod;

// gets the modrinth commands as a generichost
pub fn generic_host() GenericHost {
    return GenericHost {
        .id = "modrinth",
        .vtable = .{
            .about = about,
            .add = add,
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
        io.errorl("no project specified please pass a poject id/slug 'packme modrinth about id/slug'", .{});
    }
}

pub const ProjectVersions = []ProjectVersion;
pub const ProjectVersion = struct {
    game_versions: [][]const u8,
    loaders: [][]const u8,
    id: []const u8,
    name: []const u8,
    date_published : []const u8,
};

fn add(easy: *const curl.Easy, args: *std.process.ArgIterator,  io: iowrap.IO) void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    if(args.next()) | mod_id | {
        const pack_info = pack.load_pack_info(allocator, io) catch | err | {
            io.errorl("failed to load packinfo : {}", .{ err });
            return;
        };
        const versions_url = std.fmt.allocPrintZ(allocator, "https://api.modrinth.com/v2/project/{s}/version?loaders=[%22{s}%22]&game_versions=[%22{s}%22]", .{ mod_id, pack_info.loader, pack_info.mc_ver }) catch @panic("OOM");
        const versions_resp = easy.get(versions_url) catch {
            io.errorl("failed to get {s}", .{ versions_url });
            return;    
        };
        defer versions_resp.deinit();

        if(http.Status.expect(versions_resp.status_code, .ok)) {
            const versions = std.json.parseFromSliceLeaky(ProjectVersions, allocator, versions_resp.body.?.items, .{ .ignore_unknown_fields = true }) catch | err | {
                io.errorl("failed to parse {s} modrinth project versions! : {}", .{ mod_id, err });
                return;
            };
            if(versions.len == 0) {
                io.errorl("no valid versons of {s} were found on modrinth", .{ mod_id });
                return;
            }
            // verify and grab most recent valid version
            for(versions) | version | {
                for(version.loaders) | loader | {
                    if(std.mem.eql(u8, loader, pack_info.loader)) break;
                } else continue;
                for(version.game_versions) | mc_ver | {
                    if(std.mem.eql(u8, mc_ver, pack_info.mc_ver)) break;
                } else continue;

                // we found a valid version so we save it to disk
                const hosted_mod = HostedMod{
                    .host = "modrinth",
                    .id = mod_id,
                    .version_id = version.id,
                    .version_name = version.name,
                    .date_published = version.date_published,
                    .loaders = version.loaders,
                    .game_versions = version.game_versions,
                };
                pack.mod_add_or_add_host(allocator, mod_id, hosted_mod) catch | err | {
                    io.errorl("failed to add {s} to pack! : {}", .{ mod_id, err });
                };
                return;
            } else {
                io.errorl("failed to verify a valid mod version for {s}", .{ mod_id });
            }
        } else io.errorl("could not get {s} versions from modrinth : error{}", .{ mod_id, versions_resp.status_code });
    } else {
        io.errorl("no project specified please pass a poject id/slug 'packme modrinth about id/slug'", .{});
    }
}