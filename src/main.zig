const std = @import("std");
const curl = @import("curl");

const http = @import("http.zig");
const utils = @import("utils.zig");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();
    
    const easy = try curl.Easy.init(allocator, .{});
    defer easy.deinit();


    const args = std.os.argv;
    if(args.len >= 2) {
        const first_arg : []const u8 = std.mem.span(args[1]);
        if(std.mem.eql(u8, first_arg, "modrinth")) {
            const test_resp = try easy.get("https://api.modrinth.com/");
            defer test_resp.deinit();

            if(http.Status.expect(test_resp.status_code, .ok)) {
                if(args.len >= 3) {
                    const project_arg : []const u8 = std.mem.span(args[2]);

                    const project_url = try std.fmt.allocPrintZ(allocator, "https://api.modrinth.com/v2/project/{s}", .{ project_arg });
                    defer allocator.free(project_url);

                    const project_resp = try easy.get(project_url);
                    defer project_resp.deinit();

                    if(http.Status.expect(project_resp.status_code, .ok)) {
                        try stdout.print("project found!\n{s}\n", .{ project_resp.body.?.items }); 
                    } else {
                        try utils.print_err(stdout, "modrinth project {s} not found. error {d}\n", .{ project_arg, project_resp.status_code });
                    }
                }

            } else {
                try utils.print_err(stdout, "modrinth gave invalid status: {d}\n", .{ test_resp.status_code });
            }
        } else {
            try utils.print_err(stdout, "invalid arg {s}\n", .{ first_arg });
        }
    }
    try bw.flush();
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
