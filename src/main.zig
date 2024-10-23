const std = @import("std");
const curl = @import("curl");

const iowrap = @import("iowrap.zig");
const mod_hosts = @import("mod_hosts.zig");
const loaders = @import("loaders.zig");
const pack = @import("pack.zig");

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
        
        if(std.mem.eql(u8, command, "init")) {
            if(args.next()) | next_arg | {
                if(!std.mem.eql(u8, next_arg, "help")) io.errorl("invalid option: {s}", .{ next_arg });
                io.printl("packme init - initializes a directory and starts the packme creation wizard", .{});
                return;
            }
            const new_project = try pack.create_new(allocator, io, &easy);
            io.color_green();
            io.printl("Created a new packme project named {s} using {s}({s}) on {s}", .{ new_project.pack_name, new_project.loader, new_project.loader_ver, new_project.mc_ver });
            io.reset();
            return;
        }

        io.errorl("invalid command {s}", .{ command });
        return;
    }
    io.errorl("no command given!", .{}); //TODO when we add a help command we should notify the user to use that for help
}