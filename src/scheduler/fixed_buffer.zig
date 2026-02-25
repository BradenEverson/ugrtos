//! Fixed Buffer ArrayList-like Structure

const std = @import("std");

pub const FixedBufferError = error{
    BufferFull,
};

pub fn FixedBufferArrayList(T: type, max: comptime_int) type {
    return struct {
        vals: [max]T = undefined,
        len: usize = 0,

        const Self = @This();

        pub fn append(self: *Self, val: T) !void {
            if (self.len == self.vals.len) return error.BufferFull;

            self.vals[self.len] = val;
            self.len += 1;
        }
    };
}

test "FixedBuffer init" {
    const TenIntBuffer = FixedBufferArrayList(i32, 10);

    var foo = TenIntBuffer{};
    try foo.append(0);

    const val = foo.vals[0];

    try std.testing.expectEqual(0, val);

    try foo.append(1);
    try foo.append(2);
    try foo.append(3);
    try foo.append(4);
    try foo.append(5);
    try foo.append(6);
    try foo.append(7);
    try foo.append(8);
    try foo.append(9);

    const err = foo.append(10);

    try std.testing.expectError(error.BufferFull, err);
}
