#!/usr/bin/env perl

use strict;
use warnings;
use 5.016;

use Test::More tests => 18;

use FindBin;
use lib "$FindBin::Bin/../lib";

use experimental qw( switch );

subtest 'Initialize objects' => sub {

require_ok('Local::Date');

my $obj = Local::Date->new(2008,11,16,14,21,42);

isa_ok($obj, 'Local::Date');
new_ok('Local::Date' => [2008,11,16,14,21,42] );
can_ok($obj, 'new');

my @methods = qw(min sec now from_epoch strftime datetime);
for (@methods) {
    can_ok($obj, $_);
}

require_ok('Local::Date::Interval');

my $date1 = Local::Date->new(2008,11,16,14,21,42);
my $date2 = Local::Date->new(2008,11,16,15,21,42);
my $diff = Local::Date::Interval->diff($date1, $date2);

isa_ok($diff, 'Local::Date::Interval');

$diff = Local::Date::Interval->new({
    hour    => 1,
    minute  => 15
});

like ( $diff->to_string(), qr/\+1 hour, 15 minute/, 'test to_string function');

$diff = Local::Date::Interval->new({
    hour    => -1,
});

like ( $diff->to_string(), qr/\-1 hour/, 'test to_string function negative values');

#overload
like ( $date1, qr/2008-11-16T14:21:42/, 'test overload double quotes' );
like ( $date2, qr/2008-11-16T15:21:42/, 'test overload double quotes' );
like ( $date1 - $date2, qr/\-1 hour/, "test overload '-' operator" );
like ( $date2 - $date1, qr/\+1 hour/, "test overload '-' operator" );

#export
use Local::Date qw(date interval);
my $date = date(2011,3,4,5,6,7);
like ( $date, qr/2011-03-04T05:06:07/, 'test export function date' );
$diff = interval($date1, $date2);
like ( $diff, qr/\-1 hour/, "test iexport function interval" );

};

