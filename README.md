# vmlauncher
Virtual Machine launcher that lets configuration be used to generate VM application, e.g. qemu, command-lines

Command-lines for launching virtual machines using system emulators like qemu can be very verbose and hard to remember for many VM cases. A shell script per-VM that contains a complete command-line is one approach to simplifying a multi-VM environment. vmlauncher is intended for a similar purpose but uses a configuration file per-VM to specify all the features of that VM and the vmlauncher script generates complete command-lines for system emulator applications like qemu. I started working on this in the earliest days of qemu/kvm and have maintained it to suit myself but it makes no sense to keep it to myself so created the project.

vmlauncher will also generate pre-amble command-lines for situations like host network bridge and tap interfaces, to create components of new virtual-machines like first-time creation of virtual disk images.

The initial version contains many assumptions about the host environent on which it is used since it is based on just enough to be usable on the author's linux workstation. However, it isn't difficult to modify as-needed. Even though it was created to launch x86/x86_64 qemu/kvm virtual machines on a linux host there is nothing to prevent it being modified to target or be hosted on other CPU architectures or other system emulator applications and hypervisors.

The most functional piece in the initial version is the vmlauncher.pl perl script that allows the creation of configuration files and qemu command-lines on linux assuming the user has a .qemu directory to contain the configuration files. It also assumes the linux user has enough sudo configuration (or is the root user) to create, set up, set down, add and remove from bridges tap interfaces with a limited name format.

There is also a recently started python/python-qt UI aimed at providing the same functionality as vmlauncher.pl via a Qt UI.
