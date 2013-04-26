#!/usr/bin/perl
#
# Listen on a local port and execute local commands
#
# Borrowed in part from: http://www.thegeekstuff.com/2010/07/perl-tcp-udp-socket-programming/
#
use IO::Handle;
use IO::Select;
use IO::Socket::INET;
use IPC::Open2;
use MIME::Base64;
use File::Temp qw/ tempfile /;
use strict;

# flush after every write
$| = 1;

my ($socket,$client_socket);
my $svrhost = "localhost";
my $svrport = 64333;
my ($peeraddress,$peerport);
my (%tmpfile);

my @sshparam = @ARGV;

$SIG{'CHLD'} = 'IGNORE';

my $pid = fork();
die "Urp: $?\n" if not defined $pid;
if ($pid != 0) {
	my $sleep_delay = 3;
	print "Tunneling into @sshparam in $sleep_delay...\n\r";
	my @args = ("ssh", "-R", "$svrport:localhost:$svrport", @sshparam);
	sleep($sleep_delay); # HACK way to let the child start first...
	system(@args);
	print "\n\rwaiting for local server: use Ctrl-C...\n\r";
	waitpid($pid,0);
	exit;
}

# creating object interface of IO::Socket::INET modules which internally does
# socket creation, binding and listening at the specified port address.
$socket = new IO::Socket::INET (
	LocalHost => $svrhost,
	LocalPort => $svrport,
	Proto => 'tcp',
	Listen => 1,
	Reuse => 1) or die "ERROR in Socket Creation : $!\n\r";

print "Columbia Command Server: listening on $svrport\n\r";
#$| = 1; # autoflush (unbuffered I/O)

while(1)
{
	# waiting for new client connection.
	$client_socket = $socket->accept();
	#binmode $client_socket;
	$client_socket->autoflush(1);

	# get the host and port number of newly connected client.
	#$peer_address = $client_socket->peerhost();
	#$peer_port = $client_socket->peerport();
	#print "New Client Connection From : $peeraddress, $peerport\n";

	my $cmdfilename = "/tmp/poser-remote-cmd.sh";
	my $cmdFD;
	my $rcvfile;
	my $rcvfd;
	my $rcvdata;
	my $mode = 0;
read_again:
	while (<$client_socket>) {
		if ($mode == 2) { # Receive a file
			if (/(.*)___END_FILE___/) {
				$rcvdata .= $1;
				$rcvdata =~ s/begin-base64 .*\n//;
				$rcvdata =~ s/\n====\n//;
				print $rcvfd decode_base64($rcvdata);
				close $rcvfd;
				print "\tSuccessfully received $rcvfile!\n\r";
				last;
			} else {
				$rcvdata .= $_;
			}
		} elsif ($mode == 1) { # Receiving a command
			if (/___END_COMMAND___/) {
				close $cmdFD;
				#print "\treceive done: breaking\n\r";
				last;
			} else {
				my $line = $_;
				foreach my $nm (keys %tmpfile) {
					$line =~ s/$nm/$tmpfile{$nm}/g;
				}
				print $cmdFD $line;
			}
		} else { # Waiting for a command
			if (/START_COMMAND/) { 
				$mode = 1;
				#print "\tReceiving script...\n\r";
				open($cmdFD, ">", "$cmdfilename") or die "why can't I open '$cmdfilename'? $!";
			} elsif (/RECEIVE_FILE#([^#]*)#/) {
				$mode = 2;
				$rcvfile = $1;
				($rcvfd, $tmpfile{$rcvfile}) = tempfile();
				#print "\tReceiving $1 into ".$tmpfile{$rcvfile}."\n\r";
			} else {
				print "Unknown command.\n\r";
				$mode = -1;
				last;
			}
		}
	}

	if ($mode == 1) {
		#print "\tExecuting script...\n\r";
		my $sel = IO::Select->new();
		open2(*CMDOUT, *CMDIN, "bash $cmdfilename") or die "can't open output from command? $!";
		select((select(CMDOUT), $| = 1)[0]);
		select((select($client_socket), $| = 1)[0]);
		$sel->add(\*CMDOUT);
		$sel->add($client_socket);
		while (my @ready = $sel->can_read) {
			my ($fh, $buf);
			my $retry = 0;
			foreach $fh (@ready) {
				$buf = <$fh>;
				if ($fh == \*CMDOUT) {
					print $client_socket $buf;
					$client_socket->flush();
					$retry = 1;
				} else {
					print CMDIN $buf;
					print $client_socket $buf; # local echo :-)
					$client_socket->flush();
					$retry = 1;
				}
				if (($fh && eof $fh) || !$buf) { $retry = 0; }
			}
			next if $retry;
			if (($fh && eof $fh) || !$buf) { last; }
		}
	}
	print $client_socket "__ENDOUTPUT__\n\r";
	$client_socket->flush();
	$client_socket->close();
}

$socket->close();

# cleanup
foreach my $nm (keys %tmpfile) {
	unlink $tmpfile{$nm};
}

### Handle the PIPE
$SIG{PIPE} = sub {
	# If we receieved SIGPIPE signal then call
	# Disconnect this client function
	print "Received SIGPIPE , removing a client..\n\r";
	unless(defined $client_socket) {
		print "No clients to remove!\n\r";
	} else {
		$IO::Socket::INET::Select->remove($client_socket);
		$client_socket->close;
	}
	#print Dumper $Self->Select->handles;
	#print "Total connected clients =>".(($Select->count)-1)."<\n";
};

