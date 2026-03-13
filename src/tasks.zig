//! Generic tasks to register with known optima

const std = @import("std");

const c = @cImport({
    @cDefine("USE_HAL_DRIVER", {});
    @cDefine("STM32F446xx", {});
    @cInclude("main.h");
});
const logger = @import("hal/logger.zig");

const Scheduler = @import("scheduler/scheduler.zig").Scheduler;

const sched = @import("main.zig");

pub fn blockingWaitApprox(n: usize) void {
    for (0..n * 5000) |i| {
        _ = i;
    }
}

/// IO Bound Blinky
pub fn ioBlinky() noreturn {
    while (true) {
        c.HAL_GPIO_TogglePin(c.LD2_GPIO_Port, c.LD2_Pin);
        blockingWaitApprox(50);
        sched.ioCall(.{ .SleepMs = 50 });
    }
}

/// IO Bound Blinky
pub fn ioBlinky2() noreturn {
    while (true) {
        blockingWaitApprox(30);
        sched.ioCall(.{ .SleepMs = 100 });
    }
}

/// IO Bound Blinky
pub fn ioBlinky3() noreturn {
    while (true) {
        blockingWaitApprox(100);
        sched.ioCall(.{ .SleepMs = 10 });
    }
}

/// CPU Bound Blinky
pub fn cpuBlinky() noreturn {
    while (true) {
        c.HAL_GPIO_TogglePin(c.GPIOB, c.GPIO_PIN_5);
        blockingWaitApprox(100);
    }
}
