#!/usr/bin/perl
#
# Following version numbers precede the use of git but illustrate modifications
# v0.4.9 - David Mair - Re-modeled FDD/HDD and startdate file usage to share code
# v0.4.8 - David Mair - Fixed nic=<model> to allow model selection for netdev devices
# v0.4.7 - David Mair - Added "nonet" option to disable guest networking
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

my $ver = "0.4.9";

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
my @validCPUs = ("Opteron_G5", "Opteron_G4", "Opteron_G3", "Opteron_G2",
                    "Opteron_G1", "SandyBridge", "Nehalem", "Penryn", "Conroe",
                    "n270", "athlon", "pentium3", "pentium2", "pentium", "486",
                    "coreduo", "kvm32", "qemu32", "kvm64", "qemu64",
                    "core2duo", "phenom", "base", "host", "max");


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
my $sdl = 0;
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
my $nonet = 0;
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
my $vmelapsed;
my $sy = "0";
my $sm = "0";
my $sd = "0";
my $shr = "0";
my $smn = "0";
my $ssc = "0";
my %drives;

my %basicDrives;
my @fddKeys = ("fda", "fdb");
my @hddKeys = ("hda", "hdb", "hdc", "hdd");
my @opsForBasicDrives = ("dump", "write", "genCmd");

my %nics;
my %macs;
my %vlans;
my %netdevs;
my %netids;
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


sub vbTrace
{
    my $lnNum;
    my $pCaller;
    my $msg;

    return if (!$verbose);

    # We need a line number, the caller's caller and a message
    if (defined($_[0]) && defined($_[1]) && defined($_[2]))
    {
        $lnNum = $_[0];
        $pCaller = $_[1];
        $msg = $_[2];

        print "$lnNum".": $pCaller $msg\n";
    }
}


sub dbTrace
{
    my $lnNum;
    my $pCaller;
    my $msg;

    return if (!$debug);

    # We need a line number, the caller's caller and a message
    if (defined($_[0]) && defined($_[1]) && defined($_[2]))
    {
        $lnNum = $_[0];
        $pCaller = $_[1];
        $msg = $_[2];

        print "$lnNum".": $pCaller $msg\n";
    }
}


sub vbMessage
{
    my $msg;

    return if (!$verbose);

    # We need a message
    if (defined($_[0]))
    {
        $msg = $_[0];

        print "$msg\n";
    }
}


# Get global options that allow things like location of VM config files to be
# user chosen. Requires a file called .vmlauncher.cfg in home directory. File
# format is option=setting where the currently available options are:
#
# vmconfigsdir=<path containing VM config files>
#
sub getGlobalOptions
{
    my $vmGlobalCfg;
    my $vmGlobalCfgFile;
    my $ln;

    $vmGlobalCfgFile = $ENV{HOME}."/.vmlauncher.cfg";

    # Try to open the constructed path
    if (open($vmGlobalCfg, "<", $vmGlobalCfgFile))
    {
        dbTrace(__LINE__, (caller(0))[3], "DWH: Found  Global Config File");
        while (<$vmGlobalCfg>)
        {
            dbTrace(__LINE__, (caller(0))[3], "DWH: Parsing Global Config Item: $_");
            if ($_ =~ /^--/)
            {
                $ln = $_;
            }
            else
            {
                $ln = "--".$_;
            }
            ($ret, $remainder) = GetOptionsFromString($ln,
                                            'vmconfigsdir=s' => \$vmcfgdir);
        }
    }
    else
    {
        # Can't open a global config file, assume default VM config file directory
        $vmcfgdir = $ENV{HOME}."/.vmlauncher";
    }

    # Make sure it is treated as a directory entry name
    if (($vmcfgdir =~ m/\/$/))
    {
        $vmcfgdir =~ s/(.+)\/$/$1/;
    }

    # And replace ~ with ENV{HOME}
    $vmcfgdir =~ s/\~/$ENV{HOME}/;

    dbTrace(__LINE__, (caller(0))[3], "DWH: Using VM Config Directory: $vmcfgdir");
}


# Given a string compose and return a string that has the argument appended to
# the current config file sirectory name
sub getConfigDirFileName
{
    my $cfgFileName = "";

    if (defined($_[0]))
    {
        if (length($vmcfgdir) > 0)
        {
            $cfgFileName = $vmcfgdir."/";
        }
        $cfgFileName .= $_[0];
    }
    else
    {
        die "Attempt to create a config filename using the config directory but no file\n";
    }

    return $cfgFileName;
}


