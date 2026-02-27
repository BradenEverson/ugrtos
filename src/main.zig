//! Zig Entrypoint

const std = @import("std");

const logger = @import("hal/logger.zig");
const time = @import("hal/time.zig");

const heuristics = @import("scheduler/heuristics.zig");

const tasks = @import("tasks.zig");
const scheduler = @import("scheduler/scheduler.zig");

const c = @cImport({
    @cDefine("USE_HAL_DRIVER", {});
    @cDefine("STM32F446xx", {});
    @cInclude("main.h");
});

var sched = scheduler.Scheduler{};

export fn ScheduleNext() void {
    sched.preempt_schedule();
}

export fn buttonIt() void {
    scheduler.disable_irq();
    heuristics.sendAllData();
    scheduler.enable_irq();
}

export fn entry() callconv(.c) void {
    logger.info("UGRtos: Bare Metal RTOS for testing Q-Learning Time Delta Allocation!\r\n");
    c.SET_TIME_DELTA(10);

    sched.register(tasks.foo, 'F');
    sched.register(tasks.bar, 'B');

    sched.start();
}
