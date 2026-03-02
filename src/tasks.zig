//! Generic tasks to register

const c = @cImport({
    @cDefine("USE_HAL_DRIVER", {});
    @cDefine("STM32F446xx", {});
    @cInclude("main.h");
});

const Scheduler = @import("scheduler/scheduler.zig").Scheduler;

const sched = @import("main.zig");

pub fn foo() noreturn {
    sched.ioCall(.{ .GpioWait = .{ .port = .B, .pin = 6 } });
    while (true) {
        c.HAL_GPIO_TogglePin(c.LD2_GPIO_Port, c.LD2_Pin);
        c.HAL_Delay(100);
    }
}

pub fn bar() noreturn {
    while (true) {
        c.HAL_GPIO_TogglePin(c.GPIOB, c.GPIO_PIN_5);
        c.HAL_Delay(100);
    }
}
