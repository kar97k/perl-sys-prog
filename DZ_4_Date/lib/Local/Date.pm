package Local::Date;
use feature qw(say switch);
use base Object::Accessor;
use POSIX qw(strftime);

use strict;
use warnings;

use overload 
    '-'      => 'sub_date',
    '""'     => 'say_date',
    fallback => 1;

sub import {
    my $name = shift; # my name
    my $caller = caller(); # who calls me
    my @args = @_;
    no strict 'refs';
    for my $fun (@args) {
        *{ $caller . '::' . $fun } = \&{ $fun }; # my local sub
    }
}

sub new {
    my $class = shift;
    my ($arg, $m, $d, $H, $M, $S) = @_;
    #can't access method mk_accessor until $class isn't obj ref;
    my $self = bless {}, $class;
    #can't access other values when get argument. For example can't check month if got day 31.  
    $self->mk_accessors( { 
        year    => qr/^\d+$/ ,
        month   => [1..12] ,
        day     => [1..31] ,
        hour    => [0..23] ,
        minute  => [0..59] ,
        second  => [0..59] 
    } );
    $self->mk_aliases( sec => 'second', min => 'minute' );
    if ( ref $arg ) {
        return undef if ref $arg ne 'HASH';
        $self->year($arg->{'year'});
        $self->month($arg->{'month'});
        $self->day($arg->{'day'});
        $self->hour($arg->{'hour'});
        $self->minute($arg->{'minute'});
        $self->second($arg->{'second'});
    }
    elsif (defined $arg) {
        $self->year($arg);
        $self->month($m);
        $self->day($d);
        $self->hour($H);
        $self->minute($M);
        $self->second($S);
    }
    else { $self = bless {}, $class; }
    return $self;
}

sub now {
    my $self = shift;
    my ($S, $M, $H, $d) = localtime(time);
    my $m = (localtime(time))[4] + 1;
    my $y = (localtime(time))[5] + 1900;
    return $self = new($self, $y, $m, $d, $H, $M, $S);
}

sub from_epoch {
    my $self = shift;
    my $time = shift;
    my ($S, $M, $H, $d) = localtime($time);
    my $m = (localtime($time))[4] + 1;
    my $y = (localtime($time))[5] + 1900;
    return $self = new($self, $y, $m, $d, $H, $M, $S);
}

sub strftime {
    my $self = shift;
    my $string_format = shift;
    #infinite loop when call strftime without prefix POSIX:: in "strftime $string_format, localtime(1555759641)"
    #error when call strftime without prefix POSIX:: "Can't call method "second" without a package or object reference"
    return POSIX::strftime $string_format, $self->second, $self->minute, $self->hour, $self->day, $self->month - 1, $self->year - 1900;
}

sub datetime {
    my $self = shift;
    #infinite loop when call strftime without prefix POSIX:: 
    return POSIX::strftime "%Y-%m-%dT%H:%M:%S", $self->second, $self->minute, $self->hour, $self->day, $self->month - 1, $self->year - 1900;
}

our %month_date = (
    1   =>  31,
    2   =>  28,
    3   =>  31,
    4   =>  30,
    5   =>  31,
    6   =>  30,
    7   =>  31,
    8   =>  31,
    9   =>  30,
    10  =>  31,
    11  =>  30,
    12  =>  31
);

sub add_years {
    my $self = shift;
    my $arg = shift;
    return undef if $arg !~ m/^-?\d+$/;
    $self->year($self->year + $arg);
    return 1;
}

sub add_months {
    my $self = shift;
    my $months = shift;
    return undef if $months !~ m/^-?\d+$/;
    if ($months > 12 or $months < -12) {
        my $years = int $months / 12;
        $months = $months % 12;
        $self->year($self->year + $years);
    }
    if ( $months > 0 and $self->month + $months > 12 ) {
        $self->year($self->year + 1);
        #will substract this walue in future
        $months = $months - 12;
    }
    elsif ( $months < 0 and $self->month - $months < 1 ) {
        $self->year = $self->year - 1;
        $months = 12 - $months;
    }
    my $new_month = $self->month + $months;
    if ( $self->year % 4 and $new_month == 2 and $self->day == 29 ) { say join " ", "Illegal value. There is no 29 february in",  $self->year, "year"; }
    elsif ( $self->day > $month_date{$new_month} ) { say join " ", "Illegal value. There is no", $self->day, "day in",  $new_month, "month"; }
    else { $self->month($new_month); }
    return 1;
}

sub add_weeks {
    my $self = shift;
    my $weeks = shift;
    return undef if $weeks !~ m/^-?\d+$/;
    my $days = int $weeks * 7;
    $self->add_days($days);
    return 1;
}

sub add_days {
    my $self = shift;
    my $days = shift;
    return undef if $days !~ m/^-?\d+$/;
    if ($days > 0) { $self->add_days_positive($days);}
    elsif ($days < 0) {$self->add_days_negative($days);}
    return 1;
}

