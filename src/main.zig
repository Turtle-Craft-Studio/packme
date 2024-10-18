const std = @import("std");
const curl = @import("curl");

const http = @import("http.zig");
const modrinth = @import("modrinth.zig");
const modhost = @import("modhost.zig");
const iowrap = @import("iowrap.zig");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    const io = iowrap.IO.init();
    
    const easy = try curl.Easy.init(allocator, .{});
    defer easy.deinit();

    var args = try std.process.argsWithAllocator(allocator);
    if(args.next() == null) {
        io.errorl("no first arg? what the sigma did you do...", .{});
        return;
    }

    const modrinth_host =  modrinth.generichost();
    const modhosts = [1]modhost.GenericHost{ modrinth_host };

    if(args.next()) | command | {
        for(modhosts) | host | {
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