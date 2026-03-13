//! Discrete Q-Table Bins for CPU utilization percents
const std = @import("std");
const rand = @import("../hal/rand.zig");
const logger = @import("../hal/logger.zig");

/// Learning Rate
const ALPHA: f32 = 0.1;

/// Discount Factor, importance of future rewards
const GAMMA: f32 = 0.6;

/// Exploration rate, probability we try a random action
const EPSILON: f32 = 0.15;

/// Number of times we split up the CPU utilization percents
/// into discrete buckets
/// Ex: 10 buckets gives us 0-10%, 11-20%, ...
const BUCKETS: usize = 5;
const BUCKETS_F: f32 = @floatFromInt(BUCKETS);

const TOTAL_STATES = BUCKETS; // * BUCKETS;

pub const QAgent = extern struct {
    /// Includes IO as a second state dimension
    // pub inline fn getState(cpu_pct: f32, io_pct: f32) usize {
    //     const cpu_bucket = @min(@as(usize, @intFromFloat(cpu_pct * BUCKETS_F)), BUCKETS - 1);
    //     const io_bucket = @min(@as(usize, @intFromFloat(io_pct * BUCKETS_F)), BUCKETS - 1);
    //     return cpu_bucket + io_bucket * BUCKETS;
    // }

    pub inline fn getState(cpu_pct: f32, io_pct: f32) usize {
        _ = io_pct;
        const cpu_bucket = @min(@as(usize, @intFromFloat(cpu_pct * BUCKETS_F)), BUCKETS - 1);
        return cpu_bucket;
    }

    /// Actions the agent can take
    const Action = enum(u8) { Shorten, Keep, Lengthen };
    const NumActions = @typeInfo(Action).@"enum".fields.len;

    q_table: [TOTAL_STATES][NumActions]f32 = std.mem.zeroes([TOTAL_STATES][NumActions]f32),
    deltas: [TOTAL_STATES]usize = [_]usize{10} ** TOTAL_STATES,

    current_state: usize = 0,
    last_action: Action = .Keep,

    const MIN_DELTA: usize = 5;
    const MAX_DELTA: usize = 200;

    pub inline fn updateDelta(self: *QAgent) void {
        switch (self.last_action) {
            .Shorten => if (self.deltas[self.current_state] > MIN_DELTA) {
                self.deltas[self.current_state] -= 1;
            },
            .Keep => {},
            .Lengthen => if (self.deltas[self.current_state] < MAX_DELTA) {
                self.deltas[self.current_state] += 1;
            },
        }
    }

    const FAIRNESS_PENALTY: f32 = 3;
    const READY_WAIT_WEIGHT: f32 = 1;
    const IO_REWARD: f32 = 1;

    const B: f32 = 0.002;
    const K: f32 = 1;

    pub inline fn exponentialDeltaPunishment(self: *QAgent) f32 {
        const d: f32 = @floatFromInt(self.deltas[self.current_state]);

        return B * std.math.exp(K * @abs(d - 10));
    }

    const D: f32 = 0.01;
    const G: f32 = 0.5;

    pub inline fn quadraticDeltaPunishment(self: *QAgent) f32 {
        const d: f32 = @floatFromInt(self.deltas[self.current_state]);

        return D * std.math.pow(f32, G * @abs(d - 15), 3);
    }

    pub inline fn update(self: *QAgent, cpu: f32, ready_wait: f32, io_wait: f32, avg_sys_wait: f32, num_tasks: f32) usize {
        _ = num_tasks;

        const rng = rand.getRand();

        var reward = cpu - (READY_WAIT_WEIGHT * ready_wait) - (FAIRNESS_PENALTY * (avg_sys_wait));

        if (self.last_action != .Keep) {
            reward -= self.exponentialDeltaPunishment();
        }

        const next_state = getState(cpu, io_wait);
        var max_q_next = self.q_table[next_state][0];

        inline for (1..NumActions) |i| {
            if (self.q_table[next_state][i] > max_q_next) {
                max_q_next = self.q_table[next_state][i];
            }
        }

        const curr = self.q_table[self.current_state][@intFromEnum(self.last_action)];
        self.q_table[self.current_state][@intFromEnum(self.last_action)] = curr + ALPHA * (reward + (GAMMA * max_q_next) - curr);

        if (rng.float(f32) < EPSILON) {
            // Random exploration
            self.last_action = @enumFromInt(rng.intRangeAtMost(usize, 0, NumActions - 1));
        } else {
            var best_action: Action = .Keep;
            inline for (1..NumActions) |i| {
                if (self.q_table[next_state][i] > self.q_table[next_state][@intFromEnum(best_action)]) {
                    best_action = @enumFromInt(i);
                }
            }

            self.last_action = best_action;
        }

        self.current_state = next_state;
        self.updateDelta();

        return self.deltas[self.current_state];
        // baseline test:
        // return 10;
    }
};
