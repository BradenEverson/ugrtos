//! Task definition

const std = @import("std");

const QAgent = @import("q_agent.zig").QAgent;
const logger = @import("../hal/logger.zig");

/// Number of tasks we support at a time
pub const MAX_TASKS: usize = 10;
var tasks: usize = 0;

pub const TaskState = enum(u8) {
    ready,
    io_waiting,
};

/// Number of words the stack can hold
pub const MAX_STACK_SIZE: usize = 512;

export var stacks: [MAX_TASKS][MAX_STACK_SIZE]u32 = undefined;

pub const TaskData = extern struct {
    timestamp: u32 = 0,
    total_run_time: u32 = 0,
    total_ready_wait_time: u32 = 0,
    total_io_wait_time: u32 = 0,
    delta: usize = 10,

    run_time: u32 = 0,
    io_wait_time: u32 = 0,
    ready_wait_time: u32 = 0,
    task_id: u8 = 0,

    last_time_switched: u32 = 0,

    pub fn log(self: *const TaskData) void {
        const ready_wait: f32 = @floatFromInt(self.total_ready_wait_time);
        const io_wait: f32 = @floatFromInt(self.total_io_wait_time);
        const runtime: f32 = @floatFromInt(self.total_run_time);

        const starve = (ready_wait) / (ready_wait + io_wait + runtime);

        logger.log("{c},{},{},{},{},{},{}\r\n", .{ self.task_id, self.timestamp, self.total_run_time, self.total_io_wait_time, self.total_ready_wait_time, starve, self.delta });
    }
};

pub const Task = extern struct {
    sp: *u32,
    id: u8,
    index: usize = 0,
    agent: QAgent = .{},
    state: TaskState = .ready,
    metadata: TaskData = .{},
    running: bool = false,

    pub fn init(task: *const fn () noreturn, id: u8) Task {
        const stack = &stacks[tasks];
        initStack(stack);

        stack[MAX_STACK_SIZE - 2] = @intFromPtr(task);

        tasks += 1;

        return Task{
            .id = id,
            .sp = &stack[MAX_STACK_SIZE - 16],
            .metadata = .{ .task_id = id },
        };
    }

    pub inline fn getDelta(self: *Task, avg_wait: f32, ready_queue_length: usize) usize {
        const tot = self.metadata.run_time + self.metadata.io_wait_time;

        const tot_f: f32 = @floatFromInt(tot);
        const cpu_f: f32 = @floatFromInt(self.metadata.run_time);
        const wait_ready_f: f32 = @floatFromInt(self.metadata.ready_wait_time);
        const wait_io_f: f32 = @floatFromInt(self.metadata.io_wait_time);

        const del = self.agent.update(
            cpu_f / tot_f,
            wait_ready_f / tot_f,
            wait_io_f / tot_f,
            avg_wait,
            @floatFromInt(ready_queue_length),
        );
        self.metadata.delta = del;

        return del;
    }
};

fn initStack(stack: *[MAX_STACK_SIZE]u32) void {
    stack[MAX_STACK_SIZE - 1] = 0x0100_0000; // Thumb bit

    stack[MAX_STACK_SIZE - 2] = 0xDEAD_BEEF; // PC
    stack[MAX_STACK_SIZE - 3] = 0xFEEF_DEEF; // Link Register

    stack[MAX_STACK_SIZE - 4] = 0xAB12_BA12; // R12

    stack[MAX_STACK_SIZE - 5] = 0x3030_3030; // R3
    stack[MAX_STACK_SIZE - 6] = 0x2222_2222; // R2
    stack[MAX_STACK_SIZE - 7] = 0x1111_0101; // R1
    stack[MAX_STACK_SIZE - 8] = 0x0000_0000; // R0
    stack[MAX_STACK_SIZE - 9] = 0x0011_1100; // R11
    stack[MAX_STACK_SIZE - 10] = 0x1010_AAAA; // R10
    stack[MAX_STACK_SIZE - 11] = 0x9090_0985; // R9
    stack[MAX_STACK_SIZE - 12] = 0x8888_8800; // R8

    stack[MAX_STACK_SIZE - 13] = 0x7667_7070; // R7
    stack[MAX_STACK_SIZE - 14] = 0x6060_6060; // R6
    stack[MAX_STACK_SIZE - 15] = 0x5050_5050; // R5
    stack[MAX_STACK_SIZE - 16] = 0x4444_0440; // R4
}
