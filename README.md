# vmlauncher
Virtual Machine launcher that lets configuration be used to generate VM application, e.g. qemu, command-lines

Command-lines for launching virtual machines using system emulators like qemu can be very verbose and hard to remember for many VM cases. A shell script per-VM that contains a complete command-line is one approach to simplifying a multi-VM environment. vmlauncher is intended for a similar purpose but uses a configuration file per-VM to specify all the features of that VM and the vmlauncher script generates complete command-lines for system emulator applications like qemu. I started working on this in the earliest days of qemu/kvm and have maintained it to suit myself but it makes no sense to keep it to myself so created the project.

vmlauncher will also generate pre-amble command-lines for situations like host network bridge and tap interfaces, to create components of new virtual-machines like first-time creation of virtual disk images.

The initial version contains many assumptions about the host environent on which it is used since it is based on just enough to be usable on the author's linux workstation. However, it isn't difficult to modify as-needed. Even though it was created to launch x86/x86_64 qemu/kvm virtual machines on a linux host there is nothing to prevent it being modified to target or be hosted on other CPU architectures or other system emulator applications and hypervisors.

The most functional piece in the initial version is the vmlauncher.pl perl script that allows the creation of configuration files and qemu command-lines on linux assuming the user has a .vmlauncher directory to contain the configuration files. It also assumes the linux user has enough sudo configuration (or the root user is operating) to create, set up, set down, add and remove from bridges tap interfaces with a limited name format.

There is also a recently started python/python-qt UI aimed at providing the same functionality as vmlauncher.pl via a Qt UI.

USAGE

vmlauncher configuration files are expected to be found in a sub-directory named .vmlauncher in the user's home directory. Each file has a name that is a means of identifying the VM to the user, e.g. Linux4 and contain simple lines of ITEM=VALUE for each setting that the VM is to have. The majority of supported options have styles that match qemu command-line features but some cases simplify qemu command-line options without losing functionality. For example, a simple VM with a single CPU, 1GB of memory, an IDE HDD and an IDE CD-ROM might have a config file containing:

name=Simple PC

cpus=1

mem=1024

hda=/home/user/mySimplePCdisk.qcow2

cdrom=/home/user/myLinuxRescueCD.iso

Assuming the file is in the user's .vmlauncher directory and named SimplePC plus the vmlauncher.pl script is executable and in the user's path then the Simple PC can be started as a qemu VM using the command-line:

vmlauncher.pl vm=SimplepPC

instead of the qemu command-line:

qemu -smp 1 -m size=1024M -hda /home/user/mySimplePCdisk.qcow2 -cdrom /home/user/myLinuxRescueCD.iso -name="Simple PC"

The qemu runtime window will have in the title: "Simple PC". Once there are network interfaces and when there are more drives then it will require multiple setup and tear-down command-lines (for the network) and the qemu command-line will be hundreds of characters long, whereas vmlauncher will always be a command-line with two short parts (the program name and the vm=<value> argument to identify the configuration file to use).

GLOBAL SETTINGS

The location where vmlauncher configuration files are looked for can be set using the file .vmlauncher.cfg in the user's home directory. The option vmconfigsdir can specify the directory to be used:

vmconfigsdir=path-to-vm-configuration-files-directory

e.g.:

vmconfigsdir=~/.my-vms/

Where ~ indicates the user's home directory. The value doesn't have to end in a slash. When there is no .vmlauncher.cfg file or the vmconfigsdir is not set in it then the default location of a .vmlauncher directory in the user's home directory is used.

GUI VERSION

The GUI version of vmlauncher (qvmlauncher.py) is a Python based Qt application that can be run to perform the functions of vmlauncher.pl on a graphical desktop. It does not yet have all the features of vmlauncher.pl but that is the goal. It consists of two parts:

qvmlauncher.py - The application, run by exec/launching it by filename
pyqt/vmdlg.ui - A Qt Designer user interface model in XML for the view created by qvmlauncher.py

The pyqt/vwdlg.ui file must be converted to Qt classes in Python using the pyuic tool from the Python package:

pyuic pyqt/vmdlg.ui > ui_vm_dlg.py

The output name, ui_vm_dlg.py is the reference in the qvmlauncher.py source:

from ui_vm_dlg import Ui_vm_dlg

The ui_vm_dlg.py version should be stored in the "path", it can be modified with the the following statement in the qvmlauncher.py source:

sys.path.append('<path where ui_vm_dlg.py file was output to>')

At present this is not a global state but it will be added as a feature to .vmlauncher.cfg to avoid setting it in the source when needed.
