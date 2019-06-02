#!/usr/bin/env perl

use 5.016;
use utf8;
use open qw(:utf8 :std);
use Getopt::Long;

use AnyEvent::Socket;
use AnyEvent::Handle;
use Time::HiRes qw(time);
use Time::Moment;
use POSIX 'strftime';
use VK qw (new request users_get);
use Socket ':all';
use JSON::XS;
use Encode 'decode_utf8';
use DDP;
use Enriche 'enriche';

our $JSON = JSON::XS->new->canonical->utf8;

my $port = 6000;
my $monitor_port = 5500;
my $type = "enricher";
my $monitor = "192.168.18.12:5500";

my $socket;
my ($mhost,$mport) = split ':', $monitor, 2;
# $mport //= 5500;
socket $socket, AF_INET, SOCK_DGRAM, IPPROTO_UDP or die "monitor socket failed: $!";
my $addr = gethostbyname($mhost);
my $sockaddr = sockaddr_in($mport, $addr);
connect($socket, $sockaddr) or die "Assign udp socket failed: $!";

sub notify_monitor {
	my ($event_id) = @_;
	# return unless $monitor;
	my $ret = send($socket, $JSON->encode({
		id => $event_id,
		port => $port,
		type => $type,
	}), 0);
	say "$ret sended, $!";
}

# @events -- events ready to send for subscribers
my @events;
my %connected_clients;

my $server = tcp_server '0.0.0.0', $port, sub {
	my ($fh,$host,$port) = @_;

	my $h = AnyEvent::Handle->new(
		fh => $fh,
		timeout => 60, # read timeout
	);

	# String for identification of client in logs
	state $client_seq;
	my $client = "$host:$port#".(++$client_seq);

	say "Client $client connected (".fileno($fh).")";

	my $finish = sub {
		my $reason = shift;
		# Unregister client
		delete $connected_clients{$client};

		say AE::now()." "."Client $client disconnected", ($reason ? ": $reason" : "");
		$h->destroy;
	};

	$h->on_error(sub {
		my ($h, $err, undef) = @_;
		$finish->($err);
	});

	# First, we'd expect one line with id of event to send from
	# Empty line means "Send me all" (i.e. id = 0)

	$h->push_read(line => sub {
		my (undef, $line) = @_;
		if ($line =~ /^(\d*)$/) {
			my $from = $1 || 0;
			say AE::now()." "."Client $client want events from $from";
			# $process->($1);

			# Callback will be called outsive with event data
			my $on_event = sub {
				UNIVERSAL::isa($h,'AnyEvent::Handle::destroyed') and return;
				my $event = shift;
				my $body = $JSON->encode($event)."\n";

				say AE::now()." "."Deliver to $client $event->{id} ($h)";
				# print "Deliver to $client: ".decode_utf8($body);
				$h->push_write($body);
			};

			# Resend old events to newly connected client

			for my $event (@events) {
				if ($event->{id} > $from) {
					$on_event->($event);
				}
			}

			# Register client's callback
			# Any event should be delivered to every client
			$connected_clients{$client} = $on_event;

			# Waiting for any other input
			# It will catch close of socket
			# Also disable timeout, allowing to be connected forever
			$h->timeout(0);
			$h->on_read(sub {
				# If there is some input, read it, and goodbye to client
				$_[0]->push_read(line => sub {
					$_[0]->push_write("Goodbye!\n");
					$finish->("by client input");
				})
			});
		}
		else {
			warn "Client $client sent malformed input: $line";
			$h->push_write("Malformed input\n");
			$finish->("Malformed input");
		}
	});

}, sub {
	shift;
	my ($host,$port) = @_;
	say "Started server on $host:$port";
	return 1024;
};


sub add_event {
	my $event = shift;
	push @events, $event;
	for my $client (keys %connected_clients) {
		$connected_clients{$client}->($event);
	}
	notify_monitor($event->{"id"});
}

my %connections;

sub connect_to {
	my ($ip, $port) = @_;

	my $peer = {
		ip => $ip,
		port => $port,
		id => $ip.':'.$port,
	};

	# Declare finish-callback to destroy handle
	my $finish = sub {
		my ($reason) = @_;
		my $h = delete $connections{$peer->{id}};

		say AE::now()." "."Connecion to ".$peer->{id}." closed", ($reason ? ": $reason" : "");
		$h->destroy;
	};

	tcp_connect $peer->{ip}, $peer->{port}, sub {
		my $fh = shift;
		unless ($fh) {
			my $err = "$!";
			say sprintf "Failed to connect to %s with '%s'", $peer->{id}, $err;
			return;
		}

		say sprintf "Connection established to %s", $peer->{id};

		my $h = AnyEvent::Handle->new(fh => $fh);

		# Error callback for any errors on socket
		$h->on_error(sub {
			my (undef, undef, $err) = @_;
			$finish->($err);
		});

		$connections{$peer->{id}} = $h;

		# Send from 0 id
		$h->push_write("0\n");


		$h->on_read(sub {
			my ($h, undef, $err) = @_;
			$h->push_read(line => sub {
				my (undef, $line) = @_;
				#say sprintf "[%s:%s] >>> %s", $peer->{ip}, $peer->{port}, $line;

				my $j;
				if (eval { $j = $JSON->decode($line) }) {
					Enriche::enriche($j, sub {
						my $json = shift;
						add_event($json);
					});
				} else {
					warn "Server ".$peer->{id}." returned malformed input: $line";
					$h->push_write("Malformed input\n");
					$finish->("Malformed input");
				}
			});
			# $finish->($err);
		});
	}, sub { 3 }; # tcp_connect
	return;
}

connect_to('192.168.18.12', 5501);

my $cv = AE::cv;

my $stop_watcher = AE::signal INT => sub {
	say "Stopping";
	$cv->send();
};

$cv->recv;

