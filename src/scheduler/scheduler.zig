//! Scheduler control for all the tasks

const task = @import("task.zig");
const Task = task.Task;

pub inline fn disable_irq() void {
    asm volatile ("cpsid i" ::: .{ .memory = true });
}

pub inline fn enable_irq() void {
    asm volatile ("cpsie i" ::: .{ .memory = true });
}

var CurrentTask: *Task = undefined;

pub const Scheduler = struct {
    task_count: usize = 0,
    tasks: [task.MAX_TASKS]?Task = [_]?Task{null} ** task.MAX_TASKS,

    pub fn register(self: *Scheduler, t: *const fn () void, id: u8) void {
        const t_constructed = Task.init(t, id);
        self.tasks[self.task_count] = t_constructed;

        if (self.task_count == 0) {
            CurrentTask = &self.tasks[self.task_count].?;
        }

        self.task_count += 1;
    }

    pub fn start(self: *Scheduler) noreturn {
        _ = self;
        disable_irq();

        while (true) {}

        unreachable;
    }
};
