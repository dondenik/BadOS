echo "compiling..."
nasm /Users/Dominik/boot_sect.asm -f bin -o /Users/Dominik/boot_sect.bin
nasm /Users/Dominik/kernel.asm -f bin -o /Users/Dominik/kernel.bin
cat /Users/Dominik/boot_sect.bin /Users/Dominik/kernel.bin > /Users/Dominik/os-image
#::nasm C:\Users\Dominik\os-image.asm -f bin -o C:\Users\Dominik\os-image.bin
echo "running..."
qemu-system-i386 -drive format=raw,file=/Users/Dominik/os-image