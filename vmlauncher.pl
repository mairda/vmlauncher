#!/usr/bin/perl
#
# Following version numbers precede the use of git but illustrate modifications
# v0.4.6 - David Mair - Added qemu 2.10.1 enhancements, netdev/device for networks
#                       Use ip rather than ifconfig
# v0.4.5 - David Mair - Added vdrive disk as a means of accessing virtio disks devices
# v0.4.4 - David Mair - Added qemu 0.15 enhancements, equal vlans and which finding of executables used
#                       load and save StartDateFile and generateVMCommandLine
# v0.4.3 - David Mair - Added forced enable-kvm
#

use strict;
# use feature 'current_sub';
use warnings;

use DateTime;
use File::stat;

# Command line parsing
use Getopt::Long qw(:config pass_through);
use Getopt::Long qw(GetOptionsFromString);

my $us;

my $ver = "0.4.6";

my @sudobinlist = ("brctl", "ifconfig", "ip", "sudo", "tunctl");
my %sudobins;

my $qemubin = "qemu-system-x86_64";
my $qemuhack = "/data/unzip/qemu/qemu-kvm-0.14.0/x86_64-softmmu/qemu-system-x86_64";
my $qemuimgbin = "qemu-img";

my $brctlbin = "/usr/sbin/brctl";
my $tunctlbin = "/sbin/tunctl";
my $ifconfigbin = "/sbin/ifconfig";
my $ipbin = "/sbin/ip";
my $sudobin = "/usr/bin/sudo";

my $vibin = "vi";

my $ripcdrom = "/data/iso/riplinux-current.iso";

my $createVM = 0;
my $editVM = 0;
my $listVMs = 0;
my $configFound;
my $debug = 1;
my $pretendExec = 0;

my $vmcfg;
my $vmcfgdir;
my $vmcfgfile;
my $altgrab = 0;
my $boot;
my $bootOnce;
my $bootMenu = 0;
my $cdrom;
my @chardevs;
my $cpu = "";
my $cpus = 1;
my $curses;
my $daemonize;
my $dump;
my $fda;
my $fdb;
my $hda;
my $hdb;
my $hdc;
my $hdd;
my $sda;
my $sdb;
my $sdc;
my $sdd;
my $sdi;
my $genuuid = 0;
my $hack = 0;
my $name = "My Virtual Machine";
my $noacpi;
my $noballoon;
my $nohpet;
my $nokvm;
my $loadvm;
my $localtime = 0;
my $logBIOS = 0;
my $mem = 128;
my $mon;
my $nostart;
my $pidfile;
my $rip = 0;
my $sdl = 1;
my $snapshot;
my $usb = 1;
my $usbkbd = 1;
my $usbmouse = 1;
my $uuid = "";
my $vgatype = "";
my $vmname = "";
my $vmsource = "";
my $win2khack;

my $ret;
my $remainder;

my %scsidrives;

my $i;
my $acval;
my $user = $ENV{USER};
my $verbose = 1;
my $verbosnap;
my $test = 0;
my $subname;
my $insub = 0;
my $vmdir = "";
my $cmdline = "";
my $machine;
my $net;
my $options = "";
my $serial;
my $soundhw;
my $vnc;
my $sermon;
my $qmpserverport = 0;
my $startdate;
my $startdatefile;
my $starttime;
my $dt;
my $sdt;
my $sdfile;
my $vmelapsed;
my $sy = "0";
my $sm = "0";
my $sd = "0";
my $shr = "0";
my $smn = "0";
my $ssc = "0";
my %drives;
my %nics;
my %macs;
my %vlans;
my %netdevs;
my %bridges;
my @taps;
my @usbdevices;
my @devnameIDs;
my @ouis = ("AC:DE:48", "00:00:6C", "00:01:01", "00:05:4F", "00:05:78",
		"00:09:C2", "00:0B:18", "00:0B:F4", "00:0C:53", "00:0D:58",
		"00:0D:A7", "00:0D:C2", "00:0D:F2", "00:0E:17", "00:0E:22",
		"00:0E:2A", "00:0E:EF", "00:0F:09", "00:16:B4", "00:17:35",
		"00:1E:3F", "00:20:67", "00:22:1C", "00:22:F1", "00:23:4A",
		"00:23:8C", "00:23:F7", "00:24:19", "00:24:3E", "00:24:FB",
		"00:25:34", "00:25:3F", "00:50:47", "00:50:79", "00:A0:54",
		"00:A0:85", "10:00:00"
);
my $mcastoui = "11:00:AA";


sub findBinaries
{
	my $cmdz;
	my $binpath;

	foreach (@sudobinlist)
	{
        if ($_ ne "ifconfig")
        {
            print __LINE__, ": ", (caller(0))[3], " Finding path for $_\n" if ($verbose);
            
            # Special handling for ip, which has a /bin/ and a /sbin/ instance
            if ($_ eq "ip")
            {
                $cmdz = "sudo which /sbin/ip 2>/dev/null";
            }
            else
            {
                $cmdz = "sudo which $_ 2>/dev/null";
            }
            
            $binpath = qx/$cmdz/;
            print " - qx completes with $binpath\n" if ($verbose);
            
            if ($binpath =~ m/(.*)/)
            {
                $binpath = $1;
                print " - modified to $binpath\n" if ($verbose);
            }
            if ($binpath ne "")
            {
                $sudobins{$_} = $binpath;
                print " - saved in sudobins hash as $sudobins{$_} with key $_\n" if ($verbose);
            }
            else
            {
                if ($_ =~ m/"brctl"/)
                {
                    $binpath = $brctlbin;
                }
                elsif ($_ =~ m/"ifconfig"/)
                {
                    $binpath = $ifconfigbin;
                }
                elsif ($_ =~ m/"ip"/)
                {
                    $binpath = $ipbin;
                }
                elsif ($_ =~ m/"sudo"/)
                {
                    $binpath = $sudobin;
                }
                elsif ($_ =~ m/"tunctl"/)
                {
                    $binpath = $tunctlbin;
                }
                else
                {
                    die("Failed to find $_ executable required for operation\n");
                }

                $sudobins{$_} = $binpath;
                print " - saved constant $binpath in sudobins hash as $sudobins{$_} with key $_\n" if ($verbose);
            }
        }
	}
}


