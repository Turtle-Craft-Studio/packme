pub const Loaders = enum {
    neoforge,
    //fabric,
    //forge,
    //quilt,
};

pub const PackInfo = struct {
    format_ver: i32 = 1,
    pack_name: []u8 = "New Pack",
    mc_ver: []u8 = "1.21.1",
    loader: Loaders = .neoforge,
    loader_ver: "21.1.72",
};

pub fn create_new() PackInfo {

}

pub fn load_pack() PackInfo {
    
}