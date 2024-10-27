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
    _ = args.next().?;

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
            const new_pack_info = pack.create_new(allocator, io, &easy) catch | err | {
                io.errorl("failed to create new packme pack! : {}", .{ err });
                return;
            };

            const was_saved = pack.save_pack_info(new_pack_info, io, true) catch | err | {
                io.errorl("failed to save packinfo : {}", .{ err });
                return;
            };

            if(!was_saved) {
                io.color_yellow();
                io.printl("warning: didn't save packme pack info!", .{});
                io.reset();
            }

            io.color_green();
            io.printl("Created a new packme project named {s} using {s}({s}) on {s}", .{ new_pack_info.pack_name, new_pack_info.loader, new_pack_info.loader_ver, new_pack_info.mc_ver });
            io.reset();
            return;
        }

        io.errorl("invalid command {s}", .{ command });
        return;
    }
    io.errorl("no command given!", .{}); //TODO when we add a help command we should notify the user to use that for help
}