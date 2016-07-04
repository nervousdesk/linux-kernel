#head.s 简单2任务切换内核
LATCH=11930 #定时器初始计数，10ms一次中断
SCRN_SEL=0x18 #屏幕内存段选择符
TSS0_SEL=0x20 #任务0的TSS段选择符
LDT0_SEL=0X28 #任务0的LDT段选择符
TSS1_SEL=0x30 #任务1的TSS段选择符
LDT1_SEL=0X38 #任务1的LDT段选择符
.text
startup_32:
  movl $0x10,%eax
  mov %ax,ds
  lss init_stack,%esp #载入堆栈段
#设置新的IDT和GDT
  call setup_idt
  call setup_gdt
  movl $0x10,%eax
  mov %ax,%ds #重新加载段寄存器
  mov %ax,%es
  mov %ax,%fs
  mov %ax,%gs
  lss init_stack,%esp
#设定8253定时芯片
  movb  $0x36,%al  #通道0工作在方式3，计数2进制
  movl  0x43,%edx  #8253芯片控制字寄存器写端口
  outb  %al,%dx
  movl  $LATCH,%eax
  movl  $0x40,%edx #通道0寄存器端口
  outb  %al,%dx
  movb  %ah,%al
  outb  %al,%dx
#在IDT表8和128(0x80)项处设置定时中断门和系统调用陷阱门描述符
  movl  $0x00080000,%eax #构造中断门
  movw  $timer_interrupt,%ax
  movw  $0x8e00,%dx  #中断门类型
  movl  $0x08,%ecx
  lea idt(,%ecx,8),%esi #写入IDT
  movl  %eax,(%esi)
  movl  %edx,4(%esi)
  movw  $system_interrupt,%ax #构造陷阱门
  movw  $0xef00,%dx #陷阱门类型
  movl  $0x80,%ecx
  lea idt(,%ecx,8),%esi #写入IDT
  movl  %eax,(%esi)
  movl  %edx,4(%esi)
#构造任务0中断返回场景
  pushfl  #复位嵌套任务标志
  andl $0xffffbfff,(%esp)
  popfl
  movl  $TSS0_SEL,%eax  #TR寄存器设为任务0的TSS段选择符
  ltr %ax
  movl  $LDT0_SEL,%eax  #LDTR寄存器设为任务0的LDT段选择符
  lldt %ax
  movl  $0,current
  sti #任务0堆栈中断场景
  pushl $0x17 #ss
  pushl $init_stack #esp
  pushfl  #标志寄存器
  pushl $0x0f #cs
  pushl $task0  #eip
  iret
#3个中断处理程序：默认中断、定时中断、系统调用中断
.align 2
ignore_int:
  push  %ds
  pushl %eax
  movl  $0x10,%eax
  mov %ax,%ds
  movl  $67,%eax
  call  write_char
  popl  %eax
  pop %ds
  iret
.align 2
timer_interrupt:
  push  %ds
  pushl %eax
  movl  $0x10,%eax
  mov %ax,%ds
  movb  $0x20,%al #向8259A发送EOI命令
  outb  %al,$0x20
  movl  $1,%eax
  cmpl  %eax,current
  je  1f  #当前任务是1
  movl  %eax,current  #当前任务是0
  ljmp  $TSS_SEL,$0
  jmp 2f
1:  movl  $0,current
    ljmp  $TSS0_SEL,$0
2:  popl  %eax
    pop %ds
    iret
.align 2
system_interrupt:
  push  %ds
  pushl %edx
  pushl %ecx
  pushl %ebx
  pushl %eax
  movl  $0x10,%edx
  mov %dx,%ds
  call  write_char
  popl  %eax
  popl  %ebx
  popl  %ecx
  popl  %edx
  pop %ds
  iret
current:.long 0
scr_loc:.long 0
.align 2
lidt_opcode:
  .word 256*8-1
  .long idt
lgdt_opcode:
  .word (end_gdt-gdt)-1
  .long gdt
.align 3
idt:  .fill 256,8,0
gdt:  .quad 0x0000000000000000
      .quad 0x00c09a00000007ff
      .quad 0x00c09200000007ff      
      .quad 0x00c0920b80000002
      .word 0x68,tss0,0xe900,0x0
      .word 0x40,ldt0,0xe200,0x0
      .word 0x68,tss1,0xe900,0x0
      .word 0x40,ldt1,0xe200,0x0
end_gdt:
        .fill 128,4,0 #内核堆栈
init_stact:
        .long init_stack
        .word 0x10
.align 3
ldt0: .quad 0x0000000000000000
      .quad 0x00c0fa00000003ff
      .quad 0x00c0fa00000003ff
tss0: .long 0 #back link
      .long krn_stk0,0x10 #esp0,ss0
      .long 0,0,0,0,0 #esp1,ss1,esp2,ss2,cr3
      .long 0,0,0,0,0 #eip,eflags,eax,ecx,edx
      .long 0,0,0,0,0 #ebx,esp,ebp,esi,edi
      .long 0,0,0,0,0 #es,cs,ss,ds,fs,gs
      .long LDT0_SEL,0x8000000  #ldt,trace bitmap
    .fill 128,4,0 #任务0内核栈
krn_stk0:
#任务1的LDT和TSS
.align 3
ldt1: .quad 0x0000000000000000
      .quad 0x00c0fa00000003ff
      .quad 0x00c0f200000003ff
tss1: .long 0 #back link
      .long krn_stk1,0x10 #esp0,ss0
      .long 0,0,0,0,0 #esp1,ss1,esp2,ss2,cr3
      .long task1,0x200 #eip,efalgs
      .long 0,0,0,0 #eax,ecx,edx,ebx
      .long usr_stk1,0,0,0  #esp,ebp,esi,edi
      .long 0x17,0x0f,0x17,0x17,0x17,0x17 #es,cs,ss,ds,fs,gs
      .long LDT1_SEL,0x8000000  #ldt,trace bitmap
    .fill 128,4,0 #任务1内核栈
krn_stk1:
task0:
  movl  $0x17,%eax
  movw  %ax,%ds
  movl  $65,%al
  int $0x80 #显示字符‘A'
  movl  $0xfff,%ecx
1:loop  1b  #延时
  jmp task0
task1:
  movl  $66,%al
  int $0x80
  movl  $0xfff,%ecx
1:loop  1b
  jmp task1
  .fill 128,4,0
usr_stk1:
