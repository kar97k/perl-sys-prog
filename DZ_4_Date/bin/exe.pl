#!/usr/bin/env perl

use strict;
use warnings;
use 5.016;

use FindBin;
use lib "$FindBin::Bin/../lib";
use Local::Date qw(date interval);
use Local::Date::Interval;

my $date = Local::Date->new({ 
    year    => 1968,
    month   => 11,
    day     => 16,
    hour    => 14,
    minute  => 21,
    second  => 43
});
say "new from hash: ", $date->datetime;

my $date_list = Local::Date->new(1972,1,2,3,4,5);
say "new from list: ", $date_list->datetime;

my $date_now = Local::Date->now();
say "new from now: ", $date_now->datetime;

my $date_epoch = Local::Date->from_epoch('1556102457');
say "new from epoch: ", $date_epoch->datetime;
say $date_epoch->strftime("%e %H:%M:%S %b %Y");

my $diff = Local::Date::Interval->diff($date, $date_list);
say "new diff: ", $diff->datetime;
