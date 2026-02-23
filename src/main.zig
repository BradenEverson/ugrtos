//! Zig Entrypoint

const std = @import("std");
const scheduler = @import("scheduler/scheduler.zig");

const c = @cImport({
    @cDefine("USE_HAL_DRIVER", {});
    @cDefine("STM32F446xx", {});
    @cInclude("main.h");
});

var quantum: u32 = 10;

export fn timerIT() callconv(.c) void {
    c.HAL_GPIO_TogglePin(c.LD2_GPIO_Port, c.LD2_Pin);
}

fn foo() void {
    while (true) {}
}

export fn entry() callconv(.c) void {
    var sched = scheduler.Scheduler{};

    sched.register(foo, 'F');

    sched.start();
}
