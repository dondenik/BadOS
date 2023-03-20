# BadOS
A bad 16 bit x86 operating system that barely functions.
The current build file is designed for MacOS but is easily ported.
To run the OS simply run the zsh file.
This requires QEMU and NASM to be installed and accesible from PATH.
It is recommended to install these with Homebrew.

## Implemented Commands
 - nfile - creates new file
 - txt - basic text editor
 - calc basic calculator
 - random - basic pseudo-random number generator
 - hscroll - clears the command line output
 - snake - opens the game snake (Not fully working)
 
 ### nfile
 Creates a new file.
 Files are stored in RAM (due to my inability to get QEMU to properly emulate a disk) and are thus volatile meaning that they will be erased after power off. \
 Usage:
 > `nfile <name>`
 
 Also note that as files are stored in RAM and 16 bit address schemes can only address up to around 1mB of RAM file sizes are limited.
 
 ### txt
 Opens files in a basic text editor. The files must already exist.
 Supports arrow keys.
 To save and exit press Ctrl-E. \
 Usage:
 > `txt <file>`
 
 ### calc
 Basic command line calculator using reverse polish notation.
 Has the following implemented operators:
 - minus (-)
 - plus (+)
 - times (*)
 - divide (/)
 - power (^)
 - modulo (%)
 There is also the special operator random (RAND) which replaces itself with a random number. \

 Usage:
 > `calc <operand> <operand> <operator>`
 
 Note that this uses unsigned 16 bit integers and will not output negative numbers instead overflowing.
 
 ### random
 Basic random number generator that outputs to command line.
 Uses 16 bit XOR-Shift. \
 Usage:
 > `random`
 
 ### hscroll
 Clears command line output.
 
 ### snake
 Work in progress.
 
 ## Technical Overview and Notes
The OS runs in x86 real mode making use of BIOS functions to control output and input. As QEMU wouldn't let me use an actual disk despite my best efforts the filesystem is instead mounted in RAM making it volatile although the facilities are there to have it use a disk but are not enabled.
The command line itself will echo back anything you type into it that isn't a valid command.
The code is not properly formatted and the variable names are dubious at best with many different misspellings of 'loop' used as labels for random loops/
