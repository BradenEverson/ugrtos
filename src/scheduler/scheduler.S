.syntax unified
.cpu cortex-m4
.fpu softvfp
.thumb

.global SchedulerStart
.global TIM2_IRQHandler
.global PendSV_Handler

.extern CurrentTask
.extern ScheduleNext
.extern ClearTimerITFlag

.section .text.SchedulerStart
.type SchedulerStart, %function
SchedulerStart:
    cpsid i
    ldr r0, =0xE000ED22
    ldr r1, =0xFF
    strb r1, [r0]

    ldr r0, =CurrentTask
    ldr r1, [r0]
    ldr r2, [r1]
    
    msr psp, r2
    mov r0, #2
    msr control, r0
    isb

    pop {r4-r11}
    pop {r0}
    pop {r0, r1, r2, r3, r12}
    pop {lr}
    pop {r0}
    
    cpsie i
    bx lr

.section .text.TIM2_IRQHandler
.type TIM2_IRQHandler, %function
TIM2_IRQHandler:
    push {lr}
    bl ClearTimerITFlag
    
    // Trigger PendSV by setting PENDSVSET bit in ICSR
    ldr r0, =0xE000ED04
    ldr r1, =(1 << 28)
    str r1, [r0]
    
    pop {lr}
    bx lr

.section .text.PendSV_Handler
.type PendSV_Handler, %function
PendSV_Handler:
    cpsid i
    
    mrs r0, psp
    stmdb r0!, {r4-r11}
    ldr r1, =CurrentTask
    ldr r2, [r1]
    str r0, [r2]

    push {lr}
    bl ScheduleNext
    pop {lr}

    ldr r1, =CurrentTask
    ldr r2, [r1]
    ldr r0, [r2]
    ldmia r0!, {r4-r11}
    msr psp, r0
    
    cpsie i
    bx lr

