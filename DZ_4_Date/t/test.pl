#!/usr/bin/env perl

use strict;
use warnings;
use 5.016;

use Test::More tests => 18;

use FindBin;
use lib "$FindBin::Bin/../lib";

require_ok('Local::Date');

my $obj = Local::Date->new(2008,11,16,14,21,42);

say ref $obj;

isa_ok( $obj, 'Local::Date' );
new_ok('Local::Date' => [2008,11,16,14,21,42] );

#(year month day hour minute second)
my @methods = qw( min sec now from_epoch strftime datetime);
for (@methods) {
    can_ok($obj, $_);
}

say "----------------";

can_ok($obj, 'new');

ok($obj->year == 2008, 'check accessor year');

$obj->add_years(-2);
is ($obj->year, 2006, 'check function add_year');
isnt ($obj->year, 2003, 'check function add_year');

say "----------------";
#better use subtest

#test add functions

my $input_date = [
    [2015, 2, 12 , 14, 15, 16],
    [2013, 7,  1 ,  4, 21, 53]
];

my $result_date = [
    [2016, 2, 12 , 14, 15, 16],
    [2014, 7,  1 ,  4, 21, 53]
];

my @attributes = qw(year month day hour minute second);

#say @{ $input_date->[0] };
say "NUMBER", $#{$input_date};
for my $index (0..$#{$input_date}) {

    #$obj = Local::Date->new(@{ $input_date->[0] });
    #$obj = Local::Date->new(@{ $curr_date_ref });
    $obj = Local::Date->new(@{ $input_date->[$index] });

    $obj->add_years(1);

    #workaround, because of using Object::Accessor
    #Normal object is a hash %$obj: year => 1968
    #This object is: year => ARRAY(0x55901bb39cc0);
    #The first element of this array is 1968;

    my $result_hash = {};
    $$result_hash{$_} = $obj->{$_}[0] for @attributes;

    my $i = 0;
    my $true_result = {};
    #$true_result->{$_} = $curr_date_ref->[$i++] for @attributes;
    $true_result->{$_} = $result_date->[$index][$i++] for @attributes;
    
    say $true_result->{$_} for @attributes;

    is_deeply($result_hash, $true_result, 'test add year');
}
