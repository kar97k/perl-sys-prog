#!/usr/bin/env perl

#скрипт - посчитать сколько осталось секунд до конца часа, дня, недели

use strict;
use warnings;

my ($second, $minute, $hour) = localtime(time);
my $day_of_week = ( localtime(time) )[6];
unless ( $day_of_week ) { $day_of_week = 7 }

my $seconds_before_hour = (60 - $minute) * 60 - $second;
my $seconds_before_day = (23 - $hour) * 3600 + $seconds_before_hour;
my $seconds_before_week = (7 - $day_of_week) * 86400 + $seconds_before_day;

my $result = sprintf ("Seconds before end of:\nhour: %s\nday: %s\nweek: %s\n", $seconds_before_hour, $seconds_before_day, $seconds_before_week);
print $result;
