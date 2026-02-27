//! Discrete Q-Table Bins for CPU utilization percents
const std = @import("std");
const rand = @import("../hal/rand.zig");

/// Learning Rate
const ALPHA: f32 = 0.1;

/// Discount Factor, importance of future rewards
const GAMMA: f32 = 0.9;

/// Exploration rate, probability we try a random action
const EPSILON: f32 = 0.1;

pub const QAgent = extern struct {
    /// Number of times we split up the CPU utilization percents
    /// into discrete buckets
    /// Ex: 10 buckets gives us 0-10%, 11-20%, ...
    const BUCKETS: usize = 10;
    const BUCKETS_F: f32 = @floatFromInt(BUCKETS);

    pub fn getStateFromPct(cpu_pct: f32) usize {
        const bucket: f32 = cpu_pct * BUCKETS_F;

        const bin: usize = @intFromFloat(bucket);
        if (bin >= BUCKETS) return BUCKETS - 1;
        return bin;
    }

    /// Actions the agent can take
    const Action = enum(u8) { Shorten, Keep, Lengthen };
    const NumActions = @typeInfo(Action).@"enum".fields.len;

    q_table: [BUCKETS][NumActions]f32 = std.mem.zeroes([BUCKETS][NumActions]f32),
    deltas: [BUCKETS]usize = [_]usize{10} ** BUCKETS,

    current_state: usize = 0,
    last_action: Action = .Keep,

    const MIN_DELTA: usize = 1;
    const MAX_DELTA: usize = 50;

    pub fn updateDelta(self: *QAgent) void {
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

    const FAIRNESS_PENALTY: f32 = 10;
    const READY_WAIT_WEIGHT: f32 = 1;

    pub inline fn update(self: *QAgent, cpu: f32, ready_wait: f32, io_wait: f32, avg_sys_wait: f32, num_tasks: f32) usize {
        const rng = rand.getRand();

        const avg_wait_excluding_me = ((avg_sys_wait * num_tasks) - ready_wait) / (num_tasks - 1);

        const reward = cpu - (READY_WAIT_WEIGHT * ready_wait) + io_wait - (FAIRNESS_PENALTY * avg_wait_excluding_me);

        const next_state = getStateFromPct(cpu);
        var max_q_next = self.q_table[next_state][0];

        inline for (1..NumActions) |i| {
            if (self.q_table[next_state][i] > max_q_next) {
                max_q_next = self.q_table[next_state][i];
            }
        }

        self.q_table[self.current_state][@intFromEnum(self.last_action)] = ALPHA * (reward + (GAMMA * max_q_next));

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
    }
};
