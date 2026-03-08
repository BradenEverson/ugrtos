//! Generic tasks to register with known optima

const c = @cImport({
    @cDefine("USE_HAL_DRIVER", {});
    @cDefine("STM32F446xx", {});
    @cInclude("main.h");
});

const Scheduler = @import("scheduler/scheduler.zig").Scheduler;

const sched = @import("main.zig");

/// IO Bound Blinky
pub fn ioBlinky() noreturn {
    while (true) {
        c.HAL_GPIO_TogglePin(c.LD2_GPIO_Port, c.LD2_Pin);
        c.HAL_Delay(30);
        sched.ioCall(.{ .SleepMs = 100 });
    }
}

/// CPU Bound Blinky
pub fn cpuBlinky() noreturn {
    while (true) {
        c.HAL_GPIO_TogglePin(c.GPIOB, c.GPIO_PIN_5);
        c.HAL_Delay(100);
    }
}
