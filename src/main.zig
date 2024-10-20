const std = @import("std");
const curl = @import("curl");

const iowrap = @import("iowrap.zig");

const mod_hosts = @import("mod_hosts.zig");
const loaders = @import("loaders.zig");
const utils = @import("utils.zig");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    const io = iowrap.IO.init();
    
    const easy = try curl.Easy.init(allocator, .{});
    defer easy.deinit();

    var args = try std.process.argsWithAllocator(allocator);
    const working_dir = args.next().?;
    io.printl("{s}", .{ working_dir });

    const mc_versions = try utils.get_mc_versions(allocator, &easy, io);
    io.printl("latest mc release: {s}", .{ mc_versions.latest.release });

    const neo_versions = loaders.neoforge_loader.vtable.versions(allocator, &easy, io);

    io.printl("Neoforge versions: ", .{});
    for(neo_versions) | version | {
        io.printl(" {s}", .{ version });
    }


    if(args.next()) | command | {
        for(mod_hosts.hosts) | host | {
            if(std.mem.eql(u8, command, host.id)) {
                if(args.next()) | action | {
                    if(std.mem.eql(u8,action, "about")) host.vtable.about(&easy, &args, io)
                    else io.errorl("invalid action {s}", .{ action });

                } else io.errorl("no action specified. for help run: {s} help", .{ host.id });
                return;
            }
        }
        
        io.errorl("invalid command {s}", .{ command });
        return;
    }
}