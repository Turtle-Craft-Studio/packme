const std = @import("std");
const curl = @import("curl");
const iowrap = @import("iowrap.zig");
const utils = @import("utils.zig");
const loaders = @import("loaders.zig");
const mod_hosts = @import("mod_hosts.zig");

pub const PackInfo = struct {
    format_ver: u32 = 1,
    pack_name: []const u8 = "New Pack",
    mc_ver: []const u8 = "1.21.1",
    loader: []const u8 = "neoforge",
    loader_ver: []const u8 = "21.1.72",
};

pub const Mod = struct {
    format_ver: u32 = 1,
    host: []mod_hosts.HostedMod
};

pub const PackCreationError = error {
    InvalidDirectory,
    InvalidMinecraftVersion,
    NoLoaderVersionFound,
    UnknownModLoader,
    FailedToGetMinecraftVersions,
};

pub fn init_command(allocator: std.mem.Allocator, io: iowrap.IO, args: *std.process.ArgIterator, easy: *const curl.Easy) void {
    if(args.next()) | next_arg | {
        if(!std.mem.eql(u8, next_arg, "help")) io.errorl("invalid option: {s}", .{ next_arg });
        io.printl("packme init - initializes a directory and starts the packme creation wizard", .{});
        return;
    }
    const new_pack_info = create_new(allocator, io, easy) catch | err | {
        io.errorl("failed to create new packme pack! : {}", .{ err });
        return;
    };

    const was_saved = save_pack_info(new_pack_info, io, true) catch | err | {
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
}
// prints info about the packme pack
pub fn info_command(allocator: std.mem.Allocator, io: iowrap.IO) void {
    const pack_info_error =  load_pack_info(allocator, io);
    if(pack_info_error) | pack_info | {
        io.printl("packme.json:", .{});
        io.printl(" Format Version: {}", .{ pack_info.format_ver });
        io.printl(" Name: {s}", .{ pack_info.pack_name });
        io.printl(" MC Version: {s}", .{ pack_info.mc_ver });
        io.printl(" Loader: {s}", .{ pack_info.loader });
        io.printl(" Loader Version: {s}", .{ pack_info.loader_ver });
    } else | err | {
        io.errorl("failed to load packme.json : {}", .{ err });
    }
}
pub fn list_mods_command(allocator: std.mem.Allocator, io: iowrap.IO) void {
    var mod_dir = open_mods_dir() catch | err | {
        io.errorl("could not open mods directory! : {}", .{ err });
        return;
    };
    defer  mod_dir.close();

    var mod_iter = mod_dir.iterate();
    while(
        mod_iter.next() catch | err | { 
            io.errorl("failed to iter mods directory! : {}", .{ err });
            return;
        }
    ) | entry | {
        if(entry.kind != .file) {
            io.warningl("warning: {s} is not a file, may not be indexed correctly", .{ entry.name });
            continue;
        }
        const ext = std.fs.path.extension(entry.name);
        if(ext.len != 0) {
            io.warningl("warning: {s} is a {s}, advance indexing features will not work with this mod", .{ entry.name, ext });
            continue;
        }

        const mod = load_mod_from_disk(allocator, entry.name) catch | err | {
            io.errorl("could not index mod {s} : {}", .{ entry.name, err });
            continue;
        };

        io.printl("{s}:", .{ entry.name });
        for(mod.host) | hosted_mod | {
            io.printl(" - {s}: {s} - {s}({s})", .{ hosted_mod.host, hosted_mod.id, hosted_mod.version_name, hosted_mod.version_id });
        }
        
    }
}
// starts a creation wizard for a new packme pack
pub fn create_new(allocator: std.mem.Allocator, io: iowrap.IO, easy: *const curl.Easy) PackCreationError!PackInfo {
    io.color_green();
    io.printl("Welcome to the packme creation wizard!(default)", .{});
    io.reset();

    const default_pack_name = "New Pack";
    io.print("pack name({s}):", .{ default_pack_name });
    const input_pack_name = io.in(allocator) catch default_pack_name;
    const pack_name = if(input_pack_name.len == 0)default_pack_name else input_pack_name;

    const mc_versions = utils.get_mc_versions(allocator, easy, io) catch | err |{
        io.errorl("failed to get minecraft versions! {}", .{ err });
        return error.FailedToGetMinecraftVersions;
    };

    io.print("minecraft version({s}):", .{ mc_versions.latest.release });
    const input_mc_ver_id = io.in(allocator) catch mc_versions.latest.release;
    const mc_ver_id = if(input_mc_ver_id.len == 0) mc_versions.latest.release else input_mc_ver_id;

    // verify minecraft version
    if(mc_versions.get(mc_ver_id)) | mc_ver | {
        const default_loader : []const u8 = if(std.mem.eql(u8, mc_ver.type, "release")) "neoforge" else "unknown";
    
        io.print("loader({s}):", .{ default_loader });
        const input_loader_id = io.in(allocator) catch default_loader;
        const loader_id = if(input_loader_id.len == 0) default_loader else input_loader_id;

        const loader = loaders.get(loader_id) catch {
            io.errorl("unknown mod loader {s}", .{ loader_id });
            io.errorl("if you think support for this loader should be added open a issue on github. otherwise create a packme.json file manually", .{});
            return error.UnknownModLoader;
        };

        if(loader.vtable.latest(io, mc_ver, loader.vtable.versions(allocator, easy, io))) | latest_loader_ver  | {
            io.print("loader version({s}):", .{ latest_loader_ver });
            const input_loader_ver = io.in(allocator) catch latest_loader_ver;
            const loader_ver = if(input_loader_ver.len == 0) latest_loader_ver else input_loader_ver;

            return PackInfo{
                .pack_name = pack_name,
                .mc_ver = mc_ver.id,
                .loader = loader.id,
                .loader_ver = loader_ver,
            };

        } else {
            io.errorl("no {s} verion found for {s}", .{ loader_id, mc_ver_id });
            return error.NoLoaderVersionFound;
        }

    } else {
        io.errorl("unknown minecraft version {s}", .{ mc_ver_id });
        io.errorl("if this is not an official mojang version you must manually create a packme.json file", .{});
        return error.InvalidMinecraftVersion;
    }
}

// loads a pack info file from disk
pub fn load_pack_info(allocator: std.mem.Allocator, io: iowrap.IO) !PackInfo {
    const file = std.fs.cwd().openFile("packme.json", .{}) catch | err | {
        switch (err) {
            std.fs.Dir.OpenError.FileNotFound => {
                io.errorl("no packme.json found. please run packme init", .{});
                return err;
            },
            else => { return err; }
        }
    };
    const json = try file.readToEndAlloc(allocator, std.math.maxInt(usize));
    const pack_info = try std.json.parseFromSliceLeaky(PackInfo, allocator, json, .{});
    return pack_info;
}

// saves pack info to disk as a json file
pub fn save_pack_info(info: PackInfo, io: iowrap.IO, warn_before_overwrite: bool) !bool {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const out_json = try std.json.stringifyAlloc(allocator, info, .{ .whitespace = .indent_tab });

    var file_found = true;
    std.fs.cwd().access("packme.json", .{}) catch | err | {
        switch (err) {
            std.fs.Dir.AccessError.FileNotFound => { file_found = false; },
            else => { return err; },
        }
    };
    if(file_found) {
        if(warn_before_overwrite) {
            io.color_yellow();
            io.print("packme.json found! would you like to overwrite it y/n: ", .{});
            io.reset();
            const in = io.in(allocator) catch return false;
            if(in.len != 1) { return false; }
            if(in[0] == 'n') { return false; }
        }
        try std.fs.cwd().deleteFile("packme.json"); //TODO do we need to do this?
    }

    const new_file = try std.fs.cwd().createFile("packme.json", .{});
    _ = try new_file.write(out_json);
    new_file.close();
    return true;
}

pub const ModDirError = std.fs.Dir.OpenError || std.fs.Dir.MakeError;

// don't forget to close it!
pub fn open_mods_dir() ModDirError!std.fs.Dir {
    const open = std.fs.cwd().openDir("mods", .{ .iterate = true });
    if(open) | dir | return dir
    else | err | {
        if(err == std.fs.Dir.OpenError.FileNotFound) {
          try std.fs.cwd().makeDir("mods");
          // we just try to open it again now that we made the directory
          return open_mods_dir();
        } else return err;
    }
}

// add a mod to disk OR adds a host to a mod on disk
pub fn mod_add_or_add_host(allocator: std.mem.Allocator, aliased_id: []const u8, hosted_mod: mod_hosts.HostedMod) !void {
    //TODO: handle overriding of existing mods in a most graceful way. i.e get user confirmation before doing so
    //TODO: handle multiple mod host
    var mod_dir = try open_mods_dir();
    defer  mod_dir.close();

    if(mod_dir.access(aliased_id, .{})) {
        try mod_dir.deleteFile(aliased_id);
    } else | err | {
        if(err != std.fs.Dir.OpenError.FileNotFound)
            return err;
    }

    var hosted_mods : [1]mod_hosts.HostedMod = .{ hosted_mod  };
    const mod = Mod {
        .host = hosted_mods[0..1],
    };
    
    const out_json = try std.json.stringifyAlloc(allocator, mod, .{ .whitespace = .indent_tab });
    
    const new_file = try mod_dir.createFile(aliased_id, .{});
    defer new_file.close();
    _ = try new_file.write(out_json);
}

pub fn load_mod_from_disk(allocator: std.mem.Allocator, aliased_id: []const u8) !Mod {
    var mod_dir = try open_mods_dir();
    defer mod_dir.close();

    const file = try mod_dir.openFile(aliased_id, .{});
    defer file.close();

    const json = try file.readToEndAlloc(allocator, std.math.maxInt(usize));
    const mod = try std.json.parseFromSliceLeaky(Mod, allocator, json, .{});
    return mod;
}