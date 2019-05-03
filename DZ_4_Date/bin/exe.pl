#!/usr/bin/env perl

use strict;
use warnings;
use 5.016;

use FindBin;
use lib "$FindBin::Bin/../lib";
use Local::Date qw(date interval);
use Local::Date::Interval;

=pod
my $date = Local::Date->new({ 
    year    => 1968,
    month   => 11,
    day     => 16,
    hour    => 14,
    minute  => 21,
    second  => 43
});
say $date->datetime;
say $date->year;

my $date_list = Local::Date->new(1972,1,2,3,4,5);
say $date_list->year; #("3456");

my $date_now = Local::Date->now();
say $date_now->month;

my $date_epoch = Local::Date->from_epoch('-62167402800');
$date_epoch->datetime;
=cut


#say $date_epoch->strftime("%e %H:%M:%S %b %Y");

#check if input zero

my $date      = Local::Date->new(2008,11,16,14,21,42);
say $date;

say $date->datetime;
my $date_list = date(2006,11,16,14,21,47);
say $date_list->datetime;
#$date_list->add_minutes(136);
#say $date_list->datetime;

my $diff = Local::Date::Interval->diff($date, $date_list);
say $diff->datetime;
say $diff->year;
say $diff->month;
say $diff->to_string;

$date->add_years(-2);
say $date->datetime;

say "----------------";
$date->add_years(2);
#test: - $date_list;
say $date->datetime;
say $date_list->datetime;
say my $doff = $date - $date_list;

say "----------------";

say $date_list;

say interval($date, $date_list);

