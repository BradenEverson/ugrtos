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
    var buf: [64]u8 = undefined;
    while (true) {
        sched.ioCall(.{
            .UartReceive = .{
                .buf = &buf,
                .uart = .uart4,
            },
        });
    }
}