sub parseConfigItem
{
	my $chdev;
	my $vs;
	my $ln;
	my ($line) = @_;
	chomp($line);

	if ((!$line) || ($line eq ""))
	{
		return;
	}

	if ($line =~ m/^\[(.*)\]/)
	{
		print "Sub-section found $1\n" if ($verbose);

		# If we are looking for a sub-section
		if (!$subname)
		{
			print "No sub-section required\n" if ($verbose);

			$insub = 1;
			return;
		}

		if ($subname eq $1)
		{
			print "Found requested sub-section\n" if ($verbose);

			$insub = 2;
			return;
		}
		else
		{
			print "Found sub-section other than that requested\n" if ($verbose);

			if ($insub == 2)
			{
				$insub = 3;
			}
			else
			{
				$insub = 1;
			}
			return;
		}
	}

	if (($insub == 1) || ($insub == 3))
	{
		print "Ignoring setting $line in not requested sub-section\n" if ($verbose);

		return;
	}

	if ($line =~ /^#(.*)/)						# pyqt
	{
		print "Comment: $1\n" if ($verbose);
		return;
	}

	if ($line =~ /^--/)
	{
		$ln = $line;
	}
	else
	{
		$ln = "--".$line;
	}
	$line = $ln;

	print __LINE__, ": ", (caller(0))[3], " Parsing $line\n" if ($debug);

	if ($line =~ /--genuuid/i)
	{
		$genuuid = 1;
	}

	if ($line =~ /--hack/i)
	{
		$hack = 1;
	}

	# --sdrive<bus>.<lun>=<file>[,option,option...]
	if ($line =~ /--sdrive(\d)\.(\d)=(.*)/i)
	{
		print "scsi drive on LUN $2 of bus $1 = $3\n" if ($verbose);
		$drives{"s/$1/$2"} = $3;
		return;
	}

	# --vdrive<device>...
	if ($line =~ /--vdrive\d+.*/i)
	{
        # Bus node specification: --vdrive<bus>.<unit>=<file>
        if ($line =~ /--vdrive(\d)\.(\d)=(.*)/i)
        {
            print "virtio drive on unit $2 of bus $1 = $3\n" if ($verbose);
            $drives{"v/$1/$2"} = $3;
            return;
        }
        # Bus index specification: --vdrive<index>=<file>
        if ($line =~ /--vdrive(\d+)=(.*)/i)
        {
            print "virtio drive at index $1 = $2\n" if ($verbose);
            $drives{"v/$1"} = $2;
            return;
        }
    }

	if ($line =~ /^--nic(\d)=(.*)/i)				# pyqt
	{
		print __LINE__, ": ", (caller(0))[3], " vlan $1 nic = $2\n" if ($verbose);
		$nics{"vlan=$1"} = $2;
		print __LINE__, ": ", (caller(0))[3], " netdev $1 nic = $2\n" if ($verbose);
		$nics{"netdev=$1"} = $2;
		return;
	}
	if ($line =~ /^--mac(\d)=(.*)/i)				# pyqt
	{
		print __LINE__, ": ", (caller(0))[3], " vlan $1 mac = $2\n" if ($verbose);
		$macs{"vlan=$1"} = $2;
		print __LINE__, ": ", (caller(0))[3], " netdev $1 = $2\n" if ($verbose);
		$macs{"netdev=$1"} = $2;
		return;
	}
	if ($line =~ /^--vlan(\d)=(.*)/i)				# pyqt
	{
		print __LINE__, ": ", (caller(0))[3], " vlan $1 = $2\n";# if ($verbose);
		$vlans{"vlan=$1"} = $2;
		return;
	}

    # Get a netdev case and separate number
    #
    # Example create syntax elements for two NICs is:
    # --nic0=virtio --netdev0=tap,ifname=gentap,bridge=br8,script=no,downscript=no
    #  --nic1=virtio --netdev1=tap,ifname=gentap,bridge=br0,script=no,downscript=no
    #
	if ($line =~ /^--netdev(\d)=(.*)/i)				# pyqt
	{
		my $nmvNIC = "vlan=$1";
		
		print "netdev $1 = $2\n" if ($verbose);
		$netdevs{"netdev=$1"} = $2;
		
		# Remove it's vlan nic
		delete $nics{$nmvNIC};
		
		# ... and it's vlan MAC
		delete $macs{$nmvNIC};
		
		return;
	}

	if ($line =~ /^--usbdevice=(.*)/i)
	{
		print "USB device = $1\n" if ($verbose);
		$i = 0 + @usbdevices;
		$usbdevices[$i] = $1;
		return;
	}

	
	if ($line =~ /^--nousb$/i)					# pyqt
	{
		print "Disable guest USB controller\n" if ($verbose);
		$usb = 0;
		return;
	}

	if ($line =~ /^--nousbkbd$/i)
	{
		print "Don\'t use USB keyboard (use i8042 keyboard instead)\n" if ($verbose);
		$usbkbd = 0;
		return;
	}

	if ($line =~ /^--nousbmouse$/i)
	{
		print "Don\'t use USB mouse (use i8042 mouse instead)\n" if ($verbose);
		$usbmouse = 0;
		return;
	}
	
	if ($line =~ /^--alt-grab$/i)
	{
        print "Use alternate grab keystroke (Ctrl-Alt-Shift)\n" if ($verbose);
        $altgrab = 1;
        return;
	}

	if ($line =~/^--scsi(\d)=(.*)/i)
	{
		print "SCSI Drive $1 = $2\n" if ($verbose);
		$scsidrives{"$1"} = $2;
		return;
	}

#print "TRYING TO FIND OPTIONS in $line !!!!!!!!!!!!!!!!!!!\n";

	if ($line =~ /^--options=(.*)/i)
	{
		print "Additional options = $1\n" if ($verbose);
		$options = $1;
		return;
	}

	if ($line =~ /^--name=(.*)/i)					# pyqt
	{
		print "VM Name = $1\n" if ($verbose);
		$name = $1;
		return;
	}

	$chdev = "";
	($ret, $remainder) = GetOptionsFromString($ln, 
					'cpu=s' => \$cpu,		# pyqt
					'cpus=i' => \$cpus,		# pyqt
					'smp=i' => \$cpus,		# pyqt
					'boot=s' => \$boot,
					'bootonce=s' => \$bootOnce,
					'bootmenu' => \$bootMenu,
					'cdrom=s' => \$cdrom,		# pyqt
					'chardev=s' => \$chdev,
					'create' => \$createVM,
					'curses' => \$curses,		# pyqt
					'daemonize' => \$daemonize,
					'dump' => \$dump,
					'edit' => \$editVM,
					'fda=s' => \$fda,		# pyqt
					'fdb=s' => \$fdb,		# pyqt
					'hda=s' => \$hda,		# pyqt
					'hdb=s' => \$hdb,		# pyqt
					'hdc=s' => \$hdc,		# pyqt
					'hdd=s' => \$hdd,		# pyqt
					'sda=s' => \$sda,		# pyqt
					'sdb=s' => \$sdb,		# pyqt
					'sdc=s' => \$sdc,		# pyqt
					'sdd=s' => \$sdd,		# pyqt
					'sdi=s' => \$sdi,		# pyqt
					'loadvm=s' => \$loadvm,
					'localtime' => \$localtime,	# pyqt
					'logbios' => \$logBIOS,
					'machine=s' => \$machine,	# pyqt
					'mem=i' => \$mem,		# pyqt
					'mon=s' => \$mon,
					'net=s' => \$net,
					'noacpi' => \$noacpi,		# pyqt
					'noballoon' => \$noballoon,
					'nohpet' => \$nohpet,		# pyqt
					'nokvm' => \$nokvm,
					'nostart' => \$nostart,
					'pidfile=s' => \$pidfile,
					'qmpserver=i' => \$qmpserverport,
					'rip' => \$rip,
					'sdl' => \$sdl,
					'serial=s' => \$serial,
					'sermon=s' => \$sermon,
					'snapshot' => \$snapshot,
					'soundhw=s' => \$soundhw,	# pyqt
					'startdate=s' => \$startdate,
					'startdatefile=s' => \$startdatefile,
					'usb' => \$usb,			# pyqt
					'uuid=s' => \$uuid,		# pyqt
					'verbose' => \$verbose,
					'vga=s' => \$vgatype,		# pyqt
					'vmdir=s' => \$vmdir,
					'vnc=s' => \$vnc,
					'vs' => \$vs,
					'win2khack' => \$win2khack);

	if ($ret)
	{
		die "You need at least one CPU\n" if ($cpus < 1);
		die "Memory size too small" if ($mem < 4);
		die "The QMP server setting must be a tcp port number\n" if (($ln eq 'qmpserver') && (($qmpserverport < 1) || ($qmpserverport > 65535)));
		
		if ($ln =~ /qmpserver/i)
		{
			print "QMP Server set, line is $ln, port is $qmpserverport\n";
		}

		if ($vs) {
			print "Going verbose and snapshot\n" if ($debug);
			$verbose = 1;
			$snapshot = 1;
		}

		if ($chdev ne "") {
			push @chardevs,($chdev);
		}

		return;
	}

#		$hda = $vmdir.$1;
#		$hdb = $vmdir.$1;
#		$hdc = $vmdir.$1;
#		$hdd = $vmdir.$1;
#		$cdrom = $vmdir.$1;

	die "Unrecognized configuration item $line\n";
}


sub getConfigDir
{
	my $cfgdir;

	# Extract the generic base directory for VM configs from the environment
	$cfgdir = $ENV{HOME}."/.vmlauncher/";
	print __LINE__, ": ", (caller(0))[3], " finds $cfgdir\n" if ($debug);

	return $cfgdir;
}


sub getConfigFileName
{
	my $cfgFileName = "";

	# If a VM name is set, add it to the config directory name
	if (length($vmname) > 0)
	{
		$cfgFileName = getConfigDir();
		$cfgFileName .= $vmname;
	}

	return $cfgFileName;
}


sub CPUIsValid
{
	# Check if the value in the global CPU variable is supported
	if ( ($cpu eq "Opteron_G3") 
		|| ($cpu eq "Opteron_G2")
		|| ($cpu eq "Opteron_G1")
		|| ($cpu eq "Nehalem")
		|| ($cpu eq "Penryn")
		|| ($cpu eq "Conroe")
		|| ($cpu eq "n270")
		|| ($cpu eq "athlon")
		|| ($cpu eq "pentium3")
		|| ($cpu eq "pentium2")
		|| ($cpu eq "pentium")
		|| ($cpu eq "486")
		|| ($cpu eq "coreduo")
		|| ($cpu eq "kvm32")
		|| ($cpu eq "qemu32")
		|| ($cpu eq "kvm64")
		|| ($cpu eq "qemu64")
		|| ($cpu eq "core2duo")
		|| ($cpu eq "phenom")
		|| ($cpu eq "host") )
	{
		return 1;
	}

	return 0;
}


sub createNewVM
{
	my $i;
	my $diskSize;

	print "Creating a new Virtual Machine\n" if ($verbose);

	# Set the config directory and config filename
	$vmcfgdir = getConfigDir();	#$ENV{HOME}."/.vmlauncher/";
	$vmcfgfile = getConfigFileName();	#$vmcfgdir.$vmname;

	# Try to open the constructed path
	open($vmcfg, ">", $vmcfgfile) or die "Failed to create config file\n";

	if ($verbose)
	{
		print $vmcfg "verbose\n";
	}

	if (! ($name eq ""))
	{
		print $vmcfg "name=$name\n";
	}
	if (! ($vmdir eq ""))
	{
		print $vmcfg "vmdir=$vmdir\n";
	}
	if ($machine)
	{
		print $vmcfg "machine=$machine\n";
	}
	if (CPUIsValid())
	{
		print $vmcfg "cpu=$cpu\n";
	}
	elsif ($cpu ne "")
	{
		die "Unrecognized CPU model $cpu\n";
	}
	print $vmcfg "cpus=$cpus\n";
	print $vmcfg "mem=$mem\n";
	if ($genuuid)
	{
		
		$uuid = sprintf("%08x-%04x-%04x-%04x-%04x%08x", 
				rand(2147483647),
				rand(65535),
				rand(65535),
				rand(65535),
				rand(65535),
				rand(2147483647));
		print $vmcfg "uuid=$uuid\n"
	}
	if ($localtime)
	{
		print $vmcfg "localtime\n";
	}
	if ($vgatype eq "std")
	{
		print $vmcfg "vga=std\n";
	}
	elsif ($vgatype eq "vmware")
	{
		print $vmcfg "vga=vmware\n";
	}
	elsif ($vgatype eq "qxl")
	{
		print $vmcfg "vga=qxl\n";
	}
	elsif ($vgatype eq "none")
	{
		print $vmcfg "vga=none\n";
	}
	else
	{
		# The default
		print $vmcfg "vga=cirrus\n";
	}
	if (defined($vnc))
	{
        # Parameter format is [<ip>]:<display>[,<other argument>[,<other argument[,etc]]]
        # e.g. :0 for listen on all local addresses port 5900
        #      :5 for listen on all local addresses port 5905
        #      10.0.0.205:5 for listen on port 5905 on 10.0.0.205 address only
        #      append ",lossy" for jpeg encoding of data (might save bandwidth)
		print $vmcfg "vnc=$vnc\n";
	}
	if ($usb)
	{
		print $vmcfg "usb\n";

		foreach (@usbdevices)
		{
			print "usbdevice=$_\n";
		}
	}
	if (!$usbkbd)
	{
		print $vmcfg "nousbkbd\n";
	}
	if (!$usbmouse)
	{
		print $vmcfg "nousbmouse\n";
	}
	if ($altgrab)
	{
        print $vmcfg "alt-grab\n";
	}
	if ($fda)
	{
		print $vmcfg "fda=$fda\n";
	}
	if ($fdb)
	{
		print $vmcfg "fdb=$fdb\n";
	}
	if ($hack)
	{
		print $vmcfg "hack\n";
	}
	if ($hda)
	{
		if ($hda =~ /(.+),(\d+.)$/i)
		{
			$diskSize = $2;
			$hda = $1;
            if ($pretendExec)
			{
                print("\nsystem: $qemuimgbin create -f qcow2 $hda $2\n");
			}
			else
			{
                system("$qemuimgbin create -f qcow2 $hda $2");
            }
		}
		print $vmcfg "hda=$hda\n";
	}
	if ($hdb)
	{
		if ($hdb =~ /(.+),(\d+.)$/i)
		{
			$diskSize = $2;
			$hdb = $1;
            if ($pretendExec)
			{
                print("\nsystem: $qemuimgbin create -f qcow2 $hdb $2\n");
			}
			else
			{
                system("$qemuimgbin create -f qcow2 $hdb $2");
            }
		}
		print $vmcfg "hdb=$hdb\n";
	}
	if ($hdc)
	{
		if ($hdc =~ /(.+),(\d+.)$/i)
		{
			$diskSize = $2;
			$hdc = $1;
            if ($pretendExec)
			{
                print("\nsystem: $qemuimgbin create -f qcow2 $hdc $2\n");
			}
			else
			{
                system("$qemuimgbin create -f qcow2 $hdc $2");
			}
		}
		print $vmcfg "hdc=$hdc\n";
	}
	if ($hdd)
	{
		if ($hdd =~ /(.+),(\d+.)$/i)
		{
			$diskSize = $2;
			$hdd = $1;
            if ($pretendExec)
			{
                print("\nsystem: $qemuimgbin create -f qcow2 $hdd $2\n");
			}
			else
			{
                system("$qemuimgbin create -f qcow2 $hdd $2");
            }
		}
		print $vmcfg "hdd=$hdd\n";
	}
	if ($sda)
	{
		if ($sda =~ /(.+),(\d+.)$/i)
		{
			$diskSize = $2;
			$sda = $1;
            if ($pretendExec)
			{
                print("\nsystem: $qemuimgbin create -f qcow2 $sda $2\n");
			}
			else
			{
                system("$qemuimgbin create -f qcow2 $sda $2");
            }
		}
		print $vmcfg "sda=$sda\n";
	}
	if ($sdb)
	{
		if ($sdb =~ /(.+),(\d+.)$/i)
		{
			$diskSize = $2;
			$sdb = $1;
            if ($pretendExec)
			{
                print("\nsystem: $qemuimgbin create -f qcow2 $sdb $2\n");
			}
			else
			{
                system("$qemuimgbin create -f qcow2 $sdb $2");
            }
		}
		print $vmcfg "sdb=$sdb\n";
	}
	if ($sdc)
	{
		if ($sdc =~ /(.+),(\d+.)$/i)
		{
			$diskSize = $2;
			$sdc = $1;
            if ($pretendExec)
			{
                print("\nsystem: $qemuimgbin create -f qcow2 $sdc $2\n");
			}
			else
			{
                system("$qemuimgbin create -f qcow2 $sdc $2");
            }
		}
		print $vmcfg "sdc=$sdc\n";
	}
	if ($sdd)
	{
		if ($sdd =~ /(.+),(\d+.)$/i)
		{
			$diskSize = $2;
			$sdd = $1;
            if ($pretendExec)
			{
                print("\nsystem: $qemuimgbin create -f qcow2 $sdd $2\n");
			}
			else
			{
                system("$qemuimgbin create -f qcow2 $sdd $2");
            }
		}
		print $vmcfg "sdd=$sdd\n";
	}
	if ($sdi)
	{
		if ($sdi =~ /(.+),(\d+.)$/i)
		{
			$diskSize = $2;
			$sdi = $1;
            if ($pretendExec)
			{
                print("\nsystem: $qemuimgbin create -f qcow2 $sdi $2\n");
			}
			else
			{
                system("$qemuimgbin create -f qcow2 $sdi $2");
            }
		}
		print $vmcfg "sdi=$sdi\n";
	}
	if ($cdrom)
	{
		print $vmcfg "cdrom=$cdrom\n";
	}

    printf "Process the drives: createNewVM\n" if ($verbose);
	foreach (sort keys(%drives))
	{
		my $if;
		my $bus;
		my $tid;
		my $index;
		my $driveFull;
		my $driveLessSize;
		my $driveFileOnly;

# 		print " DRIVE KEY: $_ WITH VALUE $drives{$_}\n";

		# Extract the interface, bus, unit number and get the full drive value
		if ($_ =~ /(.)\/(\d)\/(\d)/)
		{
			$if = $1;
			$bus = $2;
			$tid = $3;
            undef($index);
			$driveFull = $drives{$_};
# 			print " DRIVE KEY DESCRIBES I/F $if, BUS $bus AND UNIT $tid\n";
		}
		# Extract the interface, index number and get the full drive value
		elsif ($_ =~ /(.)\/(\d+)/)
		{
			$if = $1;
            $index = $2;
			undef($bus);
			undef($tid);
			$driveFull = $drives{$_};
# 			print " DRIVE KEY DESCRIBES I/F $if, AND INDEX $index\n";
		}
		else
		{
            undef($if);
		}

		# If the drive value ends in command then numbers
		if ($driveFull =~ /(.+),(\d+.)$/)
		{
			# Get the size and the filename parts
			$diskSize = $2;
			$driveLessSize = $1;
		}
		else
		{
			# The whole value is the filename part
			$driveLessSize = $drives{$_};
		}

		# Get everything up to any comma as the filename
		if ($driveLessSize =~ /^(.+),.+/)
		{
			$driveFileOnly = $1;
		}
		else
		{
			$driveFileOnly = $driveLessSize;
		}

		# Save the filename only as the value for the drive key we are working on
		$drives{$_} = $driveLessSize;

		# If we got a filename and size
		if ($driveFileOnly && $diskSize)
		{
			# Create the drive file
            if ($pretendExec)
			{
                print("\nsystem: $qemuimgbin create -f qcow2 $driveFileOnly $diskSize\n");
			}
			else
			{
                system("$qemuimgbin create -f qcow2 $driveFileOnly $diskSize");
            }
		}

		# If there is an interface and a drive value
		if (defined($if) && $drives{$_})
		{
            # For the bus, unit case
            if (defined($bus) && defined($tid))
            {
                # Place the entry in the config file for it
                print $vmcfg "$if"."drive$bus.$tid=$drives{$_}\n"
            }
            # For the index case
            elsif (defined($index))
            {
                # Place the entry in the config file for it
                print $vmcfg "$if"."drive$index=$drives{$_}\n"
            }
            else
            {
                print "Drive specified without interface: $drives{$_}\n";
            }
        }
	}

	if ($curses)
	{
		print $vmcfg "curses\n";
	}

	if ($daemonize)
	{
		print $vmcfg "daemonize\n";
	}

	if ($boot)
	{
		print $vmcfg "boot=$boot\n";
	}

	if ($bootOnce)
	{
		print $vmcfg "bootonce=$bootOnce\n";
	}

	if ($bootMenu)
	{
		print $vmcfg "bootmenu\n";
	}

    printf "Process the vlans: createNewVM\n";
	foreach (sort keys(%vlans))
	{
		my $n = 0;
		my $macaddr;
		my $ifname;

		if ($debug != 0)
		{
			printf "Generating vlan $_ configuration\n";
		}

		# Get the vlan number (default is zero)
		if ($_ =~ /vlan=(\d)/i)
		{
			$n = $1;
		}

		# If no NIC type was specified we should look in the vlan setting
		if (!$nics{$_})
		{
			# Syntax only allows for bridge name and nic type
			if ($vlans{$_} =~ /tapbridge=(.+)[\,].*$/i)
			{
				$vlans{$_} = "tap,bridge=$1,ifname=gentap,script=no,downscript=no";
			}
			if ($vlans{$_} =~ /nic=(.+)/i)
			{
				$nics{$_} = $1;
			}
#			if (!$nics{$_})
#			{
#				die "Invalid auto-generate tap/bridge syntax\n";
#				$nics{$_} = " ";
#			}
		}
    }

    # Process the netdevs
    #
    # Example create syntax for two NICs is:
    # --nic0=virtio --netdev0=tap,ifname=gentap,bridge=br8,script=no
    #  --nic1=virtio --netdev1=tap,ifname=gentap,bridge=br0,script=no
    #
    # example config outcome for same two NICs is:
    # nic0=virtio
    # mac0=00:25:3F:9d:1b:0e
    # netdev0=tap,ifname=gentap,bridge=br8,script=no
    # nic1=virtio
    # mac1=00:25:3F:ad:0b:1e
    # netdev1=tap,ifname=gentap,bridge=br1,script=no
    #
    # Example qemu command-line outcome for same two NICs is:
    #  -netdev tap,id=dwh1847,ifname=kvmtap1847,script=no
    #  -device virtio-net-pci,netdev=dwh1847
    #
    #  -netdev tap,id=dwh9896,ifname=kvmtap9896,script=no
    #  -device virtio-net-pci,netdev=dwh9896 
    #
    printf "Process the netdevs: createNewVM\n" if ($verbose);
	foreach (sort keys(%netdevs))
	{
		my $n = 0;
        my $ifname;
        my $macaddr;
	
		if ($debug != 0)
		{
			printf "Generating netdev and associated NIC device $_ configuration\n";
		}

        #  netdev number (default is zero)
		if ($_ =~ /netdev=(\d)/i)
		{
			$n = $1;
		}
		
        # If no netdev type was specified we should look in the vlan setting
        if (!$nics{$_})
        {
            # Syntax only allows for bridge name and nic type
            if ($netdevs{$_} =~ /tapbridge=(.+)[\,].*$/i)
            {
                $netdevs{$_} = "tap,bridge=$1,ifname=gentap,script=no,downscript=no";
            }
            if ($netdevs{$_} =~ /nic=(.+)/i)
            {
                $nics{$_} = $1;
            }
#			if (!$nics{$_})
#			{
#				die "Invalid auto-generate tap/bridge syntax\n";
#				$nics{$_} = " ";
#			}
        }

        # If no MAC address was specified or we are cloning a config then generate one
        if ((!$macs{$_}) || ($createVM && ($vmsource ne "")))
        {
            my $octet;
            $macaddr = @ouis[int(rand(1 + scalar @ouis))];
            # Generate a mac address
            for ($i = 0; $i < 3; $i++)
            {
                # Byte value between 2 and 254
#				$octet = (int(rand(126)) + 1) << 1;
                $octet = 2 + int(rand(252));
                $macaddr .= ":";
                $macaddr .= sprintf("%02x", $octet);
            }

            printf __LINE__, ": ", (caller(0))[3], " Generated MAC address: $macaddr\n" if ($verbose);
            $macs{$_} = $macaddr;
        }

        # Write out the settings
        if ($_ =~ /^netdev=(\d)/i)
        {
            if ($nics{$_})
            {
                print $vmcfg "nic$1=$nics{$_}\n";
            }
            print $vmcfg "mac$1=$macs{$_}\n";
            print $vmcfg "netdev$1=$netdevs{$_}\n";
        }
	}

	if ($net)
	{
		print $vmcfg "net=$net\n";
	}

	foreach (keys(%scsidrives))
	{
		# Write the setting
		print $vmcfg "scsidrive$_=$scsidrives{$_}\n";
	}

	if ($serial)
	{
		print $vmcfg "serial=$serial\n";
	}

	if ($soundhw)
	{
		print $vmcfg "soundhw=$soundhw\n";
	}

	if ($startdate)
	{
		print $vmcfg "startdate=$startdate\n";
	}

	if ($startdatefile)
	{
		print $vmcfg "startdatefile=$startdatefile\n";
	}

	if ($snapshot)
	{
		print $vmcfg "snapshot\n";
	}

	if ($logBIOS)
	{
		print $vmcfg "logbios\n";
	}

	if ($win2khack)
	{
		print $vmcfg "win2khack\n";
	}

	if ($noacpi)
	{
		print $vmcfg "noacpi\n";
	}

	if ($nokvm)
	{
		print $vmcfg "nokvm\n";
	}
	
	if ($nostart)
	{
		print $vmcfg "nostart\n";
	}

	if ($pidfile)
	{
		print $vmcfg "pidfile=$pidfile\n";
	}


	if ($loadvm)
	{
		print $vmcfg "loadvm=$loadvm\n";
	}

	foreach(@chardevs) {
		print $vmcfg "chardev=$_\n";
	}

	if ($mon)
	{
		print $vmcfg "mon=$mon\n";
	}

	if ($sermon)
	{
		print $vmcfg "sermon=$sermon\n";
	}

#print "TRYING TO FIND OPTIONS in $options !!!!!!!!!!!!!!!!!!!\n";

	if ($options)
	{
		print $vmcfg "options=$options\n";
	}

	close $vmcfg;

	dumpVMConfig();
}


sub editVMConfig
{
	# Set the config directory and config filename
	$vmcfgdir = getConfigDir();	#$ENV{HOME}."/.vmlauncher/";
	$vmcfgfile = getConfigFileName();	#$vmcfgdir.$vmname;

	(-e $vmcfgfile) or die("No such VM\n");
	(-r $vmcfgfile) or die("Unreadable configuration file\n");

    if ($pretendExec)
    {
        print("\nsystem: $vibin $vmcfgfile\n");
    }
    else
    {
        system("$vibin $vmcfgfile");
    }
}


sub dumpVMConfig
{
	print "Effective VM Configuration\n\n";

	if (! ($name eq ""))
	{
		print "VM Name:      $name\n";
	}
	if ($vmdir)
	{
		print "Location:     $vmdir\n";
	}
	if ($machine)
	{
		print "Machine type: $machine\n";
	}
	if (CPUIsValid())
	{
		print "CPU model:    $cpu\n";
	}
	elsif ($cpu ne "")
	{
		print "Unrecognized CPU model $cpu\n";
	}
	print "CPUs:         $cpus\n";
	print "Memory:       $mem\n";
	if ($uuid ne "")
	{
		print "Machine UUID: $uuid\n";
	}
	print "CLOCK:        ";
	if ($localtime)
	{
		print "LOCALTIME\n";
	}
	else
	{
		print "UTC\n";
	}
	print "DISPLAY:      ";
	if ($vgatype eq "std")
	{
		print "Standard VGA\n";
	}
	elsif ($vgatype eq "vmware")
	{
		print "VMWare\n";
	}
	elsif ($vgatype eq "qxl")
	{
		print "QXL\n";
	}
	elsif ($vgatype eq "none")
	{
		print "None\n";
	}
	else
	{
		# The default
		print "Cirrus\n";
	}
	if (defined($vnc))
	{
		print " VNC:         $vnc\n";
	}
	if ($curses)
	{
		print " Uses curses/ncurses for screen I/O\n";
	}
	print "USB:          ";
	if ($usb)
	{
		print "ON\n";
	}
	else
	{
		print "OFF\n";
	}
	print "KEYBOARD:     ";
	if ($usbkbd)
	{
		print "USB\n";
	}
	else
	{
		print "i8042\n";
	}
	print "MOUSE:        ";
	if ($usbmouse)
	{
		print "USB\n";
	}
	else
	{
		print "i8042\n";
	}
	if ($altgrab)
	{
        print "Use alternate mouse grab keystroke (Ctrl-Alt-Shift)\n";
	}
	else
	{
        print "Use default mouse grab keystroke (Ctrl-Alt)\n" if ($verbose);
	}
	if ($fda)
	{
		print "FLOPPY 0:     $fda\n";
	}
	if ($fdb)
	{
		print "FLOPPY 1:     $fdb\n";
	}
	if ($hda)
	{
		print "IDE 0:MASTER: $hda\n";
	}
	if ($hdb)
	{
		print "IDE 0:SLAVE:  $hdb\n";
	}
	if ($hdc)
	{
		print "IDE 1:MASTER: $hdc\n";
	}
	if ($hdd)
	{
		print "IDE 1:SLAVE:  $hdd\n";
	}
	if ($sda)
	{
		print "SCSI 0:DEV 0: $sda\n";
	}
	if ($sdb)
	{
		print "SCSI 0:DEV 1: $sdb\n";
	}
	if ($sdc)
	{
		print "SCSI 0:DEV 2: $sdc\n";
	}
	if ($sdd)
	{
		print "SCSI 0:DEV 3: $sdd\n";
	}
	if ($sdi)
	{
		print "SCSI 1:DEV 0: $sdi\n";
	}
	if ($cdrom)
	{
		print "CD/DVD DRIVE: $cdrom\n";
	}

	foreach (sort keys(%drives))
	{
		my $if;
		my $bus;
		my $tid;
		my $index;
		my $drive;

#		print " DRIVE KEY: $_ WITH VALUE $drives{$_}\n";

        # For the bus.id syntax
		if ($_ =~ /(.)drive(\d)\/(\d)/i)
		{
            undef($index);
			$if = $1;
			$bus = $2;
			$tid = $3;
#			print " DRIVE KEY DESCRIBES I/F $if, BUS $bus AND TARGET ID $tid\n";
		}
        # For the index syntax
		elsif ($_ =~ /(.)drive(\d+)/i)
		{
			$if = $1;
			$index = $2;
			undef($bus);
			undef($tid);
#			print " DRIVE KEY DESCRIBES I/F $if AND INDEX $index\n";
		}
		else
		{
            undef($if);
		}

		if (0)
		{
			if (defined($if))
			{
				print " HAS I/F\n";
			}
			else
			{
				print " NO I/F\n";
			}

			if (defined($bus))
			{
				print " HAS BUS\n";
			}
			else
			{
				print " NO BUS\n";
			}

			if (defined($tid))
			{
				print " HAS TARGET ID\n";
			}
			else
			{
				print " NO TARGET ID\n";
			}

			if (defined($index))
			{
				print " HAS DEVICE INDEX\n";
			}
			else
			{
				print " NO DEVICE INDEX\n";
			}

			if ($drives{$_})
			{
				print " HAS VALUE\n";
			}
			else
			{
				print "NO DRIVES VALUE FOR KEY $_\n";
			}
		}

        if ($drives{$_})
        {
            if (defined($if))
            {
                if ($if == "s" || $if == "S")
                {
                    print "SCSI";
                }
                elsif ($if == "v" || $if == "V")
                {
                    print "VIRTIO";
                }
                else
                {
                    print "UNKNOWN I/F ($if)";
                }
                
                if (defined($bus) && defined($tid))
                {
                    print " disk at BUS $bus UNIT $tid\n"
                }
                elsif (defined($index))
                {
                    print " disk at INDEX $index";
                }
                else
                {
                    print " disk with no device ID";
                }
            }
            else
            {
                print "Disk specified with no interface";
            }
                
            print ": $drives{$_}\n";
		}
    }

	if ($boot)
	{
		print "BOOT DEVICE:  $boot\n";
	}

	if ($bootOnce)
	{
		print "ONE TIME BOOT DEVICE:  $bootOnce\n";
	}

	if ($bootMenu)
	{
		print "SHOW BIOS BOOT DEVICE MENU\n";
	}

	foreach (keys(%vlans))
	{
#		my $ifname;
	
#		die "No NIC for $_\n" if (!$nics{$_});
        next if ($nics{$_} eq "");
        
		print "NIC:          $_\n";
		if ($nics{$_})
		{
			print "              $nics{$_}\n";
		} else {
			print "              default NIC\n";
		}
		print "              $macs{$_}\n";
	}

    # netdev NICs
	foreach (keys(%netdevs))
	{
		my $ifname;
	
#		die "No NIC for $_\n" if (!$nics{$_});
		print "NIC(netdev):  $_\n";
		if ($nics{$_})
		{
			print "              $nics{$_}\n";
		} else {
			print "              default NIC\n";
		}
		print "              $macs{$_}\n";
	}

	if ($net)
	{
		print "Net (Extra):  $net\n";
	}

	foreach (keys(%scsidrives))
	{
		print "SCSI DRIVE:   $_\n";
		print "              $scsidrives{$_}\n";
	}

	foreach (@usbdevices)
	{
		print "USB DEVICE:   $_\n";
	}

	if ($serial)
	{
		print "SERIAL PORT:  $serial\n";
	}

	if ($soundhw)
	{
		print "SOUND:        $soundhw\n";
	}

	if ($startdate)
	{
		print "START DATE:   $startdate\n";
	}

	if ($startdatefile)
	{
		print "START DATE FILE: $startdatefile\n";
	}

	if ($snapshot)
	{
		print "USE TEMPORARY FILES FOR DISK\n";
	}

	if ($logBIOS)
	{
		print "Show SeaBIOS log\n";
	}

	if ($win2khack)
	{
		print "WINDOWS 2000 IDE HACK\n";
	}
	
	if ($noacpi)
	{
		print "DISABLE ACPI\n";
	}
	
	if ($nokvm)
	{
		print "DO NOT USE KVM\n";
	}
	
	if ($nostart)
	{
		print "LAUNCH QEMU BUT DO NOT START GUEST\n";
	}
	if ($daemonize)
	{
		print " Daemonize QEMU after initialization\n";
	}
	if ($pidfile)
	{
		print " Save PID in $pidfile\n";
	}

	if ($loadvm)
	{
		print "LAUNCH SNAPSHOT: $loadvm\n";
	}

	foreach(@chardevs) {
		print "CHARDEV:      $_\n";
	}

	if ($mon)
	{
		print "MONITOR:      $mon\n";
	}
	
	if ($sermon)
	{
		print "SER MONITOR:  $sermon\n";
	}
	
	if ($qmpserverport != 0)
	{
		print "QMP SERVER ON PORT: $qmpserverport\n";
	}

#print "TRYING TO FIND OPTIONS in $options !!!!!!!!!!!!!!!!!!!\n";

	if ($options)
	{
		print "ADDITIONAL:   $options\n";
	}
	
	print "\n";
}


sub generateVMCommandLine
{
	# Build a command line in the global variable
	if (!$hack)
	{
		$cmdline = $qemubin;
	}
	else
	{
        $cmdline = $qemubin;
        $cmdline .= " -accel kvm";
		#$cmdline = $qemuhack;
	}
	
	# Basic system
	if ($machine)
	{
		$cmdline .= " -machine $machine";
	}
	if ($cpu ne "")
	{
		$cmdline .= " -cpu $cpu";
	}
	$cmdline .= " -smp $cpus";
	$cmdline .= " -m $mem";
	$cmdline .= " -uuid $uuid" if ($uuid ne "");
	$cmdline .= " -localtime" if ($localtime);

	if ($usb)
	{
	  $cmdline .= " -usb";
	  
	  # Keyboard and mouse
	  $cmdline .= " -device usb-kbd" if ($usbkbd);
#	$cmdline .= " -device usb-mouse" if ($usbmouse);
#	  $cmdline .= " -usbdevice mouse" if ($usbmouse);
	  $cmdline .= " -device usb-mouse" if ($usbmouse);
	}

	$cmdline .= " -alt-grab" if ($altgrab);

	#Floppy disks
	if ($fda)
	{
        $cmdline .= " -fda $fda";
        # $cmdline .= " -drive if=none,id=FD-A,file=$fda -global isa-fdc,driveA=FD-A,driveB=FD-B";
	}
	if ($fdb)
	{
		$cmdline .= " -fdb $fdb";
	}
	
	# IDE Hard disks
	if ($hda)
	{
		$cmdline .= " -hda $hda";
	}
	if ($hdb)
	{
		$cmdline .= " -hdb $hdb";
	}
	if ($hdc)
	{
		$cmdline .= " -hdc $hdc";
	}
	if ($hdd)
	{
		$cmdline .= " -hdd $hdd";
	}
	
	# SCSI Hard disks
	if ($sda)
	{
		$cmdline .= " -drive file=$sda,if=scsi,bus=0,unit=0";
# 		if (!$hda && $boot && ($boot =~ "c" || $boot =~ "C"))
# 		{
# 			$cmdline .= ",boot=on"
# 		}
	}
	if ($sdb)
	{
		$cmdline .= " -drive file=$sdb,if=scsi,bus=0,unit=1,cache=none"
	}
	if ($sdc)
	{
		$cmdline .= " -drive file=$sdc,if=scsi,bus=0,unit=2"
	}
	if ($sdd)
	{
		$cmdline .= " -drive file=$sdd,if=scsi,bus=0,unit=3"
	}
	if ($sdi)
	{
		$cmdline .= " -drive file=$sdi,if=scsi,bus=1,unit=0,cache=none"
	}

	# CD-ROM
	if ($cdrom || $rip)
	{
		$cmdline .= " -cdrom ";
		if ($rip)
		{
			$cmdline .= $ripcdrom;
		}
		else
		{
			$cmdline .= $cdrom;
		}
	}

	print __LINE__, ": ", (caller(0))[3], " Process the drives\n" if ($verbose);
	foreach (sort keys(%drives))
	{
		my $if;
		my $bus;
		my $tid;
		my $index;
		my $drive;

# 		print " DRIVE KEY: $_ WITH VALUE $drives{$_}\n";

		# Format of this key is a single character interface identifier
		# (s=scsi, v=virtio), a backslash, the bus ID number,
		# a backslash, the unit number to use on the bus
		if ($_ =~ /(.)\/(\d)\/(\d)/i)
		{
			$if = $1;
			$bus = $2;
			$tid = $3;
			undef($index);
# 			print " DRIVE KEY DESCRIBES I/F $if, BUS $bus AND TARGET ID $tid\n";
		}
		# Format of this key is a single character interface identifier
		# (s=scsi, v=virtio), a backslash and the drive index
		elsif ($_ =~ /(.)\/(\d+)/i)
		{
			$if = $1;
			$index = $2;
			undef($bus);
			undef($tid);
# 			print " DRIVE KEY DESCRIBES I/F $if, BUS $bus AND TARGET ID $tid\n";
		}
		else
		{
            undef($if);
		}

		# If we have a parameter value
		if ($drives{$_})
		{
            my $drivearg;
            
            # Prepare a drive argument with a file and start the
            # interface parameter
            $drivearg = " -drive file=$drives{$_},if=";
            
            if (defined($if))
            {
                # For each supported interface found, add the value
                if ($if eq "s" || $if eq "S")
                {
                    $drivearg .= "scsi";
                }
                elsif ($if eq "v" || $if eq "V")
                {
                    $drivearg .= "virtio";
                }
                else
                {
                    print "UNKNOWN DRIVE INTERFACE TYPE $if, IGNORING DRIVE\n" if ($verbose);
                    $drivearg = "";
                }

                # If we got everything as far as an interface, complete
                # the drive argument with the bus and unit or the index
                if ($drivearg ne "")
                {
                    $cmdline .= $drivearg;
                    
                    # If we have an interface, bus, unit and filename
                    if (defined($if) && defined($bus) && defined($tid))
                    {
                        $cmdline .= ",bus=$bus,unit=$tid";
                    }            
                    # If we have an index number
                    elsif (defined($index))
                    {
                        $cmdline .= ",index=$index";
                    }
                }
            }
            else
            {
                print "DRIVE SPECIFIED WITHOUT AN INTERFACE: $_ = $drives{$_}\n";
            }
        }
	}

	# Boot device
	if ($boot || $bootOnce || $bootMenu || $rip)
	{
		$cmdline .= " -boot ";
		if ($rip)
		{
			$cmdline .= "order=d";
		}
		else
		{
			if ($boot)
			{
				$cmdline .= "order=$boot";
				$cmdline .= "," if ($bootOnce || $bootMenu);
			}
			if ($bootOnce)
			{
				$cmdline .= "once=$bootOnce";
				$cmdline .= "," if ($bootMenu);
			}
			$cmdline .= "menu=on" if ($bootMenu);
		}
	}
	
	# NICs by vlan
	print __LINE__, ": ", (caller(0))[3], " Process the vlans\n" if ($verbose);
	foreach (sort keys(%vlans))
	{
		my $ifname;
		my $vlanport;
		my $copyvlan;
		my $i;
		
#		die "No NIC for $_\n" if (!$nics{$_});

        next if ($_ eq "");

		if ($nics{$_})
		{
            print __LINE__, ": ", (caller(0))[3], " Processing NIC for VLAN $_ value is $nics{$_}\n" if ($verbose);
            
			if ($nics{$_} =~ /^i82.*$/)
			{
                print __LINE__, ": ", (caller(0))[3], "\n" if ($verbose);
				$cmdline .= " -device $nics{$_},$_";
				$cmdline .= ",mac=$macs{$_}" if ($macs{$_});
			}
			elsif ($nics{$_} =~ /^usb-net$/)
			{
                print __LINE__, ": ", (caller(0))[3], "\n" if ($verbose);
				$cmdline .= " -device $nics{$_},$_";
				$cmdline .= ",mac=$macs{$_}" if ($macs{$_});
			}
			else
			{
                print __LINE__, ": ", (caller(0))[3], "\n" if ($verbose);
				$cmdline .= " -net nic,$_,model=$nics{$_}";
				$cmdline .= ",macaddr=$macs{$_}" if ($macs{$_});
			}
		} else {
            print __LINE__, ": ", (caller(0))[3], "\n" if ($verbose);
			$cmdline .= " -net nic,$_";
		}

		$vlanport = $vlans{$_};
		if ($vlanport =~ /^vlan(\d)$/i)
		{
			$copyvlan = "vlan=$1";
			$vlans{$_} = $vlans{$copyvlan};
		}
		if (($vlans{$_} =~ /,ifname=gentap/i) || ($vlans{$_} =~ /,gentap/i ))
		{
			$ifname = (rand() * 10000) % 10000;
			$i = 0 + @taps;
			$taps[$i] = "kvmtap".sprintf("%d", $ifname);
			$vlans{$_} =~ s/,ifname=gentap/,ifname=$taps[$i]/i;
			$vlans{$_} =~ s/,gentap/,ifname=$taps[$i]/i;
	
			my $us = $_;
	
			print __LINE__, ": ", (caller(0))[3], " Bridge parsing $vlans{$_}\n" if $verbose;
	
			if ($vlans{$_} =~ /,bridge=(.*?),/i)
			{
				$bridges{$taps[$i]} = $1;
				$vlans{$us} =~ s/,bridge=.*?,/,/i;
				print "  Found bridge $bridges{$taps[$i]}, modified vlan: $vlans{$us}\n" if ($verbose);
			}
		}
	
		$cmdline .= " -net $vlans{$_},$_";
	}
	
	# Generate netdevs and related device command-line elements, e.g.:
    # -netdev tap,id=dwh1847,ifname=kvmtap1847,script=no
    # -device virtio-net-pci,netdev=dwh1847
    #
    # -netdev tap,id=dwh9896,ifname=kvmtap9896,script=no
    # -device virtio-net-pci,netdev=dwh9896 
	print __LINE__, ": ", (caller(0))[3], " Process the netdevs\n" if ($verbose);
	foreach (sort keys(%netdevs))
	{
		my $idnum;
		my $idname;
		my $netdevport;
		my $copynetdev;
		my $i;
		my $ifname;
	
#		die "No NIC for $_\n" if (!$nics{$_});
        printf __LINE__, ": ", (caller(0))[3], " Processing NIC for netdev $_ value is $nics{$_}\n" if ($verbose && $nics{$_});

		if (($netdevs{$_} =~ /,ifname=gentap/i) || ($netdevs{$_} =~ /,gentap/i ))
		{
			$idnum = (rand() * 10000) % 10000;
			$ifname = (rand() * 10000) % 10000;
			$i = 0 + @taps;
			$taps[$i] = "kvmtap".sprintf("%d", $ifname);
			$idname = "qdevid".sprintf("%d", $idnum);
        }
        
		if ($nics{$_})
		{
            print __LINE__, ": ", (caller(0))[3], "\n" if ($verbose);
			if ($nics{$_} =~ /^i82.*$/)
			{
                print __LINE__, ": ", (caller(0))[3], "\n" if ($verbose);
				$cmdline .= " -device $nics{$_},netdev=qdeved$_";
				$cmdline .= ",mac=$macs{$_}" if ($macs{$_});
			}
			elsif ($nics{$_} =~ /^usb-net$/)
			{
                print __LINE__, ": ", (caller(0))[3], "\n" if ($verbose);
				$cmdline .= " -device $nics{$_},$_";
				$cmdline .= ",mac=$macs{$_}" if ($macs{$_});
			}
			else
			{
                print __LINE__, ": ", (caller(0))[3], "\n" if ($verbose);
#				$cmdline .= " -device nic,$_,model=$nics{$_}";
                $cmdline .= " -device $nics{$_}";
                $cmdline .= ",netdev=$idname";
#				$cmdline .= ",macaddr=$macs{$_}" if ($macs{$_});
				$cmdline .= ",mac=$macs{$_}" if ($macs{$_});
			}
		} else {
            print __LINE__, ": ", (caller(0))[3], "\n" if ($verbose);
#			$cmdline .= " -device e1000,netdev=$idname";
			$cmdline .= " -device virtio-net-pci,netdev=$idname";
			$cmdline .= ",mac=$macs{$_}" if ($macs{$_});
		}

		$netdevport = $netdevs{$_};
		if ($netdevport =~ /^netdev(\d)$/i)
		{
			$copynetdev = "netdev=$1";
			$netdevs{$_} = $netdevs{$copynetdev};
		}
		
		if (($netdevs{$_} =~ /,ifname=gentap/i) || ($netdevs{$_} =~ /,gentap/i ))
		{
			$netdevs{$_} =~ s/,ifname=gentap/,id=$idname,ifname=$taps[$i]/i;
			$netdevs{$_} =~ s/,gentap/,id=$idname,ifname=$taps[$i]/i;
	
			my $us = $_;
	
			print __LINE__, ": ", (caller(0))[3], " Bridge parsing $netdevs{$_}\n" if $verbose;
	
			if ($netdevs{$_} =~ /,bridge=(.*?),/i)
			{
				$bridges{$taps[$i]} = $1;
				$netdevs{$us} =~ s/,bridge=.*?,/,/i;
				print "  Found bridge $bridges{$taps[$i]}, modified netdev: $netdevs{$us}\n" if $verbose;
			}
		}
	
		$cmdline .= " -netdev $netdevs{$_}";
	}

	print __LINE__, ": ", (caller(0))[3], " Process the NICs\n" if ($verbose);
	foreach (keys(%nics))
	{
 		my $ifname;
	
		next if ($vlans{$_});
	
        if ($netdevs{$_})
        {
#DWH            $cmdline .= " -device $nics{$_}";
#DWH            $cmdline .= ",mac=$macs{$_}" if ($macs{$_});
            $cmdline .= " ";
        }
        else
        {
            $cmdline .= " -net nic,$_,model=$nics{$_}";
            $cmdline .= ",macaddr=$macs{$_}" if ($macs{$_});
        }
	}
	
	if ($net)
	{
		$cmdline .= " -net $net";
	}
	
	print "\n" if $verbose;
	
	# SCSI drives
	foreach (keys(%scsidrives))
	{
		$cmdline .= " -drive file=$scsidrives{$_},if=scsi,index=$_";
		if ($snapshot)
		{
			$cmdline .= ",snapshot=on";
		}
	}
	
	# USB devices
	foreach (@usbdevices)
	{
		$cmdline .= " -usbdevice $_";
	}

	loadStartDateFile();

	if ($startdate)
	{
		$cmdline .= " -startdate $startdate";
	}
	
	if ($vgatype eq "std")
	{
		$cmdline .= " -vga std";
#		$cmdline .= " -device VGA";
	}
	elsif ($vgatype eq "vmware")
	{
#		$cmdline .= " -vga vmware";
		$cmdline .= " -device vmware-svga";
	}
	elsif ($vgatype eq "qxl")
	{
		$cmdline .= " -vga qxl";
	}
	elsif ($vgatype eq "none")
	{
		$cmdline .= " -vga none";
	}
	else
	{
		# The default, but state it anyway
		$cmdline .= " -vga cirrus";
#		$cmdline .= " -device cirrus-vga";
	}

	foreach(@chardevs) {
		$cmdline .= " -chardev $_";
	}
	
	if ($mon)
	{
		$cmdline .= " -mon $mon";
	}
	
	if ($sermon)
	{
		$cmdline .= " -serial mon:$sermon";
	}
	
	if ($serial)
	{
		$cmdline .= " -serial $serial";
	}
	
	if ($soundhw)
	{
		$cmdline .= " -soundhw $soundhw";
	}

	if (defined($vnc))
	{
		$cmdline .= " -vnc $vnc";
	}
	else
	{
        if ($sdl)
        {
            $cmdline .= " -display sdl";
            $cmdline .= " -sdl";
        }
        elsif ($curses)
        {
            $cmdline .= " -curses";
        }
    }
	
	if ($daemonize)
	{
		$cmdline .= " -daemonize";
	}
	
	if ($snapshot)
	{
		$cmdline .= " -snapshot";
	}
	
	if ($win2khack)
	{
		$cmdline .= " -win2k-hack";
	}
	
	if ($logBIOS)
	{
		$cmdline .= " -chardev stdio,id=seabios -device isa-debugcon,iobase=0x402,chardev=seabios";
#		$cmdline .= " -chardev virtconsole,id=seabios -device isa-debugcon,iobase=0x402,chardev=seabios,name=console.3";
	}
	
	if ($noacpi)
	{
		$cmdline .= " -no-acpi";
	}
	
	if ($noballoon)
	{
		$cmdline .= " -balloon none";
	}
	
	if ($nohpet)
	{
		$cmdline .= " -no-hpet";
	}
	
	if ($nokvm)
	{
		$cmdline .= " -no-kvm";
	}
	else
	{
		$cmdline .= " -enable-kvm";
	}
	
	if ($nostart)
	{
		$cmdline .= " -S";
	}
	
	if ($pidfile)
	{
		$cmdline .= " -pidfile \"$pidfile\"";
	}
	
	if ($qmpserverport != 0)
	{
		$cmdline .= " -qmp tcp:localhost:$qmpserverport,server";
	}
	
	$cmdline .= " -name \"$name\"" if ($name);
	
	#print "TRYING TO ADD OPTIONS $options !!!!!!!!!!!!!!!!!!!\n";
	
	$cmdline .= " $options" if ($options);
	
	print "Command line = $cmdline\n" if ($verbose);
	
	print "\n\n" if ($verbose);

	foreach (@taps)
	{
#		print($sudobins{'sudo'}." ".$sudobins{'tunctl'}." -u $user -t $_\n" if ($verbose);
        print("\nsystem: ".$sudobins{'sudo'}." ".$sudobins{'tunctl'}." -u $user -t $_\n") if ($verbose || $pretendExec);
        if (!$pretendExec)
        {
            system($sudobins{'sudo'}." ".$sudobins{'tunctl'}." -u $user -t $_") if (!$test);
        }

		# Switch to ip (2017-10-26)
#		print $sudobins{'sudo'}." ".$sudobins{'ifconfig'}." $_ up 0.0.0.0 promisc\n" if ($verbose);
#		system($sudobins{'sudo'}." ".$sudobins{'ifconfig'}." $_ up 0.0.0.0 promisc") if (!$test);
		print("system: ".$sudobins{'sudo'}." ".$sudobins{'ip'}." addr add 0.0.0.0 dev $_\n") if ($verbose || $pretendExec);
        if (!$pretendExec)
        {
            system($sudobins{'sudo'}." ".$sudobins{'ip'}." addr add 0.0.0.0 dev $_") if (!$test);
        }
		print("system: ".$sudobins{'sudo'}." ".$sudobins{'ip'}." link set $_ up\n") if ($verbose || $pretendExec);
        if (!$pretendExec)
        {
            system($sudobins{'sudo'}." ".$sudobins{'ip'}." link set $_ up") if (!$test);
        }

		if ($bridges{$_} && ! ($bridges{$_} eq "private"))
		{
			print("system: ".$sudobins{'sudo'}." ".$sudobins{'brctl'}." addif $bridges{$_} $_\n") if ($verbose || $pretendExec);
            if (!$pretendExec)
			{
                system($sudobins{'sudo'}." ".$sudobins{'brctl'}." addif $bridges{$_} $_") if (!$test);
            }
		}
		else
		{
			print "Private bridge for $_\n";
		}
	}
	
	# Load a vm snapshot (from a qcow2 disk file) if requested
	if ($loadvm)
	{
		$cmdline .= " -loadvm $loadvm";
	}
}


sub listVMs
{
	my $i;
	my $l;
	my $vmdir;
	my $vmfile;
	my @lt;
	my $yr;
	my $st;
	my @vms;

	# List the files in the generic base directory for VM configs
	$vmdir = getConfigDir();
	#$ENV{HOME}."/.vmlauncher/";
	opendir(DIR, $vmdir);
	@vms = readdir(DIR);
	closedir(DIR);

	# Print the names
	foreach $vmfile (@vms)
	{
		if (! ($vmfile =~ '^\.') && ($vmfile ne '..') && ! ($vmfile =~ /~$/))
		{
			$st = stat($vmdir.$vmfile);

			if ($verbose) {
				@lt = localtime($st->atime);
				$yr = 1900 + $lt[5];
				printf("%04d-%02d-%02d  ", $yr, $lt[4], $lt[3]);
			}

			print $vmfile."\n";
		}
	}

	print "\n";
}


sub loadStartDateFile
{
	if ($startdatefile)
	{
		if (open($sdfile, "<", $startdatefile))
		{
			while (defined($sdfile) && ($startdate = <$sdfile>) && ($startdate =~ /^#(.*)/))
			{
			}
			close($sdfile);
			print "Using start date from file: $startdate\n" if ($verbose);
		}
	
		if (!$startdate || ($startdate eq ""))
		{
			if ($localtime)
			{
				$dt = DateTime->now( time_zone => "local" );
			}
			else
			{
				$dt = DateTime->now();
			}
	
			$startdate = "$dt";
			print "Using now as start date: $startdate\n" if ($verbose);
		}
	
		if ($startdate =~ /^(\d{4})-(\d{2})-(\d{2})/)
		{
			$sy = $1;
			$sm = $2;
			$sd = $3;
		}
		if ($startdate =~ /^\d+-\d+-\d+T(\d{2})/)
		{
			$shr = $1;
		}
		if ($startdate =~ /^\d+-\d+-\d+T\d{2}:(\d{2})/)
		{
			$smn = $1;
		}
		if ($startdate =~ /^\d+-\d+-\d+T\d{2}:\d{2}:(\d{2})/)
		{
			$ssc = $1;
		}
	
		$sdt = new DateTime(	year	=> $sy,
					month	=> $sm,
					day	=> $sd,
					hour	=> $shr,
					minute	=> $smn,
					second	=> $ssc );
	
		print "Selected startdate: $sdt\n" if ($verbose);
		$starttime = DateTime->now();
		print "Starting VM at $starttime\n" if ($verbose);
	}
}


sub saveStartDateFile
{
	if ($startdatefile && !$daemonize)
	{
		if  (!$snapshot)
		{
			$vmelapsed = DateTime->now() - $starttime;
			print "VM Elapsed runtime: $vmelapsed\n" if ($verbose);
			$vmelapsed->add(seconds => 15);
			print "VM padded runtime: $vmelapsed\n" if ($verbose);
		
			$sdt->add($vmelapsed);
		
			print "Next start time: $sdt\n" if ($verbose);
		
			$startdate = "$sdt";
			print "Next start time value: $startdate\n" if ($verbose);
		
			if (open($sdfile, ">", $startdatefile))
			{
				print "Writing start date to file: $startdate\n" if ($verbose);
				print $sdfile "$startdate";
				close($sdfile);
			}
		}
		else
		{
			print "Snapshot used, not updating startdate file\n";
		}
	}
}


sub generateVMDirDiskPaths
{
	# Ensure vmdir ends in a slash
	if (!($vmdir =~ /\/$/))
	{
		$vmdir .= "/";
	}

	# Insert the vmdir path before each disk path/filename

	if ($fda)
	{
		$fda = $vmdir.$fda;
	}
	if ($fdb)
	{
		$fdb = $vmdir.$fdb;
	}
	if ($hda)
	{
		$hda = $vmdir.$hda;
	}
	if ($hdb)
	{
		$hdb = $vmdir.$hdb;
	}
	if ($hdc)
	{
		$hdc = $vmdir.$hdc;
	}
	if ($hdd)
	{
		$hdd = $vmdir.$hdd;
	}
	if ($sda)
	{
		$sda = $vmdir.$sda;
	}
	if ($sdb)
	{
		$sdb = $vmdir.$sdb;
	}
	if ($sdc)
	{
		$sdc = $vmdir.$sdc;
	}
	if ($sdd)
	{
		$sdd = $vmdir.$sdd;
	}
	if ($sdi)
	{
		$sdi = $vmdir.$sdi;
	}
	if ($cdrom)
	{
		$cdrom = $vmdir.$cdrom;
	}
}


# Program entry point
print "\nKVM/QEMU Virtual Machine Launcher (version $ver)\n\n";

findBinaries();

$acval = 0 + @ARGV;
if (($acval == 1) && ($ARGV[0] =~ m/--version/i))
{
	exit 0;
}

GetOptions('vm=s' => \$vmname,
		'create' => \$createVM,
		'edit' => \$editVM,
		'list' => \$listVMs,
		'ls' => \$listVMs,
		'vmsrc=s' => \$vmsource,
		'verbose' => \$verbose,
		'vs' => \$verbosnap,
		'test' => \$test,
		'sub=s' => \$subname);
		
if ($verbosnap)
{
	$verbose = 1;
	$snapshot = 1;
}
		
if ($listVMs)
{
	listVMs();
	exit 0;
}

if ($editVM)
{
	editVMConfig();
	exit 0;
}

my $remainingArgs;

$i = 0;
foreach (@ARGV)
{
	if ($i != 0)
	{
		$remainingArgs .= " ";
	}
	else
	{
		$i = 1;
	}
	$remainingArgs .= "$_";
}
if ($remainingArgs)
{
	print "Remaining command line: $remainingArgs\n" if ($debug);
}
else
{
	print "Command line all handled\n" if ($verbose);
}

if (length($vmname) == 0)
{
	die "You must specify a virtual machine config filename\n";
}

# Try to open the supplied config file as a literal path
if (!$createVM)
{
	$vmcfgfile = $vmname;
}
elsif ($vmsource ne "")
{
	$vmcfgfile = $vmsource;
}

$vmcfgdir = "";

# BUG: This will over-ride the whole conditional above
$vmcfgfile = $vmname;

if (!$createVM)
{
    print __LINE__, ": Config filename supplied: $vmcfgfile\n" if ($debug);
	$configFound = 1;
	if (!open($vmcfg, "<", $vmcfgfile))
	{
        print __LINE__, ": Config filename is not fully qualified, trying with config dir\n" if ($debug);
		# Extract the generic base directory for VM configs from the environment
		$vmcfgdir = getConfigDir();
		#$ENV{HOME}."/.vmlauncher/";
	
		# Add the config name
		$vmcfgfile = $vmcfgdir.$vmname;
	
		# Try to open the constructed path
		if (!open($vmcfg, "<", $vmcfgfile))
		{
			$configFound = 0;
		}
		
		# Yuk, look for verbose here so that we can re-parse with it on
		if ($configFound && !$verbose)
		{
			my $ln;
			while (<$vmcfg>)
			{
				if ($_ =~ /^--/)
				{
					$ln = $_;
				}
				else
				{
					$ln = "--".$_;
				}
				($ret, $remainder) = GetOptionsFromString($ln,
							'verbose' => \$verbose,
							'vs' => \$verbose);
				
				last if ($verbose);
			}
			
			# Re-set to start of file for everything else
			seek($vmcfg, 0, 0);
		}
	}
		
	if ($verbose)
	{
		print "VM Base directory is $vmcfgdir\n";
		print "VM config is $vmcfgfile\n\n";
	}
}
else
{
	$configFound = 0;
}

if ($configFound)
{
	print "Config found\n" if ($debug);
	while (<$vmcfg>)
	{
		print __LINE__, ": Parsing $_\n" if ($debug);
		parseConfigItem($_);
	
		# If we found a sub-section
		if ($insub)
		{
			# But are not looking for one
			if (!$subname)
			{
				# We are done
				last;
			}
	
			# If we have come to the end of the sub-section we were looking for
			if ($insub == 3)
			{
				# We are done
				last;
			}
		}
	}

	# Make VNC undefined if it is empty anyway
	if (defined($vnc) && ($vnc eq ""))
	{
        undef($vnc);
	}
	
	print "QMP setting is $qmpserverport\n" if ($qmpserverport != 0);
}

# Now do the remainder of the command line as over-rides
if ($remainingArgs)
{
	print "Parsing remaining arguments\n" if ($debug);
	foreach (@ARGV)
	{
		print __LINE__, ": Parsing $_\n" if ($debug);
		parseConfigItem($_);
	}

	# Make VNC undefined if it is empty anyway
	if (defined($vnc) && ($vnc eq ""))
	{
        undef($vnc);
	}
}

if ($createVM)
{
	createNewVM();
	exit 0;
}

if ($verbose)
{
	print "\nStart a KVM virtual machine\n\n";
}

print "\n\n" if ($verbose);

if (!$configFound && !$createVM)
{
	die "No VM configuration file found in $vmcfgfile\n";
}

# Validate some error cases
if ($subname)
{
	print "Sub-name is $subname in-sub is $insub\n" if ($verbose);
}
die "When you select a sub-section it must exist: $subname\n" if ($subname && ($insub < 2));
die "hdc and cdrom are mutually exclusive\n" if ($hdc && $cdrom);

if ($vmdir)
{
	generateVMDirDiskPaths();
}

if ($verbose || $dump)
{
	dumpVMConfig();
}

if (!$dump)
{
	generateVMCommandLine();
}

if (!$test && (length($cmdline) > 0))
{
	print "Starting VM\n";
    if ($pretendExec)
    {
        print("\nsystem: $cmdline\n");
    }
    else
    {
        system($cmdline);
    }
}
elsif (!$dump)
{
	print "Test mode, not starting VM\n";
}


if (!$dump)
{
	foreach (@taps)
	{
		if ($bridges{$_} && ! ($bridges{$_} eq "private"))
		{
			print("\nsystem: ".$sudobins{'sudo'}." ".$sudobins{'brctl'}." delif $bridges{$_} $_\n") if ($verbose || $pretendExec);
            if (!$pretendExec)
			{
                system($sudobins{'sudo'}." ".$sudobins{'brctl'}." delif $bridges{$_} $_") if (!$test && !$daemonize);
            }
		}
		else
		{
			print "Private bridge for $_\n";
		}
	
		# Switch to ip (2017-10-26)
#		print $sudobins{'sudo'}." ".$sudobins{'ifconfig'}." $_ down\n" if ($verbose);
#		system($sudobins{'sudo'}." ".$sudobins{'ifconfig'}." $_ down") if (!$test && !$daemonize);
		print("\nsystem: ".$sudobins{'sudo'}." ".$sudobins{'ip'}." link set $_ down\n") if ($verbose || $pretendExec);
		if (!$pretendExec)
        {
            system($sudobins{'sudo'}." ".$sudobins{'ip'}." link set $_ down") if (!$test && !$daemonize);
        }
		print("\nsystem: ".$sudobins{'sudo'}." ".$sudobins{'ip'}." addr del 0.0.0.0/32 dev $_\n") if ($verbose || $pretendExec);
        if (!$pretendExec)
        {
            system($sudobins{'sudo'}." ".$sudobins{'ip'}." addr del 0.0.0.0/32 dev $_") if (!$test && !$daemonize);
        }
	
		print("\nsystem: ".$sudobins{'sudo'}." ".$sudobins{'tunctl'}." -d $_\n") if ($verbose || $pretendExec);
        if (!$pretendExec)
        {
            system($sudobins{'sudo'}." ".$sudobins{'tunctl'}." -d $_") if (!$test && !$daemonize);
		}
	}

	saveStartDateFile();
}

print "\n\n";
