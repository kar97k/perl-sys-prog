package Local::Date::Interval;
use feature 'say';
use base Local::Date;
use POSIX qw(mktime);

use strict;
use warnings;

sub new {
    my $class = shift;
    my ($arg, $m, $d, $H, $M, $S) = @_;
    #can't access method mk_accessor until $class isn't obj ref;
    my $self = bless {}, $class;
    #can't access other values when get argument. For example can't check month if got day 31.
    #can't check sign of argument, for example drop if want to create -1 hour +15 minutes -3 seconds.
    $self->mk_accessors( { 
        year    => qr/^-?\d+$/ ,
        #in interval 12 months is 1 year;
        month   => [-11..11] ,
        day     => [-31..31] ,
        hour    => [-23..23] ,
        minute  => [-59..59] ,
        second  => [-59..59] ,
        sign    => qr/^[+\-]$/
    } );
    $self->mk_aliases( sec => 'second', min => 'minute' );
    if ( ref $arg ) {
        no warnings 'uninitialized';
        return undef if ref $arg ne 'HASH';
        $self->year(0+$arg->{'year'});
        $self->month(0+$arg->{'month'});
        $self->day(0+$arg->{'day'});
        $self->hour(0+$arg->{'hour'});
        $self->minute(0+$arg->{'minute'});
        $self->second(0+$arg->{'second'});
    }
    elsif (defined $arg) {
        no warnings 'uninitialized';
        $self->year(0+$arg);
        $self->month(0+$m);
        $self->day(0+$d);
        $self->hour(0+$H);
        $self->minute(0+$M);
        $self->second(0+$S);
    }
    else { $self = bless {}, $class; }
    #set sign of interval with first sign of first non zero accessor;
    my @atr = qw(year month day hour minute second);
    for (@atr) {
        if ($self->$_ != 0) { my $sign = $self->$_ >= 0 ? '+' : '-'; $self->sign($sign); last; }
    }
    return $self;
}

sub diff {
    #date2 - date1; if date1 = 2017, date2 = 2019, diff = 2
    #if date1 = 2013, date2 = 2009, diff = -4
    #В результате получится объект, содержащий год, месяц, день и т.д. Если последовательно к первой дате прибавлять по порядку: год, месяц, день и т.д. из этого объекта, получится вторая дата.
    shift;
    my $date1 = shift;
    my $date2 = shift;
    my $epoch_date1 = POSIX::mktime($date1->second, $date1->minute, $date1->hour, $date1->day, $date1->month - 1, $date1->year - 1900);
    my $epoch_date2 = POSIX::mktime($date2->second, $date2->minute, $date2->hour, $date2->day, $date2->month - 1, $date2->year - 1900);
    my $diff;
    my $diff_second = 0;
    if ($epoch_date2 > $epoch_date1) { 
        $diff_second = $epoch_date2 - $epoch_date1; 
        $diff = 1;
    } else { 
        $diff_second = $epoch_date1 - $epoch_date2; 
        $diff = -1;
    }
    my $days = int ( $diff_second / 86400 );
    my $seconds = $diff_second % 86400;
    my $result_hour = int ( $seconds / 3600 );
    $seconds = $diff_second % 3600;
    my $result_minute = int ( $seconds / 60 );
    my $result_second = $seconds % 60;
    #process date overflow 
    my $curr_year = $date1->year;
    my $curr_month = $date1->month;
    my $curr_day = $date1->day;
    my $result_year = 0;
    my $result_month = 0;
    my $result_day = 0;
    while ( $days > $Local::Date::month_date{$curr_month} ) { 
        #real date
        if ( $curr_month == 12 ) { $days -= 31; $curr_month = 1; $curr_year += 1; }
        elsif ( $curr_month == 2 and $curr_year % 4 == 0 ) { $days -= 29; $curr_month++; }
        else { $days -= $Local::Date::month_date{$curr_month}; $curr_month++; }
        #result date which is difference...
        if ( $result_month == 11 ) { $result_month = 0; $result_year += 1; }
        else { $result_month++; }
    }
    $result_day = $days;
    if ($diff > 0) {
        $diff = Local::Date::Interval->new($result_year, $result_month, $result_day, $result_hour, $result_minute, $result_second, '+'); 
    } else { $diff = Local::Date::Interval->new(-$result_year, -$result_month, -$result_day, -$result_hour, -$result_minute, -$result_second, '-'); }
    return $diff;
}

sub to_string {
    my $self = shift;
    my $res_str = "";
    my @atr = qw(year month day hour minute second);
    for (@atr) { 
        $res_str .= $self->$_ != 0 ? $self->$_ . " $_, " : "";
    }
    if ( $res_str eq "" ) { $res_str = "zero" }
    #cut comma in the end of string
    else { $res_str = substr $res_str, 0, -2; }
    if ($self->sign eq '+') { $res_str = '+'.$res_str }
    return $res_str;
}

1;
