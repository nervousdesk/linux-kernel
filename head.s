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
  pushfl
