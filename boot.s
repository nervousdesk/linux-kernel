!利用bios中断把内核代码(head代码)加载到内存0x10000处，然后移动到内存0处(此前0处有BIOS中断向量表)
!最后进入保护模式，并跳转到内存0（head代码）继续运行
BOOTSEG=0x07c0        !本程序(引导扇区)被BIOS加载到内存0x7c00处
SYSSEG=0x1000
SYSLEN==17            !内核占用最大磁盘扇区数
entry start
start:
  jmpi go,#BOOTSEG
go:
  mov ax,cs
  mov ds,ax
  mov ss,ax
  mov sp,#0x400
!加载内核代码到内存0x10000处
load_system:
  mov dx,0x0000 !DH-磁头号 DL-驱动器号
  mov cx,#0x0002  !CH-磁道号低8位 CL-位7/6是磁道号高2位，位5-0是起始扇区号（从1计）
  mov ax,#SYSSEG
  mov es,ax
  xor bx,bx !BIOS 0x13中断移动数据目的地址es:bx
  mov ax,#0x200+SYSLEN  !AH=0x02功能号(0x13中断) AL=要读取的扇区数量
  int 0x13
  jnc ok_load !中断没发生错误则跳转
die:  jmp die
!移动内核代码到内存0处(不能用BIOS中断了，因为破坏了内存0处的中断向量表)
ok_load:
  cli
  mov ax,#SYSSEG  !从ds:si到es:di，cx计数(rep mov指令)
  mov ds,ax
  xor ax,ax
  mov es,ax
  sub si,si
  sub di,di
  mov cx,#0x1000  !移动4k次，每次一个word
  rep movw
!加载IDT和GDT基地址寄存器IDTR和GDTR
  mov ax,#BOOTSEG
  mov ds,ax
  lidt idt_48
  lgdt gdt_48 !6字节操作数：2字节表长度，4字节线性基址
!设置机器状态字(控制寄存器CR0)，进入保护模式，跳转到GDT第二个段选择符所指定的段
  mov ax,#0x0001  !PE标志位即保护模式
  lmsw ax
  jmpi 0,8
!所需要的数据
gdt:  .word 0,0,0,0

      .word 0x07ff  !段限长=2047(2048*4096=8MB) 段粒度是4k(段属性字段中有)
      .word 0x0000  !段基址
      .word 0x9A00  !段属性（代码段，可读/执行）
      .word 0x00C0  !段粒度属性4KB
      
      .word 0x07ff
      .word 0x0000
      .word 0x9200  !数据段，可读写
      .word 0x00c0
!LIDT和GDT指令的操作数
idt_48: .word 0     !表长度
        .word 0,0   !表基址
gdt_48: .word 0x7ff
        .word 0x7c00+gdt,0
.org 510
        .word 0xAA55  !引导扇区有效标志
