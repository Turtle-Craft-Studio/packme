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
                    else if(std.mem.eql(u8,action, "help")) host.vtable.help(&args, io)
                    else if(std.mem.eql(u8,action, "add")) host.vtable.add(&easy, &args, io)
                    else io.errorl("invalid action {s}", .{ action });

                } else io.errorl("no action specified. for help run: {s} help", .{ host.id });
                return;
            }
        }
        if(std.mem.eql(u8, command, "init")) {
            pack.init_command(allocator, io, &args, &easy);
            return;
        }
        if(std.mem.eql(u8, command, "info")) {
            pack.info_command(allocator, io);
            return;
        }
        if(std.mem.eql(u8, command, "list")) {
            pack.list_mods_command(allocator, io);
            return;
        }

        io.errorl("invalid command {s}", .{ command });
        return;
    }
    io.errorl("no command given!", .{}); //TODO when we add a help command we should notify the user to use that for help
}