//! Zig Entrypoint

const std = @import("std");
const scheduler = @import("scheduler/scheduler.zig");
const logger = @import("logger.zig");
const tasks = @import("tasks.zig");
const time = @import("time.zig");

const c = @cImport({
    @cDefine("USE_HAL_DRIVER", {});
    @cDefine("STM32F446xx", {});
    @cInclude("main.h");
});

var sched = scheduler.Scheduler{};

export fn ScheduleNext() void {
    sched.schedule();
}

export fn buttonIt() void {
    // TODO: Log out heuristics

    for (0..sched.task_count) |i| {
        sched.tasks[i].metadata.log();
    }
}

export fn entry() callconv(.c) void {
    logger.info("UGRtos: Bare Metal RTOS for testing Q-Learning Time Delta Allocation!\r\n");
    c.SET_TIME_DELTA(10);

    sched.register(tasks.foo, 'F');
    sched.register(tasks.bar, 'B');

    sched.start();
}
