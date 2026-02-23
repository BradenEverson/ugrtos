//! Logging functionality

const c = @cImport({
    @cDefine("USE_HAL_DRIVER", {});
    @cDefine("STM32F446xx", {});
    @cInclude("main.h");
});

extern var huart2: c.UART_HandleTypeDef;

pub inline fn info(msg: []const u8) void {
    _ = c.HAL_UART_Transmit(&huart2, @ptrCast(msg), msg.len, 1000);
}
