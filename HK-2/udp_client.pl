# Monitor notifier
use strict;
use warnings;

use Socket ':all';
use JSON::XS;
use Encode 'decode_utf8';
use DDP;

our $JSON = JSON::XS->new->canonical->utf8;

my $port = 5003;
my $type = "enricher";
my $monitor = "192.168.18.12:5000";

my $socket;
if ($monitor) {
	my ($mhost,$mport) = split ':', $monitor, 2;
	$mport //= 5500;
	socket $socket, AF_INET, SOCK_DGRAM, IPPROTO_UDP or die "monitor socket failed: $!";
	my $addr = gethostbyname($mhost);
	my $sockaddr = sockaddr_in($mport, $addr);
	connect($socket, $sockaddr) or die "Assign udp socket failed: $!";
}

sub notify_monitor {
	my ($event_id) = @_;
	return unless $monitor;
	send($socket, $JSON->encode({
		id => $event_id,
		port => $port,
		type => $type,
	}), 0);
}
