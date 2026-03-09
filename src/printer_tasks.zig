//! Generic tasks to register with known optima

const std = @import("std");

const c = @cImport({
    @cDefine("USE_HAL_DRIVER", {});
    @cDefine("STM32F446xx", {});
    @cInclude("main.h");
});

const Scheduler = @import("scheduler/scheduler.zig").Scheduler;

const sched = @import("main.zig");

/// G-Code Parser
pub fn gcodeParser() noreturn {
    while (true) {
        c.HAL_GPIO_TogglePin(c.LD2_GPIO_Port, c.LD2_Pin);
        sched.ioCall(.{ .SleepMs = 100 });
    }
}
