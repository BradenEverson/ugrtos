//! Zig Entrypoint

const std = @import("std");

const logger = @import("hal/logger.zig");
const time = @import("hal/time.zig");

const heuristics = @import("scheduler/heuristics.zig");
const io = @import("scheduler/io_manager.zig");

const tasks = @import("tasks.zig");
const scheduler = @import("scheduler/scheduler.zig");

const c = @cImport({
    @cDefine("USE_HAL_DRIVER", {});
    @cDefine("STM32F446xx", {});
    @cInclude("main.h");
});

var sched = scheduler.Scheduler{};

pub inline fn ioCall(call: io.IoCall) void {
    sched.ioCall(call);
}

pub inline fn getSwitchCount() usize {
    return sched.switches;
}

export fn ScheduleNext() void {
    sched.schedule();
}

export fn sleepIt() void {
    sched.io_manager.sleepRetIt();
}

export fn gpioIt(port: usize, pin: usize) void {
    _ = port;
    const gpio = io.Gpio{ .port = .B, .pin = pin };
    sched.io_manager.gpioRetIt(gpio);
}

export fn buttonIt() void {
    scheduler.disable_irq();
    heuristics.sendAllData();
    @panic("We should not recover from this");
}

export fn entry() callconv(.c) void {
    c.SET_TIME_DELTA(10);

    sched.register(tasks.ioBlinky, 'B');
    sched.register(tasks.cpuBlinky, 'C');

    sched.start();
}