# Find the paths to the executables for the external programs to be used
sub findBinaries
{
	my $cmdz;
	my $binpath;

	foreach (@sudobinlist)
	{
        if ($_ ne "ifconfig")
        {
            vbTrace(__LINE__, (caller(0))[3], " Finding path for $_");
            
            # Make a temporary copy of the bin name
            $binpath = $_;

            # Special handling for ip, which has a /bin/ and a /sbin/ instance
            if ($binpath eq "ip")
            {
                $binpath = "/sbin/ip";
            }
            
            # Command line to see if an executable exists
            $cmdz = "sudo which $binpath 2>/dev/null";

            # Execute it and keep the stdio from it
            $binpath = qx/$cmdz/;
            vbMessage(" - qx completes with $binpath");
            
            # If there was output to stdio
            if ($binpath =~ m/(.*)/)
            {
                # It's the fully qualified path to the executable, use it
                $binpath = $1;
                vbMessage(" - modified to $binpath");
            }
            # If we have anything for the path to the executable
            if ($binpath ne "")
            {
                # Use it as the executable for this binary name
                $sudobins{$_} = $binpath;
                vbMessage(" - saved in sudobins hash as $sudobins{$_} with key $_");
            }
            # If which gave us nothing, use globally assumed fully
            # qualified paths
            else
            {
                if ($_ =~ m/"brctl"/)
                {
                    $binpath = $brctlbin;
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
                # Can this case ever occur, see if ($_ ne "ifconfig") above?
                elsif ($_ =~ m/"ifconfig"/)
                {
                    $binpath = $ifconfigbin;
                }
                else
                {
                    die("Failed to find $_ executable required for operation\n");
                }

                $sudobins{$_} = $binpath;
                vbMessage(" - saved constant $binpath in sudobins hash as $sudobins{$_} with key $_");
            }
        }
	}
}


# Get the netdev NIC number from a netdev=<n> string
# -1 is error
sub getNetdevNICnumber
{
    my $netdev;
    my $n;

    vbTrace(__LINE__, (caller(0))[3], " Getting netdev NIC number");

    if (defined($_[0]))
    {
        $netdev = $_[0];
        vbTrace(__LINE__, (caller(0))[3], " * from $netdev");
        if ($_ =~ /netdev=(\d)/i)
        {
            $n = $1;
        }
        else
        {
            $n = -1;
        }
    }
    else
    {
        $n = -1;
    }

    vbTrace(__LINE__, (caller(0))[3], " * Result is: $n");
    return $n;
}


# Given a NIC number, return a netdev=<n> string
# Return empty string on error
sub getNetdevFromNICnum
{
    my $netdev = "";
    my $n;

    vbTrace(__LINE__, (caller(0))[3], " Getting netdev from NIC number");

    if (defined($_[0]))
    {
        if ($_[0] =~ /(\d+)/)
        {
            vbTrace(__LINE__, (caller(0))[3], " * from $1");
            $n = 0 + $1;
            if ($n >= 0)
            {
                $netdev = "netdev=$1";
            }
        }
    }

    vbTrace(__LINE__, (caller(0))[3], " * Result is: $netdev");
    return $netdev;
}

# Get a netdev list item value for the netdev=<n> key in the first argument
# Return empty string on error
sub getNetdev
{
    my $ndkey;
    my $netdev;

    vbTrace(__LINE__, (caller(0))[3], " Get netdevs list item from key");

    if (defined($_[0]))
    {
        $ndkey = $_[0];
        vbTrace(__LINE__, (caller(0))[3], " * key is: $ndkey");
        $netdev = $netdevs{$ndkey};
        if (!defined($netdev))
        {
            vbTrace(__LINE__, (caller(0))[3], " * Nothing found in netdevs");
            $netdev = "";
        }
    }

    vbTrace(__LINE__, (caller(0))[3], " * Returning $netdev");
    return $netdev;
}


# Set a netdev list item value for the netdev=<n> key in the first argument
# to the value in the second argument
sub setNetdev
{
    my $ndkey;
    my $netdev;

    vbTrace(__LINE__, (caller(0))[3], " Set netdevs list item from key and value");

    if (defined($_[0]) && defined($_[1]))
    {
        $ndkey = $_[0];
        vbTrace(__LINE__, (caller(0))[3], " * key is:   $ndkey");
        $netdev = $_[1];
        vbTrace(__LINE__, (caller(0))[3], " * Value is: $netdev");
        $netdevs{$ndkey} = $netdev;
    }
}


# Get a macs list item value for the key in the first argument
# Return empty string on error
sub getMAC
{
    my $macKey;
    my $macVal;

    vbTrace(__LINE__, (caller(0))[3], " Get macs list item from key");

    if (defined($_[0]))
    {
        $macKey = $_[0];
        vbTrace(__LINE__, (caller(0))[3], " * key is: $macKey");
        $macVal = $macs{$macKey};
        if (!defined($macVal))
        {
            vbTrace(__LINE__, (caller(0))[3], " * Nothing found in macs");
            $macVal = "";
        }
    }

    vbTrace(__LINE__, (caller(0))[3], " * Returning $macVal");
    return $macVal;
}


# Set a macs list item value for the key in the first argument
# to the value in the second argument
sub setMAC
{
    my $macKey;
    my $macVal;

    vbTrace(__LINE__, (caller(0))[3], " Set MAC list item from key and value");

    if (defined($_[0]) && defined($_[1]))
    {
        $macKey = $_[0];
        vbTrace(__LINE__, (caller(0))[3], " * key is:   $macKey");
        $macVal = $_[1];
        vbTrace(__LINE__, (caller(0))[3], " * Value is: $macVal");
        $macs{$macKey} = $macVal;
    }
}


# Set a macs list item value for the key in the first argument
# to a randomly generated MAC address
sub setRandomMAC
{
    my $macAddr;
    my $macKey;
    my $replace;
    my $octet;

    vbTrace(__LINE__, (caller(0))[3], " Set MAC list item for key to a random value");

    if (defined($_[0]) && defined($_[1]))
    {
        $macKey = $_[0];
        $replace = 0 + $_[1];

        # Check if the entry already exists
        if ($macKey ne "")
        {
            $macAddr = getMAC($macKey);
            if (!$replace && ($macAddr ne ""))
            {
                return;
            }

            # Generate the new address
            $macAddr = @ouis[int(rand(1 + scalar @ouis))];
            for ($i = 0; $i < 3; $i++)
            {
                # Byte value between 2 and 254
                $octet = 2 + int(rand(252));
                $macAddr .= ":";
                $macAddr .= sprintf("%02x", $octet);
            }

            vbTrace(__LINE__, (caller(0))[3], " Generated MAC address: $macAddr");
            setMAC($macKey, $macAddr);
        }
    }
}

# Get the NIC device model for a netdev=<n> NIC, defaults to virtio (virtio-net-pci - 2018-04-27)
sub netdevNICtype
{
    my $netdev;
    my $model = "virtio";

    vbTrace(__LINE__, (caller(0))[3], " Getting netdev NIC type");

    if (!defined($_[0]))
    {
        vbTrace(__LINE__, (caller(0))[3], " - No argument provided, returning default");
        return $model;
    }

    $netdev = $netdevs{$_[0]};
    if ($netdev)
    {
        vbTrace(__LINE__, (caller(0))[3], " - Using netdev $netdev");
    }

    vbTrace(__LINE__, (caller(0))[3], " * Returning $model as netdev NIC type");
    return $model;
}


sub readStartDateFile
{
    my $sdfile;

    if (!defined($_[0]))
    {
        die "Attempt to read startdate file without providing a file\n";
    }
    $sdfile = $_[0];

    while (defined($sdfile) && ($startdate = <$sdfile>) && ($startdate =~ /^#(.*)/))
    {
    }
    vbMessage("Using start date from file: $startdate");

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
        vbMessage("Using now as start date: $startdate");
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

    vbMessage("Selected startdate: $sdt");
    $starttime = DateTime->now();
    vbMessage("Starting VM at $starttime");
}


sub writeStartDateFile
{
    my $sdfile;

    if (!defined($_[0]))
    {
        die "Attempt to write startdate file without providing a file\n";
    }
    $sdfile = $_[0];

    $vmelapsed = DateTime->now() - $starttime;
    vbMessage("VM Elapsed runtime: $vmelapsed");
    $vmelapsed->add(seconds => 15);
    vbMessage("VM padded runtime: $vmelapsed");

    $sdt->add($vmelapsed);
    vbMessage("Next start time: $sdt");

    $startdate = "$sdt";
    vbMessage("Next start time value: $startdate");

    vbMessage("Writing start date to file: $startdate");
    print $sdfile "$startdate";
}


sub doStartDateFileOp
{
    my $sdOp;
    my $sdfile;

    # There has to be one
    if ($startdatefile)
    {
        # ...and an operation r or w
        if (!defined($_[0]))
        {
            die "Attempt to use startdate file without specifying an operation (r/w)\n";
        }

        $sdOp = $_[0];
        if (!($sdOp =~ m/^[rw]$/i))
        {
            die "Unrecognized startdate operation $sdOp\n";
        }

        # For write there are some restrictions
        if ($sdOp =~ m/w/i)
        {
            if ($daemonize || !$snapshot)
            {
                print "Startdate file used along with don\'t update startdate file option\n";
                return;
            }

            open($sdfile, ">", $startdatefile);
            writeStartDateFile($sdfile);
        }
        else
        {
            open($sdfile, "<", $startdatefile);
            readStartDateFile($sdfile);
        }

        close($sdfile);
    }
}


#
# Verify the VGA Type is valid or impose a default
#
sub getVMGraphicsCard
{
    my $gCard;

	if ($vgatype eq "std")
	{
        $gCard = "std";
	}
	elsif ($vgatype eq "vmware")
	{
        $gCard = "vmware";
	}
	elsif ($vgatype eq "qxl")
	{
        $gCard = "qxl";
	}
	elsif ($vgatype eq "virtio")
	{
        $gCard = "virtio";
	}
	elsif ($vgatype eq "none")
	{
        $gCard = "none";
	}
	else
	{
        # The default
        $gCard = "cirrus";
	}

    vbMessage("getVMGraphicsCard returning: $gCard");

	return $gCard;
}


#
# Get a name for the VGA graphics card
#
sub getVMGraphicsCardName
{
    my $vgaName = "";

    $vgatype = getVMGraphicsCard();

	if ($vgatype eq "std")
	{
		$vgaName = "Standard VGA";
	}
	elsif ($vgatype eq "vmware")
	{
		$vgaName = "VMWare";
	}
	elsif ($vgatype eq "qxl")
	{
		$vgaName = "QXL";
	}
	elsif ($vgatype eq "virtio")
	{
		$vgaName = "virtio";
	}
	elsif ($vgatype eq "none")
	{
		$vgaName = "None";
	}
	elsif ($vgatype eq "cirrus")
	{
		print "Cirrus\n";
	}

    vbMessage("getVMGraphicsCardName returning: $vgaName");

	return $vgaName;
}


# Process a configuration definition
# This handles all cases and in nearly all cases the block for a given case
# contains a return and this is called one item at a time by a caller walking
# down the set of config items.
# Some cases are quite complicated
sub parseConfigItem
{
	my $chdev;
	my $vs;
	my $ln;
	my $netdev;
	my ($line) = @_;
	chomp($line);

    # Quick, do nothing exit for no arguments
	if ((!$line) || ($line eq ""))
	{
		return;
	}

	# The next part seems over-complicated but is required to handle the case
	# of sub-sections having a start item, [<sub-section name>] but no end of
	# sub-section declaration. The end of sub-section can be inferred in
	# the case of the start of a new sub-section (note they are not nested)

    # Start of a sub-section:
    # [<sub-section name>]
	if ($line =~ m/^\[(.*)\]/)
	{
		print "Sub-section found $1\n" if ($verbose);

		# If we are not looking for a sub-section we can return with a message
		if (!$subname)
		{
			print "No sub-section required\n" if ($verbose);

			$insub = 1;
			return;
		}

		# If we are looking for a sub-section and found it
		if ($subname eq $1)
		{
			print "Found requested sub-section\n" if ($verbose);

			$insub = 2;
			return;
		}
		# We are looking for a sub-section but found the wrong one
		else
		{
			print "Found sub-section other than that requested\n" if ($verbose);

			# If we are already in the correct one then it has ended
			if ($insub == 2)
			{
				$insub = 3;
			}
			# Otherwise we start a sub-section
			else
			{
				$insub = 1;
			}

			# ... and exit (until we reach another sub-section)
			return;
		}
	}

	# Ignore an unwanted sub-section line
	if (($insub == 1) || ($insub == 3))
	{
		print "Ignoring setting $line in not requested sub-section\n" if ($verbose);

		return;
	}

    # Process the sub-secton we wanted, $insub will be 2 or
    # not defined (the root section if you like)

	if ($line =~ /^#(.*)/)						# pyqt
	{
		print "Comment: $1\n" if ($verbose);
		return;
	}

    # Process as a setting line (adding a -- prefix if needed)
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

	# Generate a UUID
	if ($line =~ /--genuuid/i)
	{
		$genuuid = 1;
	}

	if ($line =~ /--hack/i)
	{
		$hack = 1;
	}

	# SCSI drive
	# --sdrive<bus>.<lun>=<file>[,option,option...]
	if ($line =~ /--sdrive(\d)\.(\d)=(.*)/i)
	{
		print "scsi drive on LUN $2 of bus $1 = $3\n" if ($verbose);
		$drives{"s/$1/$2"} = $3;
		return;
	}

	# Virtio drive
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

	# Work without networking
	if ($line =~ /--nonet/i)
	{
        print "no networking for guest\n" if ($verbose);
		$nonet = 1;
	}

    # Legacy NIC definition
	if ($line =~ /^--nic(\d)=(.*)/i)				# pyqt
	{
		print __LINE__, ": ", (caller(0))[3], " vlan $1 nic = $2\n" if ($verbose);
		$nics{"vlan=$1"} = $2;
		print __LINE__, ": ", (caller(0))[3], " netdev $1 nic = $2\n" if ($verbose);
		$netdev = getNetdevFromNICnum($1);
		if ($netdev)
		{
            $nics{$netdev} = $2;
        }
		return;
	}
	# Static MAC address for a NIC
	if ($line =~ /^--mac(\d)=(.*)/i)				# pyqt
	{
		print __LINE__, ": ", (caller(0))[3], " vlan $1 mac = $2\n" if ($verbose);
		setMAC("vlan=$1", $2);
		print __LINE__, ": ", (caller(0))[3], " netdev $1 = $2\n" if ($verbose);
		$netdev = getNetdevFromNICnum($1);
		setMAC($netdev, $2);
		return;
	}
	# Virtual LAN configuration
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
        $netdev = getNetdevFromNICnum($1);
        setNetdev($netdev, $2);
		
		# Remove any vlan nic
		delete $nics{$nmvNIC};
		
		# ... and any vlan MAC
		delete $macs{$nmvNIC};
		
		return;
	}

	# Declare a USB device
	if ($line =~ /^--usbdevice=(.*)/i)
	{
		print "USB device = $1\n" if ($verbose);
		if (!$usb)
		{
            print "Enabling USB interface" if ($verbose);
            $usb = 1;
		}
		$i = 0 + @usbdevices;
		$usbdevices[$i] = $1;
		return;
	}

    # Disable the USB controller
	if ($line =~ /^--nousb$/i)					# pyqt
	{
        die "Unable to disable guest USB controller due to pre-existing USB devices" if (@usbdevices > 0);

        print "Disable guest USB controller\n" if ($verbose);
		$usb = 0;
		return;
	}

	# Use a PS/2 keyboard interface
	if ($line =~ /^--nousbkbd$/i)
	{
		print "Don\'t use USB keyboard (use i8042 keyboard instead)\n" if ($verbose);
		$usbkbd = 0;
		return;
	}

	# Use a PS/2 mouse interface
	if ($line =~ /^--nousbmouse$/i)
	{
		print "Don\'t use USB mouse (use i8042 mouse instead)\n" if ($verbose);
		$usbmouse = 0;
		return;
	}

	# Change the mouse/keyboard grab method from Ctrl-Alt to Ctrl-Alt-Shift
	if ($line =~ /^--alt-grab$/i)
	{
        print "Use alternate grab keystroke (Ctrl-Alt-Shift)\n" if ($verbose);
        $altgrab = 1;
        return;
	}

	# Define a SCSI disk:
	# e.g.: --scsi0=<path to disk image>[,other arguments]
	if ($line =~/^--scsi(\d)=(.*)/i)
	{
		print "SCSI Drive $1 = $2\n" if ($verbose);
		$scsidrives{"$1"} = $2;
		return;
	}

#print "TRYING TO FIND OPTIONS in $line !!!!!!!!!!!!!!!!!!!\n";

    # Additional options, i.e. raw qemu command-line syntax
	if ($line =~ /^--options=(.*)/i)
	{
		print "Additional options = $1\n" if ($verbose);
		$options = $1;
		return;
	}

	# Guest name (used for display window)
	if ($line =~ /^--name=(.*)/i)					# pyqt
	{
		print "VM Name = $1\n" if ($verbose);
		$name = $1;
		return;
	}

	# GetOptionsFromString() can handle the rest by giving us the setting
	# value in a relevant variable
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

    # Do some verification or information output
    if ($ret)
	{
        # Handle some error cases
		die "You need at least one CPU\n" if ($cpus < 1);
		die "Memory size too small" if ($mem < 4);
		die "The QMP server setting must be a tcp port number\n" if (($ln eq 'qmpserver') && (($qmpserverport < 1) || ($qmpserverport > 65535)));

		# QMP server being used for disk, show the back-end server specified
		if ($ln =~ /qmpserver/i)
		{
			print "QMP Server set, line is $ln, port is $qmpserverport\n";
		}

		# Special way to turn on verbose and snapshot with one argument --verbosnap
		if ($vs) {
			print "Going verbose and snapshot\n" if ($debug);
			$verbose = 1;
			$snapshot = 1;
		}

		# Save any chardevs
		if ($chdev ne "") {
			push @chardevs,($chdev);
		}

		return;
	}

    # Something unhandled
	die "Unrecognized configuration item $line\n";
}


# If we used --vm=<config file> and have an expected config file then generate
# the complete path we expect for it
sub getConfigFileName
{
	my $cfgFileName = "";

	# If a VM name is set, add it to the config directory name
	if (length($vmname) > 0)
	{
		$cfgFileName = getConfigDirFileName($vmname);
	}

	return $cfgFileName;
}


# If there is a CPU setting, check the value is valid
sub CPUIsValid
{
	# Check if the value in the global CPU variable is supported
	if ($cpu ~~ @validCPUs)
	{
		return 1;
	}

	return 0;
}


sub writeVMConfigItem
{
    my $vmcfg;
    my $setting;
    my $value;

    if (!defined($0))
    {
        print "No file supplied to save configuration\'s item\n";
        return;
    }
    $vmcfg = $_[0];

    if (!defined($_[1]))
    {
        return;
    }
    $setting = $_[1];

    if (defined($_[2]))
    {
        $value = $_[2];
    }

    print $vmcfg "$setting";
    if (defined($value))
    {
        print $vmcfg "=$value";
    }
    print $vmcfg "\n";
}


sub generateVMDiskCommandLine
{
    my $diskID;
    my $fname;

    if (!defined($_[0]))
    {
        print "No device given for disk command-line\n";
        return;
    }
    $diskID = $_[0];

    if (!defined($_[1]))
    {
        die "No filename given for disk $diskID command-line\n";
    }
    $fname = $_[1];

    vbTrace(__LINE__, (caller(0))[3], " Generate command-line entries for a basic disk");

    dbTrace(__LINE__, (caller(0))[3], " Disk: $diskID is $fname");
    $cmdline .= " -";
    $cmdline .= "$diskID $fname";
}


sub dumpVMConfigItem
{
    my $setting;
    my $value;

    if (!defined($_[0]))
    {
        print "No setting given for dump VM config item\n";
        return;
    }
    $setting = $_[0];

    if (defined($_[1]))
    {
        $value = $_[1];
    }

    print __LINE__, ": ", (caller(0))[3], " Config setting: $setting";
    if (defined($value))
    {
        print "  = $value\n";
    }
    else
    {
        print " SET\n";
    }
}


#
# Given a key that's a device name (fda, hdb, etc) and a filename, prefix it
# with any VM prefix directory and add it to the basicDrives list
#
sub setVMDirDiskPath
{
    my $devID;
    my $fullPath;

    vbTrace(__LINE__, (caller(0))[3], " setVMDirDiskPath");

    if (defined($_[0]) && defined($_[1]))
    {
        $devID = $_[0];
        $fullPath = $vmdir.$_[1];
        $basicDrives{$devID} = $fullPath;
        dbTrace(__LINE__, (caller(0))[3], " VMDirDiskPath: $devID is $fullPath");
    }
}


#
# For each device of a given type do an operation on it
#
sub doVMDevOp
{
    my $opName;
    my $vmcfg;
    my $devID;
    my $valueSaved;
    my $devSet;
    my @theKeys;

    if (!defined($_[0]))
    {
        print "No operation specified for do VM FDD Operation\n";
        return;
    }
    $opName = $_[0];

    # Is the operation one we support
    if (!($opName ~~ @opsForBasicDrives))
    {
        print "Unrecognized operation $opName supplied for do VM FDD Operation\n";
        return;
    }

    # Get the device set
    if (!defined($_[1]))
    {
        print "No device set specified for do VM device Operation\n";
        return;
    }
    $devSet = $_[1];

    if ($devSet eq "FDD")
    {
        @theKeys = @fddKeys;
    }
    elsif ($devSet eq "HDD")
    {
        @theKeys = @hddKeys;
    }
    else
    {
        die "Unrecognized device set $devSet in do VMFDDOp\n";
    }

    # Get any config file
    if (defined($_[2]))
    {
        $vmcfg = $_[2];
    }

    foreach (@theKeys)
    {
        # Ignore non-existent or empty ones
        next if ((!defined($basicDrives{$_})) || ($basicDrives{$_} eq ""));
        print __LINE__, ": ", (caller(0))[3], " Device: $_ is ".$basicDrives{$_}."\n" if ($debug);

        $devID = $_;
        $valueSaved = $basicDrives{$devID};
        if ($opName eq "dump")
        {
            dumpVMConfigItem($devID, $valueSaved);
        }
        elsif ($opName eq "write")
        {
            writeVMConfigItem($vmcfg, $devID, $valueSaved);
        }
        elsif ($opName eq "genCmd")
        {
            generateVMDiskCommandLine($devID, $valueSaved);
        }
    }
}


sub createNewVM
{
	my $i;
	my $diskSize;

	print "Creating a new Virtual Machine\n" if ($verbose);

	# Set the config directory and config filename
	$vmcfgfile = getConfigFileName();

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
	writeVMConfigItem($vmcfg, "vga", $vgatype);
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
	doVMDevOp("write", "FDD", $vmcfg);
	if ($hack)
	{
		print $vmcfg "hack\n";
	}
	doVMDevOp("write", "HDD", $vmcfg);
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

    if ($nonet)
    {
		print $vmcfg "nonet\n";
    }
    else
    {
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
        # 2018/02/15 - Add support for a type= option to change NIC model from virtio
        #
        printf "Process the netdevs: createNewVM\n" if ($verbose);
        foreach (sort keys(%netdevs))
        {
            my $n;
            my $ifname;
            my $macaddr;
            my $netdev;

            if ($debug != 0)
            {
                printf "Generating netdev and associated NIC device $_ configuration\n";
            }

            $netdev = getNetdev($_);

            # If no netdev type was specified we should look in the vlan setting
            if (!$nics{$_})
            {
                # Syntax only allows for bridge name and nic type
                if ($netdev =~ /tapbridge=(.+)[\,].*$/i)
                {
                    $netdev = "tap,bridge=$1,ifname=gentap,script=no,downscript=no";
                    setNetdev($_, $netdev);
                }
                if ($netdev =~ /nic=(.+)/i)
                {
                    $nics{$_} = $1;
                }
            }

            # If no MAC address was specified or we are cloning a config then generate one
            $macaddr = getMAC($_);
            if (((!defined($macaddr)) || (!$macaddr) || ($macaddr eq "")) || ($createVM && ($vmsource ne "")))
            {
                setRandomMAC($_, 1);
            }

            # Write out the settings
            #  netdev number (default is zero)
            $n = getNetdevNICnumber($_);
            if ($n >= 0)
            {
                $macaddr = getMAC($_);
                if ($nics{$_})
                {
                    print $vmcfg "nic$n=$nics{$_}\n";
                }
                print $vmcfg "mac$n=$macaddr\n";
                print $vmcfg "netdev$n=$netdev\n";
            }
        }

        if ($net)
        {
            print $vmcfg "net=$net\n";
        }
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
    $vmcfgfile = getConfigFileName();

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
    my $wspace;

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
	$wspace = getVMGraphicsCardName();
	print "$wspace\n";
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
	doVMDevOp("dump", "FDD");
    doVMDevOp("dump", "HDD");
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

	if ($nonet)
	{
		print "GUEST WITH NO NETWORKING\n";
	}
	else
	{
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
            my $mac;
            my $netdev = getNetdev($_);

            print "NIC(netdev):  $_\n";
            if ($nics{$netdev})
            {
                print "              $nics{$netdev}\n";
            } else {
                print "              default NIC\n";
            }
            $mac = getMAC($netdev);
            if (defined($mac) && ($mac ne ""))
            {
                print "              $mac\n";
            }
        }

        if ($net)
        {
            print "Net (Extra):  $net\n";
        }
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
		# DWH: 04/25/2018 try to remove FD controller and other noise but have
		# a watchdog device
		$cmdline .= " -nodefaults -watchdog i6300esb -watchdog-action poweroff";
	}
	else
	{
        $cmdline = $qemubin;
        $cmdline .= " -nodefaults -watchdog i6300esb";
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
	$cmdline .= " -m size=$mem";
	$cmdline .= "M";
	$cmdline .= " -uuid $uuid" if ($uuid ne "");
#   2018/04/27
#	$cmdline .= " -localtime" if ($localtime);
    if ($localtime)
    {
        $cmdline .= " -rtc base=localtime";
    }
    else
    {
        $cmdline .= " -rtc base=utc";
    }

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
	doVMDevOp("genCmd", "FDD");

	# IDE Hard disks
	doVMDevOp("genCmd", "HDD");

	# CD-ROM
	if ($basicDrives{"cdrom"} || $rip)
	{
		$cmdline .= " -cdrom ";
		if ($rip)
		{
			$cmdline .= $ripcdrom;
		}
		else
		{
			$cmdline .= $basicDrives{"cdrom"};
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
	
	if ($nonet)
	{
        print __LINE__, ": ", (caller(0))[3], " Turn off guest networking\n" if ($verbose);
        $cmdline .= " -net none";
	}
	else
	{
        # NICs by vlan
        print __LINE__, ": ", (caller(0))[3], " Process the vlans\n" if ($verbose);
        foreach (sort keys(%vlans))
        {
            my $ifname;
            my $vlanport;
            my $copyvlan;
            my $mac;
            my $i;

    #		die "No NIC for $_\n" if (!$nics{$_});

            next if ($_ eq "");
            print __LINE__, ": ", (caller(0))[3], " Processing NIC for VLAN $_ value is $nics{$_}\n" if ($verbose);

            if ($nics{$_})
            {
                print __LINE__, ": ", (caller(0))[3], "\n" if ($verbose);
                $mac = getMAC($_);
                if ($nics{$_} =~ /^i82.*$/)
                {
                    print __LINE__, ": ", (caller(0))[3], "\n" if ($verbose);
                    $cmdline .= " -device $nics{$_},$_";
                    if (defined($mac) && ($mac ne ""))
                    {
                        $cmdline .= ",mac=$mac";
                    }
                }
                elsif ($nics{$_} =~ /^usb-net$/)
                {
                    print __LINE__, ": ", (caller(0))[3], "\n" if ($verbose);
                    $cmdline .= " -device $nics{$_},$_";
                    if (defined($mac) && ($mac ne ""))
                    {
                        $cmdline .= ",mac=$mac";
                    }
                }
                else
                {
                    print __LINE__, ": ", (caller(0))[3], "\n" if ($verbose);
                    $cmdline .= " -net nic,$_,model=$nics{$_}";
                    if (defined($mac) && ($mac ne ""))
                    {
                        $cmdline .= ",macaddr=$mac";
                    }
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
            my $netdevport = getNetdev($_);
            my $copynetdev;
            my $i;
            my $ifname;
            my $iftype;
            my $mac;
            my $devdef;

    #		die "No NIC for $_\n" if (!$nics{$_});
            print __LINE__, ": ", (caller(0))[3], " Processing NIC for netdev $_\n" if ($verbose);
            if ($nics{$_})
            {
                $iftype = $nics{$_};
            }
            else
            {
                $iftype = "";
            }

            $mac = getMAC($_);

            if (($netdevport =~ /,ifname=gentap/i) || ($netdevport =~ /,gentap/i ))
            {
                print __LINE__, ": ", (caller(0))[3], " Processing generate random tap interface and qemu net device IDs\n" if ($verbose);

                $ifname = (rand() * 10000) % 10000;
                $i = 0 + @taps;
                $taps[$i] = "kvmtap".sprintf("%d", $ifname);
                print __LINE__, ": ", (caller(0))[3], " * tap is:            $taps[$i]\n" if ($verbose);

                $idnum = (rand() * 10000) % 10000;
                $idname = "qdevid".sprintf("%d", $idnum);
                $netids{$i} = $idname;
                print __LINE__, ": ", (caller(0))[3], " * qemu device ID is: $idname\n" if ($verbose);

                # If we also have a NIC for this netdev
                if ($iftype)
                {
                    print __LINE__, ": ", (caller(0))[3], "  * netdev has a NIC model: $iftype\n" if ($verbose);
                }
            }
            else
            {
                if ($nics{$_})
                {
                    print __LINE__, ": ", (caller(0))[3], "\n" if ($verbose);
                    if ($nics{$_} =~ /^i82.*$/)
                    {
                        print __LINE__, ": ", (caller(0))[3], "\n" if ($verbose);
                        $cmdline .= " -device $nics{$_},netdev=qdeved$_";
                        if (defined($mac) && ($mac ne ""))
                        {
                            $cmdline .= ",mac=$mac";
                        }
                    }
                    elsif ($nics{$_} =~ /^usb-net$/)
                    {
                        print __LINE__, ": ", (caller(0))[3], "\n" if ($verbose);
                        $cmdline .= " -device $nics{$_},$_";
                        if (defined($mac) && ($mac ne ""))
                        {
                            $cmdline .= ",mac=$mac";
                        }
                    }
                    elsif ($nics{$_} =~ /^virtio$/)
                    {
                        print __LINE__, ": ", (caller(0))[3], "\n" if ($verbose);
                        $cmdline .= " -net nic";
                        if (defined($vlans{$_}) && ($vlans{$_} ne ""))
                        {
                            $cmdline .= ",$vlans{$_}";
                        }
                        if (defined($mac) && ($mac ne ""))
                        {
                            $cmdline .= ",mac=$mac";
                        }
                        if (defined($nics{$_}) && ($nics{$_} ne ""))
                        {
                            $cmdline .= ",model=$nics{$_}";
                        }
                    }
                    else
                    {
                        print __LINE__, ": ", (caller(0))[3], "\n" if ($verbose);
                        $cmdline .= " -device nic,$_,model=$nics{$_}";
                        if (defined($mac) && ($mac ne ""))
                        {
                            $cmdline .= ",macaddr=$mac";
                        }
                    }
                }
            }

            if ($netdevport =~ /^netdev(\d)$/i)
            {
                $copynetdev = getNetdevFromNICnum($1);
                print __LINE__, ": ", (caller(0))[3], "  * Using:\n    $copynetdev\n    to replace\n    $netdevport\n" if ($verbose);
                $netdevport = getNetdev($copynetdev);
                setNetdev($_, $netdevport);
            }

            if (($netdevport =~ /,ifname=gentap/i) || ($netdevport =~ /,gentap/i ))
            {
                print __LINE__, ": ", (caller(0))[3], " Inserting generated tap\n" if ($verbose);
                print __LINE__, ": ", (caller(0))[3], " * $netdevport\n" if ($verbose);
                $netdevport =~ s/,ifname=gentap/,id=$idname,ifname=$taps[$i]/i;
                $netdevport =~ s/,gentap/,id=$idname,ifname=$taps[$i]/i;
                print __LINE__, ": ", (caller(0))[3], " Becomes:\n" if ($verbose);
                print __LINE__, ": ", (caller(0))[3], " * $netdevport\n" if ($verbose);

                my $us = $_;

                print __LINE__, ": ", (caller(0))[3], " Bridge parsing $netdevport\n" if $verbose;

                if ($netdevport =~ /,bridge=(.*?),/i)
                {
                    $bridges{$taps[$i]} = $1;
                    $netdevport =~ s/,bridge=.*?,/,/i;
                    setNetdev($us, $netdevport);
                    print "  Found bridge $bridges{$taps[$i]}, modified netdev: $netdevport\n" if $verbose;
                }
            }

            $cmdline .= " -netdev $netdevport";

            # If there is an associated NIC type definition that's empty but there is a MAC address
            if ((!defined($iftype) || ($iftype eq "")) && (defined($mac) && ($mac ne "")))
            {
                # Use the default type (2018-04-27 - virtio-net-pci)
                $iftype = "virtio";
            }
            if ($iftype)
            {
                print __LINE__, ": ", (caller(0))[3], " Process device associated with netdev using $_\n" if ($verbose);
                print __LINE__, ": ", (caller(0))[3], " * Interface type:  $iftype\n" if ($verbose);
                print __LINE__, ": ", (caller(0))[3], " * QEMU device ID:  $idname\n" if ($verbose);
                $cmdline .= " -device $iftype,netdev=$idname";

                # And add any MAC address
                if (defined($mac) && ($mac ne ""))
                {
                    print __LINE__, ": ", (caller(0))[3], " * MAC address: $mac\n" if ($verbose);
                    $cmdline .= ",mac=$mac";
                }
            }
        }

        print __LINE__, ": ", (caller(0))[3], " Process the NICs\n" if ($verbose);
        foreach (keys(%nics))
        {
            my $mac;

            if (defined($vlans{$_}) && ($vlans{$_} ne ""))
            {
                $mac = getMAC($_);
                $cmdline .= " -net nic,$_,model=$nics{$_}";
                if (defined($mac) && ($mac ne ""))
                {
                    $cmdline .= ",macaddr=$mac";
                }
            }
        }

        if ($net)
        {
            $cmdline .= " -net $net";
        }
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

	doStartDateFileOp("r");

	if ($startdate)
	{
		$cmdline .= " -startdate $startdate";
	}

	if ($vgatype ne "")
	{
        $cmdline .= " -vga $vgatype";
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
		$cmdline .= " -accel kvm -enable-kvm";
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
	
	vbMessage("Command line = $cmdline\n");

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
	my $hdir;
	my $vmfile;
	my $vmfname;
	my @lt;
	my $yr;
	my $st;
	my @vms;

	# List the files in the generic base directory for VM configs
    $vmdir = $vmcfgdir;
    dbTrace(__LINE__, (caller(0))[3], "Listing VM Config Directory: $vmdir");
    opendir($hdir, $vmdir) || die "Failed to open VM Config Directory to list VMs: $vmdir";
    @vms = readdir($hdir);
    closedir($hdir);

	# Print the names
	foreach $vmfile (@vms)
	{
		if (! ($vmfile =~ '^\.') && ($vmfile ne '..') && ! ($vmfile =~ /~$/))
		{
            $vmfname = getConfigDirFileName($vmfile);
            $st = stat($vmfname);

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


#
# Setup a list of the supplied basic drives and filenames, using a prefix directory if supplied
#
sub generateVMDirDiskPaths
{
    my $fullPath;

    print __LINE__, ": ", (caller(0))[3], " generateVMDirDiskPaths\n" if ($verbose);

	# Ensure a non-empty vmdir ends in a slash
	if (defined($vmdir))
	{
        if ((length($vmdir) != 0) &&  !($vmdir =~ /\/$/))
        {
            $vmdir .= "/";
        }
	}
	else
	{
        # An empty vmdir assumes any disk file is fully qualified
        $vmdir = "";
	}

	print __LINE__, ": ", (caller(0))[3], " VM Dir is: $vmdir\n" if ($debug);

	# Insert the vmdir path before each disk path/filename
	setVMDirDiskPath("fda", $fda);
	setVMDirDiskPath("fdb", $fdb);
	setVMDirDiskPath("hda", $hda);
	setVMDirDiskPath("hdb", $hdb);
	setVMDirDiskPath("hdc", $hdc);
	setVMDirDiskPath("hdd", $hdd);
	setVMDirDiskPath("sda", $sda);
	setVMDirDiskPath("sdb", $sdb);
	setVMDirDiskPath("sdc", $sdc);
	setVMDirDiskPath("sdd", $sdd);
	setVMDirDiskPath("sdi", $sdi);
	setVMDirDiskPath("cdrom", $cdrom);
}


# Program entry point
print "\nKVM/QEMU Virtual Machine Launcher (version $ver)\n\n";

getGlobalOptions();
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

# BUG: This will over-ride the whole conditional above
$vmcfgfile = $vmname;

if (!$createVM)
{
    print __LINE__, ": Config filename supplied: $vmcfgfile\n" if ($debug);
	$configFound = 1;
	if (!open($vmcfg, "<", $vmcfgfile))
	{
		# Add the config name
        print __LINE__, ": Config filename is not fully qualified, trying with config dir\n" if ($debug);
		$vmcfgfile = getConfigDirFileName($vmname);
	
		# Try to open the constructed path
		if (!open($vmcfg, "<", $vmcfgfile))
		{
            print __LINE__, ": Named config file not found using config dir\n" if ($debug);
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

if ($createVM || $configFound)
{
    # Validate the graphics card or use the default
    $vgatype = getVMGraphicsCard();
}

if ($createVM)
{
	createNewVM();
	exit 0;
}

if ($configFound && $verbose)
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

generateVMDirDiskPaths();

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

	doStartDateFileOp("w");
}

print "\n\n";
