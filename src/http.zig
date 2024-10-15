pub const Status = enum(i32) {
    ok = 200,

    pub fn expect(code: i32, expected: Status) bool {
        return code == @intFromEnum(expected);
    }
};