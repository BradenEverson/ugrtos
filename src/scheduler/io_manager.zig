//! IO Management Struct

const std = @import("std");

const c = @cImport({
    @cDefine("USE_HAL_DRIVER", {});
    @cDefine("STM32F446xx", {});
    @cInclude("main.h");
});

extern var huart2: c.UART_HandleTypeDef;
extern var huart4: c.UART_HandleTypeDef;
extern var huart5: c.UART_HandleTypeDef;

const time = @import("../hal/time.zig");
const task = @import("task.zig");
const Task = task.Task;

const SleepEntry = struct {
    task: *Task,
    wake_time: u64,
};
const logger = @import("../hal/logger.zig");

const TaskQueue = @import("fixed_buffer.zig").FixedBufferArrayList(*Task, task.MAX_TASKS);
const SleepQueue = @import("fixed_buffer.zig").FixedBufferArrayList(SleepEntry, task.MAX_TASKS);

var sleep_queue: SleepQueue = .{};

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

pub const Uart = enum(u8) {
    uart2,
    uart4,
    uart5,

    pub fn fromU8(u: u8) ?Uart {
        return switch (u) {
            2 => .uart2,
            4 => .uart4,
            5 => .uart5,
            else => null,
        };
    }

    pub fn getHuart(self: Uart) *c.UART_HandleTypeDef {
        return switch (self) {
            .uart2 => &huart2,
            .uart4 => &huart4,
            .uart5 => &huart5,
        };
    }
};

pub const IoCall = union(enum) {
    GpioWait: Gpio,
    SleepMs: usize,
    UartTransmit: struct { msg: []const u8, uart: Uart },
    UartReceive: struct { buf: []u8, uart: Uart },
};

const GpioPinCount: usize = @typeInfo(GpioPort).@"enum".fields.len * 16;
var gpio_queues: [GpioPinCount]TaskQueue = [_]TaskQueue{.{}} ** GpioPinCount;

var Sleeper: ?*Task = null;

const UartIoQueues = struct {
    read: ?*Task = null,
    write: ?*Task = null,
};

const UartCount: usize = @typeInfo(Uart).@"enum".fields.len;
var uart_queues: [UartCount]UartIoQueues = [_]UartIoQueues{.{}} ** UartCount;

pub const IoManager = extern struct {
    ready_queue_ref: *TaskQueue = undefined,

    pub inline fn ioCall(self: *IoManager, t: *Task, io: IoCall) void {
        _ = self;
        switch (io) {
            .GpioWait => |gpio| {
                t.metadata.last_time_switched = time.getTimeMicros();
                t.state = .io_waiting;
                gpio_queues[gpio.toIndex()].pushFront(t) catch unreachable;
            },

            .UartTransmit => |uart_req| {
                const idx: usize = @intFromEnum(uart_req.uart);
                if (uart_queues[idx].write != null) unreachable;

                t.metadata.last_time_switched = time.getTimeMicros();
                t.state = .io_waiting;
                uart_queues[idx].write = t;

                _ = c.HAL_UART_Transmit_IT(uart_req.uart.getHuart(), uart_req.msg.ptr, @truncate(uart_req.msg.len));
            },

            .UartReceive => |uart_req| {
                const idx: usize = @intFromEnum(uart_req.uart);
                if (uart_queues[idx].read != null) unreachable;

                t.metadata.last_time_switched = time.getTimeMicros();
                t.state = .io_waiting;
                uart_queues[idx].read = t;

                const huart = uart_req.uart.getHuart();

                _ = c.HAL_UART_Receive_IT(huart, uart_req.buf.ptr, @truncate(uart_req.buf.len));
            },

            .SleepMs => |sleep| {
                const now = time.getTimeMicros();
                const wake_time = now + sleep * 1000;

                var idx: usize = 0;
                while (idx < sleep_queue.len) : (idx += 1) {
                    if (wake_time < sleep_queue.vals[idx].wake_time) break;
                }

                const entry = SleepEntry{ .task = t, .wake_time = wake_time };
                sleep_queue.insert(idx, entry) catch unreachable;

                t.metadata.last_time_switched = now;
                t.state = .io_waiting;

                if (idx == 0) {
                    const delta_us = wake_time - now;
                    const delta_ms = (delta_us + 999) / 1000;
                    c.SetTimerMs(@intCast(@max(delta_ms, 1)));
                }
            },
        }
    }

    pub inline fn sleepRetIt(self: *IoManager) void {
        const now = time.getTimeMicros();

        while (sleep_queue.len > 0 and sleep_queue.vals[0].wake_time <= now) {
            const entry = sleep_queue.orderedRemove(0);
            const t = entry.task;

            t.metadata.io_wait_time = now - t.metadata.last_time_switched;
            t.metadata.last_time_switched = now;
            t.state = .ready;

            self.ready_queue_ref.pushFront(t) catch unreachable;
        }

        if (sleep_queue.len > 0) {
            const now2 = time.getTimeMicros();
            const next_wake = sleep_queue.vals[0].wake_time;
            if (next_wake > now2) {
                const delta_us = next_wake - now2;
                const delta_ms = (delta_us + 999) / 1000;
                c.SetTimerMs(@intCast(@max(delta_ms, 1)));
            } else {
                c.SetTimerMs(1);
            }
        }
    }

    pub inline fn uartTransmitRetIt(self: *IoManager, uart: Uart) void {
        const idx: usize = @intFromEnum(uart);
        if (uart_queues[idx].write) |t| {
            const now = time.getTimeMicros();

            t.metadata.io_wait_time = now - t.metadata.last_time_switched;
            t.metadata.last_time_switched = now;
            t.state = .ready;

            self.ready_queue_ref.pushFront(t) catch unreachable;
        }

        uart_queues[idx].write = null;
    }

    pub inline fn uartReceiveRetIt(self: *IoManager, uart: Uart) void {
        const idx: usize = @intFromEnum(uart);
        if (uart_queues[idx].read) |t| {
            const now = time.getTimeMicros();

            t.metadata.io_wait_time = now - t.metadata.last_time_switched;
            t.metadata.last_time_switched = now;
            t.state = .ready;

            self.ready_queue_ref.pushFront(t) catch unreachable;
        }

        uart_queues[idx].read = null;
    }

    pub inline fn gpioRetIt(self: *IoManager, gpio: Gpio) void {
        const now = time.getTimeMicros();

        const idx = gpio.toIndex();

        const queue = &gpio_queues[idx];

        while (queue.pop()) |t| {
            t.metadata.io_wait_time = now - t.metadata.last_time_switched;
            t.metadata.last_time_switched = now;
            t.state = .ready;

            self.ready_queue_ref.pushFront(t) catch unreachable;
        }
    }
};
