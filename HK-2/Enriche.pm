package Enriche;

use 5.016;
use DDP;
use VK qw (new request users_get groups_get);

my $API = VK->new(access_token=>"74c198fb74c198fb74c198fb75749e166a774c174c198fb2ecc459d39284f0741ddc759");
sub enriche {
	say "\n" x 2;
	my ($event, $cb) = @_;
	p $event;

	say "\n";
	my $author_id = $event->{data}->{author}->{id};
	say "\nid: \033[32m$author_id";
	say "\033[0m";

	$event->{data}{tags_info} = [];
	for my $tag (@{ $event->{data}{tags} }) {
		push @{ $event->{data}{tags_info} }, $API->{tags}{$tag};
	}

	if ($author_id > 0) {
		$API->users_get($author_id, sub {
			my $info = shift;
                        $info->[0]->{'name'} = $info->[0]->{'first_name'} . " " . $info->[0]->{'last_name'};
#			p $info;
			$event->{data}->{author}->{info} = $info->[0];
			$cb->($event);
		});
	} elsif ($author_id < 0) {
		$API->groups_get(-$author_id, sub {
			my $info = shift;
#			p $info;
			$event->{data}->{author}->{info} = $info->[0];
			$cb->($event);
		});
	} else {
		return undef;
	}

}

1;
