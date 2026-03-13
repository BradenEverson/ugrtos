//! Discrete Q-Table Bins for CPU utilization percents

const std = @import("std");
const rand = @import("../hal/rand.zig");
const logger = @import("../hal/logger.zig");

/// Learning Rate
const ALPHA: f32 = 0.01;

/// Discount Factor, importance of future rewards
const GAMMA: f32 = 0.7;

/// Exploration rate, probability we try a random action
const EPSILON: f32 = 0.15;

/// Staggered Updates
const TIME_UNTIL_UPDATE: usize = 1;

/// Gates for what's beyond reasonable deltas
const MIN_DELTA: usize = 5;
const MAX_DELTA: usize = 200;

const FAIRNESS_PENALTY: f32 = 15;
const READY_WAIT_WEIGHT: f32 = 5;
const IO_REWARD: f32 = 5;

const B: f32 = 0.002;
const K: f32 = 1;

/// Number of times we split up the CPU utilization percents
/// into discrete buckets
/// Ex: 10 buckets gives us 0-10%, 11-20%, ...
const BUCKETS: usize = 10;
const BUCKETS_F: f32 = @floatFromInt(BUCKETS);

pub const QAgent = extern struct {
    pub inline fn getStateFromPct(cpu_pct: f32) usize {
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

    rolling_cpu: f32 = 0,
    rolling_io: f32 = 0,
    rolling_ready_wait: f32 = 0,
    rolling_avg_wait: f32 = 0,
    rolling_num_tasks: f32 = 0,
    updates: usize = 0,

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

    pub inline fn exponentialDeltaPunishment(self: *QAgent) f32 {
        const d: f32 = @floatFromInt(self.deltas[self.current_state]);

        return B * std.math.exp(K * @abs(d - 10));
    }

    pub fn update(self: *QAgent, cpu_here: f32, ready_wait_here: f32, io_wait_here: f32, avg_sys_wait_here: f32, num_tasks_here: f32) usize {
        self.updates += 1;

        self.rolling_cpu += cpu_here;
        self.rolling_ready_wait += ready_wait_here;
        self.rolling_io += io_wait_here;
        self.rolling_avg_wait += avg_sys_wait_here;
        self.rolling_num_tasks += num_tasks_here;

        if (self.updates % TIME_UNTIL_UPDATE != 0) {
            return self.deltas[self.current_state];
        }

        const rng = rand.getRand();

        const n: f32 = @floatFromInt(TIME_UNTIL_UPDATE);

        const cpu = self.rolling_cpu / n;
        const ready_wait = self.rolling_ready_wait / n;
        const io_wait = self.rolling_io / n;
        const avg_sys_wait = self.rolling_avg_wait / n;
        const num_tasks = self.rolling_num_tasks / n;

        self.rolling_cpu = 0;
        self.rolling_ready_wait = 0;
        self.rolling_io = 0;
        self.rolling_avg_wait = 0;
        self.rolling_num_tasks = 0;

        const best_cpu_avg_wait = 1 / num_tasks;
        var reward = cpu - (READY_WAIT_WEIGHT * ready_wait) + (IO_REWARD * io_wait) - (FAIRNESS_PENALTY * (avg_sys_wait - best_cpu_avg_wait));

        if (self.last_action != .Keep) {
            reward -= self.exponentialDeltaPunishment();
        }

        const next_state = getStateFromPct(cpu);
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
