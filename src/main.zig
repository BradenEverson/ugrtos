//! Zig Entrypoint

const std = @import("std");

const c = @cImport({
    @cDefine("USE_HAL_DRIVER", {});
    @cDefine("STM32F446xx", {});
    @cInclude("main.h");
});

var quantum: u32 = 10;

export fn timerIT() callconv(.c) void {
    c.HAL_GPIO_TogglePin(c.LD2_GPIO_Port, c.LD2_Pin);
    quantum *= 2;
    c.SET_TIME_QUANTUM(quantum);
}

export fn entry() callconv(.c) void {
    while (true) {}
}
