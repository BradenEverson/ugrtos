//! Scheduler control for all the tasks

const task = @import("task.zig");
const Task = task.Task;

extern fn SchedulerStart() void;

const c = @cImport({
    @cDefine("USE_HAL_DRIVER", {});
    @cDefine("STM32F446xx", {});
    @cInclude("main.h");
});

pub inline fn disable_irq() void {
    asm volatile ("cpsid i" ::: .{ .memory = true });
}

pub inline fn enable_irq() void {
    asm volatile ("cpsie i" ::: .{ .memory = true });
}

export var CurrentTask: *Task = undefined;

pub const Scheduler = struct {
    task_count: usize = 0,
    curr: usize = 0,
    tasks: [task.MAX_TASKS]Task = undefined,

    /// Choose who goes next and allocate the proper time slice for them
    pub inline fn schedule(self: *Scheduler) void {
        self.curr += 1;
        self.curr %= self.task_count;

        CurrentTask = &self.tasks[self.curr];
    }

    pub fn register(self: *Scheduler, t: *const fn () void, id: u8) void {
        const t_constructed = Task.init(t, id);
        self.tasks[self.task_count] = t_constructed;

        if (self.task_count == 0) {
            CurrentTask = &self.tasks[self.task_count];
        }

        self.task_count += 1;
    }

    pub fn start(self: *Scheduler) noreturn {
        _ = self;
        disable_irq();

        c.SCHEDULER_ENABLE_IT();

        // Call the start asm fn
        SchedulerStart();

        unreachable;
    }
};