sub add_days_positive {
    my $self = shift;
    my $days = shift;
    #not necessary process years
    my $curr_year = $self->year;
    if ( $days > 365 ) {
        if ($self->day == 29 and $self->month == 2) {
            #can get in 29.02 only if incremented exactly 4,8,12, etc years, it is 365*3 + 366 days;
            if ($days % 1461 == 0) { $curr_year += 4*(int $days / 1461); $days = 0; }
            #add 365 days to 29.02 and get into 28.02. Process it as a regular day with while below
            else { $curr_year += 1; $days-=365; $self->day = 28 }
        }
        while ($days > 365) {
            $days -= 365;
            $curr_year += 1;
            #pass through 29.02 in leap year
            #from 3.3.2015 to 3.3.2016 366 days have passed
            if ($curr_year % 4 == 0 and $self->month > 2) { $days -= 1; }
            #from 17.1.2016 to 17.1.2017 366 days have passed
            elsif ($curr_year % 4 == 1 and $self->month <= 2) { $days -= 1; }
        }
    }
    #months
    my $curr_month = $self->month;
    while ( $days > $month_date{$curr_month} ) {
        if ( $curr_month == 12 ) { $days -= 31; $curr_month = 1; $curr_year += 1; }
        elsif ( $curr_month == 2 and $curr_year % 4 == 0 ) { $days -= 29; $curr_month++; }
        else { $days -= $month_date{$curr_month}; $curr_month++; }
    }
    #days
    my $new_day = $self->day + $days;
    if ( $new_day > $month_date{$curr_month} ) {    
        if ( $curr_month == 12 ) { $new_day -= 31; $curr_month = 1; $curr_year += 1; }
        elsif ( $curr_month == 2 and $curr_year % 4 == 0 ) { $new_day = ($new_day == 29) ? 29 : $new_day - 29 ; $curr_month++; }
        else { $new_day -= $month_date{$curr_month}; $curr_month++; }
    }
    $self->year($curr_year);
    $self->month($curr_month);
    $self->day($new_day);
    return 1;
}

sub add_days_negative {
    my $self = shift;
    my $days = shift;
    #months
    my $curr_month = $self->month;
    while ( $days < -$month_date{$curr_month} ) {
        if ( $curr_month == 1 ) { $days += 31; $curr_month = 12; $self->year( $self->year - 1 ); }
        elsif ( $curr_month == 3 and $self->year % 4 == 0 ) { $days += 29; $curr_month--; }
        else { $days += $month_date{$curr_month}; $curr_month--; }
    }
    #days
    my $new_day = $self->day + $days;
    if ( $new_day < 1 ) {    
        if ( $curr_month == 1 ) { $new_day += 31; $curr_month = 12; $self->year( $self->year - 1 ); }
        elsif ( $curr_month == 3 and $self->year % 4 == 0 ) { $new_day += 29; $curr_month--; }
        else { $new_day += $month_date{$curr_month}; $curr_month--; }
    }
    $self->month($curr_month);
    $self->day($new_day);
    return 1;    
}

sub add_hours {
    my $self = shift;
    my $hours = shift;
    return undef if $hours !~ m/^-?\d+$/;
    if ($hours > 23) {
        my $days = int $hours / 24;
        $self->add_days($days);
        $hours = $hours % 24;
    }
    $hours = $self->hour + $hours;
    if ($hours > 23) { 
        $self->add_days(1);
        $hours = $hours % 24;
    }
    $self->hour($hours);
    return 1;
}

sub add_minutes {
    my $self = shift;
    my $minutes = shift;
    return undef if $minutes !~ m/^-?\d+$/;
    if ($minutes > 59) {
        my $hours = int $minutes / 60;
        $self->add_hours($hours);
        $minutes = $minutes % 60;
    }
    $minutes = $self->minute + $minutes;
    if ($minutes > 59) {
        $self->add_hours(1);
        $minutes = $minutes % 60;
    }
    $self->minute($minutes);
    return 1;
}

#"overload arg 'say' is invalid"
sub say_date {
    my $self = shift;
    #infinite loop when call strftime without prefix POSIX:: 
    return POSIX::strftime "%Y-%m-%dT%H:%M:%S", $self->second, $self->minute, $self->hour, $self->day, $self->month - 1, $self->year - 1900;
}

sub sub_date {
    my $date_one = shift;
    my $date_two = shift;
    #reverse order of arguments
    my $diff = Local::Date::Interval->diff($date_two, $date_one);
    $diff = $diff->to_string;
    return $diff;
}

sub date {
    return new('Local::Date', @_);
}

sub interval {
    my $date_one = shift;
    my $date_two = shift;
    #reverse order of arguments
    my $diff = Local::Date::Interval->diff($date_two, $date_one);
    return $diff->to_string;
}

1;
