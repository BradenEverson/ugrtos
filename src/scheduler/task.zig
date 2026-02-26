//! Task definition

const std = @import("std");

const QAgent = @import("q_agent.zig").QAgent;
const logger = @import("../logger.zig");

/// Number of tasks we support at a time
pub const MAX_TASKS: usize = 10;
var tasks: usize = 0;

/// Number of words the stack can hold
pub const MAX_STACK_SIZE: usize = 100;

export var stacks: [MAX_TASKS][MAX_STACK_SIZE]u32 = undefined;

var log_buf: [1024]u8 = undefined;

pub const TaskData = extern struct {
    run_time: u32 = 0,
    io_wait_time: u32 = 0,
    ready_wait_time: u32 = 0,
    task_id: u8 = 0,

    pub fn log(self: *const TaskData) void {
        const entry = std.fmt.bufPrint(&log_buf, "{c},{},{},{}\r\n", .{ self.task_id, self.run_time, self.io_wait_time, self.ready_wait_time }) catch unreachable;
        logger.info(entry);
    }
};

pub const Task = extern struct {
    sp: *u32,
    id: u8,
    agent: QAgent = .{},
    metadata: TaskData = .{},

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
