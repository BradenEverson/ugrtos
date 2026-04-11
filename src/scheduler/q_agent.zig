//! Discrete Q-Table Bins for CPU utilization percents
const std = @import("std");
const rand = @import("../hal/rand.zig");
const logger = @import("../hal/logger.zig");

/// Learning Rate
const ALPHA: f32 = 0.01;

/// Discount Factor, importance of future rewards
const GAMMA: f32 = 0.8;

/// Exploration rate, probability we try a random action
const EPSILON: f32 = 0.35;

/// Epsilon Decay Rate, every update it is multiplied by this
const DECAY: f32 = 0.999;

/// Number of times we split up the CPU utilization percents
/// into discrete buckets
/// Ex: 10 buckets gives us 0-10%, 11-20%, ...
const BUCKETS: usize = 5;
const BUCKETS_F: f32 = @floatFromInt(BUCKETS);

const TOTAL_STATES = BUCKETS * 2 * 2;

pub const QAgent = extern struct {
    pub inline fn getState(cpu_pct: f32, io_pct: f32, ready_queue_size: usize) usize {
        const cpu_idx = @min(@as(usize, @intFromFloat(cpu_pct * BUCKETS_F)), BUCKETS - 1);
        const io_idx: usize = if (io_pct > 0.2) 1 else 0;
        const pressure_idx: usize = if (ready_queue_size > 0) 1 else 0;
        return cpu_idx + (io_idx * BUCKETS) + (pressure_idx * BUCKETS * 2);
    }

    /// Actions the agent can take
    const Action = enum(u8) { ShortenSmall, ShortenMedium, ShortenLarge, Keep, LengthenSmall, LengthenMedium, LengthenLarge };
    const NumActions = @typeInfo(Action).@"enum".fields.len;

    q_table: [TOTAL_STATES][NumActions]f32 = std.mem.zeroes([TOTAL_STATES][NumActions]f32),
    deltas: [TOTAL_STATES]usize = [_]usize{10} ** TOTAL_STATES,

    current_state: usize = 0,
    last_action: Action = .Keep,
    epsilon: f32 = EPSILON,

    const MIN_DELTA: usize = 10;
    const MAX_DELTA: usize = 200;

    const STEP_SIZES = [_]usize{ 1, 2, 5 };

    pub inline fn updateDelta(self: *QAgent, action: Action) void {
        const current = self.deltas[self.current_state];

        const step_idx = @intFromEnum(action);
        if (step_idx < 3) {
            const step = STEP_SIZES[step_idx];
            self.deltas[self.current_state] = @max(MIN_DELTA, current -| step);
        } else if (step_idx > 3) {
            const step = STEP_SIZES[step_idx - 4];
            self.deltas[self.current_state] = @min(MAX_DELTA, current + step);
        }
    }

    const IO_REWARD: f32 = 1.0;

    pub inline fn update(
        self: *QAgent,
        cpu: f32,
        ready_wait: f32,
        io_wait: f32,
        switches: f32,
        wait_len: usize,
    ) usize {
        const rng = rand.getRand();

        const switch_penalty = switches * 0.05;
        // const utilization_efficiency: f32 = if (cpu > 0.75) 1.5 else 0.0;
        const utilization_efficiency: f32 = cpu;
        const wait_penalty = std.math.pow(f32, ready_wait, 2.0) * 5.0;
        const io_bonus = io_wait * 2.0;
        const global_congestion_penalty = @as(f32, @floatFromInt(wait_len)) * 0.5;

        const reward = utilization_efficiency + io_bonus - wait_penalty - switch_penalty - global_congestion_penalty;

        const next_state = getState(cpu, io_wait, wait_len);
        var max_q_next = self.q_table[next_state][0];
        inline for (1..NumActions) |i| {
            if (self.q_table[next_state][i] > max_q_next) max_q_next = self.q_table[next_state][i];
        }

        const curr_q = self.q_table[self.current_state][@intFromEnum(self.last_action)];
        self.q_table[self.current_state][@intFromEnum(self.last_action)] = curr_q + ALPHA * (reward + (GAMMA * max_q_next) - curr_q);

        var next_action: Action = .Keep;
        if (rng.float(f32) < EPSILON) {
            next_action = @enumFromInt(rng.intRangeAtMost(usize, 0, NumActions - 1));
        } else {
            inline for (1..NumActions) |i| {
                if (self.q_table[next_state][i] > self.q_table[next_state][@intFromEnum(next_action)]) {
                    next_action = @enumFromInt(i);
                }
            }
        }

        self.current_state = next_state;
        self.last_action = next_action;
        self.updateDelta(next_action);

        self.epsilon *= DECAY;
        return self.deltas[self.current_state];
        // baseline
        // return 10;
    }
};
