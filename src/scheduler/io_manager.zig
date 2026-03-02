//! IO Management Struct

const std = @import("std");

const time = @import("../hal/time.zig");
const task = @import("task.zig");
const Task = task.Task;

const logger = @import("../hal/logger.zig");

const TaskQueue = @import("fixed_buffer.zig").FixedBufferArrayList(*Task, task.MAX_TASKS);

pub const GpioPort = enum(usize) {
    A,
    B,
    C,
};

pub const Gpio = extern struct {
    port: GpioPort,
    pin: usize,

    pub inline fn toIndex(self: Gpio) usize {
        const base = @intFromEnum(self.port);
        return base * 16 + self.pin;
    }
};

pub const IoCall = union(enum) {
    GpioWait: Gpio,
    UartTransmit: []const u8,
    UartReceive: []u8,
};

const GpioPinCount: usize = @typeInfo(GpioPort).@"enum".fields.len * 16;
var gpio_queues: [GpioPinCount]TaskQueue = [_]TaskQueue{.{}} ** GpioPinCount;

var buf: [256]u8 = undefined;

pub const IoManager = extern struct {
    ready_queue_ref: *TaskQueue = undefined,

    pub inline fn ioCall(self: *IoManager, t: *Task, io: IoCall) void {
        _ = self;
        switch (io) {
            .GpioWait => |gpio| {
                t.metadata.time_put_on_wait = time.getTimeMicros();
                t.state = .io_waiting;

                gpio_queues[gpio.toIndex()].pushFront(t) catch unreachable;
            },
            else => {},
        }
    }

    pub inline fn gpioRetIt(self: *IoManager, gpio: Gpio) void {
        const now = time.getTimeMicros();

        const idx = gpio.toIndex();

        const queue = &gpio_queues[idx];

        while (queue.pop()) |t| {
            t.metadata.io_wait_time = now - t.metadata.time_put_on_wait;
            t.metadata.time_put_on_wait = now;
            t.state = .ready;

            self.ready_queue_ref.pushFront(t) catch unreachable;
        }
    }
};
