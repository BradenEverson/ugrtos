//! Static Random Number Generation

const std = @import("std");
const time = @import("time.zig");

var prng: ?std.Random.DefaultPrng = null;

pub inline fn getRand() std.Random {
    if (prng) |*r| {
        return r.random();
    } else {
        // prng = .init(@as(u64, time.getTimeMicros()));
        // prng = .init(0x90908797);
        // prng = .init(0xFBFBFBF);
        // prng = .init(0x0BBFDFD9);
        prng = .init(0xC238945B);
        // prng = .init(0xDEAD_BEEF_A201);
        // prng = .init(0xEEEEEEE);
        // prng = .init(0x4);

        // prng = .init(0x9); // THIS WORKS FOR CVG
        // prng = .init(0x4);

        // prng = .init(0xDEAD_BEEF_A201);
        return prng.?.random();
    }
}
