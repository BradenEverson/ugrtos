//! Zig Entrypoint

const std = @import("std");
const scheduler = @import("scheduler/scheduler.zig");

const c = @cImport({
    @cDefine("USE_HAL_DRIVER", {});
    @cDefine("STM32F446xx", {});
    @cInclude("main.h");
});

extern var huart2: c.UART_HandleTypeDef;

var sched = scheduler.Scheduler{};

export fn ScheduleNext() void {
    sched.schedule();
}

fn foo() void {
    while (true) {
        c.HAL_GPIO_WritePin(c.LD2_GPIO_Port, c.LD2_Pin, c.GPIO_PIN_SET);
    }
}

fn bar() void {
    while (true) {
        c.HAL_GPIO_WritePin(c.LD2_GPIO_Port, c.LD2_Pin, c.GPIO_PIN_RESET);
    }
}

export fn entry() callconv(.c) void {
    log("UGRtos: Bare Metal RTOS for testing Q-Learning Time Delta Allocation!\r\n");
    c.SET_TIME_DELTA(100);

    sched.register(foo, 'F');
    sched.register(bar, 'B');

    sched.start();
}

pub inline fn log(msg: []const u8) void {
    _ = c.HAL_UART_Transmit(&huart2, @ptrCast(msg), msg.len, 1000);
}
