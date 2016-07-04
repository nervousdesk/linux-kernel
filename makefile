boot:boot.o
	ld86 -0 -s -o boot boot.o
boot.o:boot.s
	as86 -0 -a -o boot.o boot.s
head:head.o
	gld -o head head.o
head.o:head.s
	gas -o head.o head.s
disk:boot head
	dd bs=32 if=boot of=Image skip=1
	dd bs=512 if=head of=Image skip=2 seek=1
	dd if=Image of=/dev/fd1
clean:
	rm boot boot.o head head.o Image
