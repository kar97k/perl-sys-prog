#!/usr/bin/env perl

use 5.016;
use utf8;
use open qw(:utf8 :std);
use AnyEvent::HTTP;
use DDP;
use EV;
use URI;
use Async::Chain;
use Getopt::Long;
use JSON::XS;
our $JSON = JSON::XS->new->utf8;
use AnyEvent::Socket;
use AnyEvent::Handle;
use HTTP::Easy::Headers;
use Mojo::UserAgent;
use Time::HiRes 'time';
use Encode 'decode_utf8';
my $access_token;
my $port = 5501;
my $disco;

GetOptions(
	'a|access_token=s' => \$access_token,
	'l|listen=i' => \$port,
	'd|disco=s' => \$disco,
) and $access_token or die "Usage:\n\t$0 -a access_token -l listenport -d ser.vice.dis.covery\n";

our @EVENTS;
our %WATCHERS;

sub start_server {
	tcp_server '0.0.0.0', $port, sub {
		my $fh = shift;
		my ($host,$port) = @_;
		my $clientid = fileno($fh);
		say "Client connected from $host:$port ($clientid)";
		my $h = AnyEvent::Handle->new(
			fh => $fh,
			timeout => 60,
		);
		my $client = "$host:$port#$clientid";
		my $finish = sub {
			say "Client $client disconnected";
			$h->destroy;
			delete $WATCHERS{0+$h};
		};
		$h->on_error($finish);
		my $process = sub {
			my $body = shift;
			# p $body;
			$body->{from}//=0;
			for my $event (@EVENTS) {
				if ($event->{id}>$body->{from}) {
					say "Resend to $client: ".decode_utf8 $JSON->encode($event);
					$h->push_write($JSON->encode($event)."\n");
				}
			}
			$WATCHERS{0+$h} = sub {
				my $event = shift;
				say "Deliver to $client: ".decode_utf8 $JSON->encode($event);
				$h->push_write($JSON->encode($event)."\n");
			};
			$h->timeout(undef);
			$h->on_read(sub {
				$h->push_read(line => sub {
					for ($_[1]) {
						if (/^(quit|exit)$/m) {
							$h->push_write("Goodbye!\n");
							$finish->();
						}
						else {
							$h->push_write("Unexpected input!\n");
							$finish->();
						}
					}
				});
			});
		};
		my $body;
		$h->push_read(line => sub {
			shift;
			for ($_[0]) {
				if (/^(\d+)$/) {
					$process->({from => $1});
				}
				elsif (/^\{/ and eval { $body = $JSON->decode($_) }) {
					$process->($body);
				}
				else {
					p @_;
					$h->push_write("Malformed input\n");
					$h->destroy;
				}
			}
		});
	}, sub {
		shift;
		my ($host,$port) = @_;
		say "Started server on $host:$port";
		return 1024;
	};
}

# start_server();
# use Time::HiRes 'time';
# my $w; $w = AE::timer 1,1, sub {
# 	my $id = int(time*1000);
# 	my $event = {id=>$id, event => "some event $id"};
# 	push @EVENTS, $event;
# 	shift @EVENTS while @EVENTS > 100;
# 	for (values %WATCHERS) {
# 		$_->($event);
# 	}
# };
# EV::loop; exit;

my $auth_uri = URI->new("https://api.vk.com/method/streaming.getServerUrl");
$auth_uri->query_form(access_token => $access_token, v => "5.64");
my $cv = AE::cv;
http_request
	GET => "$auth_uri",
	sub {
		if ($_[1]{Status} == 200) {
			my $j = $JSON->decode($_[0]);
			# p $j;
			$cv->send($j->{response}{endpoint}, $j->{response}{key});
		}
		else {
			warn "$_[1]{Status} $_[1]{Reason}\n";
			exit;
		}
	}
;
my ($endpoint, $key) = $cv->recv;


say "Got key $key for $endpoint";


# binmode STDOUT, ':utf8';

my $ua = Mojo::UserAgent->new();
$ua->websocket("wss://$endpoint/stream?key=$key", sub {
	my ($ua, $tx) = @_;
	unless ($tx->is_websocket) {
		say 'WebSocket handshake failed!';
		p $tx->res->body;
		exit;
	};
	say "Connected";

	start_server();

	$tx->on(
		message => sub {
			shift;
			my $raw = shift;
			utf8::encode $raw if utf8::is_utf8 $raw;
			my $data = $JSON->decode($raw);
			if ($data->{code} == 100) {
				my $event = $data->{event};
				my $my_event = { id => int(time*100), event => $event };
				push @EVENTS, $my_event;
				shift @EVENTS while @EVENTS > 100;
				for (values %WATCHERS) {
					$_->($my_event);
				}
				if ($event->{event_type} eq 'post') {
					if ($event->{action} eq 'new') {
						say "#$event->{event_id}{post_id} ($event->{event_url}) by $event->{author}{id} ".substr($event->{text},0,127);
						return;
					}
				}
				elsif ($event->{event_type} eq 'comment') {
					if ($event->{action} eq 'new') {
						say "#$event->{event_id}{comment_id}->$event->{event_id}{post_id} ($event->{event_url}) by $event->{author}{id} $event->{text}";
						return;
					}
				}
				elsif ($event->{event_type} eq 'share') {
					if ($event->{action} eq 'new') {
						say "#$event->{event_id}{post_id}:$event->{event_id}{shared_post_id} ($event->{event_url}) by $event->{author}{id} $event->{text}";
						return;
					}
				}
			}
			p $data;
		},
	);
});

# Mojo::IOLoop->start unless Mojo::IOLoop->is_running;
EV::loop;
