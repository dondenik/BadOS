echo "compiling..."
nasm ./boot_sect.asm -f bin -o /Users/Dominik/boot_sect.bin
nasm ./kernel.asm -f bin -o /Users/Dominik/kernel.bin
cat ./boot_sect.bin ./kernel.bin > ./os-image
#::nasm C:\Users\-\os-image.asm -f bin -o C:\Users\-\os-image.bin
echo "running..."
qemu-system-i386 -drive format=raw,file=./os-image