subtest 'Test add functions' => sub {

my $obj = Local::Date->new(2008,11,16,14,21,42);

sub add_smth {
    my $self = shift;
    my $aref = shift;
    my $fun = $aref->[0]; #year
    my $arg = $aref->[1]; #-2
    given ($fun) {
        when ('add_years' )     { $self->add_years($arg); }
        when ('add_months')     { $self->add_months($arg); }
        when ('add_weeks' )     { $self->add_weeks($arg); }
        when ('add_days'  )     { $self->add_days($arg); }
        when ('add_hours' )     { $self->add_hours($arg); }
        when ('add_minutes')    { $self->add_minutes($arg); }
        default { return undef }
    }
    return $self;
}

#Хорошо бы во втором стоблце использовать ссылку на метод объека, вроде \&add_year(1)
#Сверял здесь https://planetcalc.ru/274/
#Имеет смысл генерировать значения массива третьего столбца с помощью https://metacpan.org/pod/Date::Calc

my $tests = [
                #start date                #function                  #result date                    #explanation
    [   [2016,  2, 12, 14, 15, 16],   ['add_years',    3]   ,   [2019,  2, 12, 14, 15, 16] ,    'check function add_year'  ],
    [   [2016,  3, 30, 14, 15, 16],   ['add_years',   -1]   ,   [2015,  3, 30, 14, 15, 16] ,    'check add_year negative'  ],
    [   [2016,  2, 29, 14, 15, 16],   ['add_years',    1]   ,   [2017,  3,  1, 14, 15, 16] ,    'check add_year on 29.02'  ],
    [   [2001,  3,  5, 14, 15, 16],   ['add_months',  22]   ,   [2003,  1,  5, 14, 15, 16] ,    'check add_months more than 12'  ],
    [   [2005,  4,  9, 14, 15, 16],   ['add_months',  -1]   ,   [2005,  3,  9, 14, 15, 16] ,    'add_months negative 9.04 -> 9.03' ],
    [   [2003,  5,  5, 14, 15, 16],   ['add_months',  11]   ,   [2004,  4,  5, 14, 15, 16] ,    'check add_months pass through leap year'  ],
    [   [2004,  2, 29, 14, 15, 16],   ['add_months',   1]   ,   [2004,  3, 29, 14, 15, 16] ,    '29.02 -> 3.29 in leap year'  ],
    [   [2004,  2, 29, 14, 15, 16],   ['add_months',  13]   ,   [2005,  3, 29, 14, 15, 16] ,    '29.02.2004 -> 29.03.2005' ],
    [   [2004,  1, 29, 14, 15, 16],   ['add_months',   1]   ,   [2004,  2, 29, 14, 15, 16] ,    '29.01.2004 -> 29.02.2004' ],
    [   [2004,  4, 29, 14, 15, 16],   ['add_months',  -2]   ,   [2004,  2, 29, 14, 15, 16] ,    'add_months negative 29.04 -> 29.02' ],
    [   [2004,  5, 31, 14, 15, 16],   ['add_months',   1]   ,   [2004,  7,  1, 14, 15, 16] ,    'add 1 month: 31.5 -> 1.7'  ],
    [   [2019,  3,  4, 14, 15, 16],   ['add_weeks',    4]   ,   [2019,  4,  1, 14, 15, 16] ,    'add 4 weeks: 4.3 -> 1.4'  ],
    [   [2017,  3,  6, 14, 15, 16],   ['add_weeks',  108]   ,   [2019,  4,  1, 14, 15, 16] ,    'add 108 weeks'  ],
    [   [2017, 12,  6, 14, 15, 16],   ['add_weeks',   -8]   ,   [2017, 10, 11, 14, 15, 16] ,    'add weeks negative'  ],
    [   [2015, 12,  6, 14, 15, 16],   ['add_weeks',   13]   ,   [2016,  3,  6, 14, 15, 16] ,    'add weeks through 29.02'  ],
    [   [2011,  2,  1, 14, 15, 16],   ['add_days',    28]   ,   [2011,  3,  1, 14, 15, 16] ,    'check function add_days'  ],
#   [   [2012,  2, 29, 14, 15, 16],   ['add_days',   366]   ,   [2013,  3,  1, 14, 15, 16] ,    'add_days 29.2.2012 -> 1.3.2013'  ],
    [   [2012,  2,  1, 14, 15, 16],   ['add_days',    28]   ,   [2012,  2, 29, 14, 15, 16] ,    'add_days 1.2.2012 -> 29.2.2012'  ],
    [   [2012, 11, 30,  1, 15, 16],   ['add_hours',   25]   ,   [2012, 12,  1,  2, 15, 16] ,    'add_hours more than 24'  ],
    [   [2012, 12, 31, 23, 15, 16],   ['add_hours',    2]   ,   [2013,  1,  1,  1, 15, 16] ,    'add_hours through year'  ],
    [   [2011, 12, 12, 20, 11, 07],   ['add_minutes', 55]   ,   [2011, 12, 12, 21, 06, 07] ,    'check add_minutes'  ],
    [   [2011, 12, 31, 23, 11, 07],   ['add_minutes', 55]   ,   [2012,  1,  1,  0, 06, 07] ,    'add_minutes through year'  ],
    [   [2011, 12, 12, 20, 11, 07],   ['add_minutes',115]   ,   [2011, 12, 12, 22, 06, 07] ,    'add_minutes more than hour'  ],
];

my @attributes = qw(year month day hour minute second);

for my $current_test (@{$tests}) {
    $obj = Local::Date->new(@{$current_test->[0]});
    add_smth($obj, $current_test->[1]);

    #function is_deeply works with structures. 
    #Create hash from objects

    #workaround, because of using Object::Accessor
    #Normal object is a hash %$obj: year => 1968
    #This object is: year => ARRAY(0x55901bb39cc0);
    #The first element of this array is 1968;

    my $result_hash = {};
    $$result_hash{$_} = $obj->{$_}[0] for @attributes;

    my $i = 0;
    my $true_result = {};
    #$true_result->{$_} = $curr_date_ref->[$i++] for @attributes;
    #$true_result->{$_} = $result_date->[$index][$i++] for @attributes;
    $true_result->{$_} = $current_test->[2][$i++] for @attributes;
                                                                                                                                                                                                            
    is_deeply($result_hash, $true_result, $current_test->[3]);

}

};
