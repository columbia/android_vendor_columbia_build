#!/usr/bin/perl
#tcpclient.pl

use IO::Handle;
use IO::Select;
use IO::Socket::INET;
use MIME::Base64;
use strict;

my ($socket,$client_socket);
my $svrhost = "localhost";
my $svrport = 64333;

die "need command file, and output file" if (($#ARGV+1) < 2);

my $cmddata;
{
	open (CMDFILE, '<', $ARGV[0]) or die $!;
	my $tmp_RS = $/;
	$/ = undef;
	binmode CMDFILE;
	$cmddata = <CMDFILE>;
	$/ = $tmp_RS;
}

# creating object interface of IO::Socket::INET modules which internally creates
# socket, binds and connects to the TCP server running on the specific port.
$socket = new IO::Socket::INET (
	PeerHost => $svrhost,
	PeerPort => $svrport,
	Proto => 'tcp') or die "ERROR in Socket Creation : $!\n";

#print "Connected to Columbia Command Server...\n";
print $socket "$cmddata\n\r";
$socket->flush();

my $local_echo = undef;
if ($ARGV[2] =~ /^echo$/) {
	print "\033[0;32m[interactive remote cmd]\033[0m\n\r";
	$local_echo = 1;
} else {
	$local_echo = 0;
}

select((select($socket), $| = 1)[0]);

my $sel = IO::Select->new();
#$sel->add(\*STDIN);
$sel->add($socket);
open (OUTFILE, '>', $ARGV[1]) or die $!;
while (my @ready =$sel->can_read) {
	my ($fh, $buf);
	my $retry = 0;
	foreach $fh (@ready) {
		$buf = <$fh>;
		if ($fh == \*STDIN) {
			print $socket $buf;
			$socket->flush();
			$retry = 1;
		} else {
			if ($buf =~ /(.*)__ENDOUTPUT__.*/) {
				$buf = $1;
				$retry = 0;
			} else { $retry = 1; }
			print OUTFILE $buf;
			print $buf if $local_echo;
		}
		if (($fh && eof $fh) || !$buf) { $retry = 0; last; }
	}
	next if $retry;
	if (($fh && eof $fh) || !$buf) { last; }
}
close OUTFILE;

$socket->close();
