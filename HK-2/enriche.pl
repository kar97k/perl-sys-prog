#!/usr/bin/env perl

use 5.016;
use utf8;
use DDP;
use JSON::XS;
our $JSON = JSON::XS->new->canonical->utf8;

use AnyEvent::Socket;
use AnyEvent::Handle;

use VK qw (new request users_get);

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

#		say AE::now()." "."Connecion to ".$peer->{id}." closed", ($reason ? ": $reason" : "");
		$h->destroy;
	};

	tcp_connect $peer->{ip}, $peer->{port}, sub {
		my $fh = shift;
		unless ($fh) {
			my $err = "$!";
#			say sprintf "Failed to connect to %s with '%s'", $peer->{id}, $err;
			return;
		}

#		say sprintf "Connection established to %s", $peer->{id};

		my $h = AnyEvent::Handle->new(fh => $fh);

		# Error callback for any errors on socket
		$h->on_error(sub {
			my (undef, undef, $err) = @_;
			$finish->($err);
		});

		$connections{$peer->{id}} = $h;

		# Send from 0 id
		$h->push_write("0\n");

		my $read;
		$read = sub {
			$h->push_read(line => sub {
				my (undef, $line) = @_;
#				say sprintf "[%s:%s] >>> %s", $peer->{ip}, $peer->{port}, $line;
#				say $line;

				my $j;
				if (eval { $j = $JSON->decode($line) }) {
					enriche($j, sub {
						say "\n~~~Continue work~~~\n";
					});
				} else {
					warn "Server ".$peer->{id}." returned malformed input: $line";
					$h->push_write("Malformed input\n");
					$finish->("Malformed input");
				}
				$read->();
			});
		};
		$read->();

	}, sub { 3 }; # tcp_connect

	return;
}

connect_to('192.168.18.12', 5501);

my $cv = AE::cv;

my $stop_watcher = AE::signal INT => sub {
	say "Stopping";
	$cv->send();
};

sub enriche {
	say "\n" x 2;
	my ($event, $cb) = @_;
	p $event;

	say "\n";
	my $author_id = $event->{data}->{author}->{id};
	say "\nid: \033[32m$author_id";
	say "\033[0m";


	my $API = VK->new(access_token=>"74c198fb74c198fb74c198fb75749e166a774c174c198fb2ecc459d39284f0741ddc759");
	if ($author_id > 0) {
		$API->users_get($author_id, sub {
			my $info = shift;
			p $info;
			$event->{data}->{author}->{info} = $info;
			$cb->($event);
		});
	} elsif ($author_id < 0) {
		$API->groups_get(-$author_id, sub {
			my $info = shift;
			p $info;
			$event->{data}->{author}->{info} = $info;
			$cb->($event);
		});
	} else {
		return undef;
	}

}

$cv->recv;
