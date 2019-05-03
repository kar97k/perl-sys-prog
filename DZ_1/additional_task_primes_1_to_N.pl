#!/usr/bin/env perl

#скрипт - найти все простые числа в диапазоне от 1..N
#(N приходит как аргумент в программу)

use strict;
use warnings;

sub is_prime {
    my $digit = shift;
    return if ($digit <= 1);
    my $end_of_cycle = int sqrt $digit;
    for (2..$end_of_cycle) {
        #if result is zero, digit is not prime
        return unless $digit % $_;
    }
    return 1;
}

sub primes_from_1_to_n {
    my $n = shift;
    return "no argument given!\n" unless $n;
    my @result;
    if ($n < 3) { return 2} 
    push @result, 2;
    #C-style for, because no matter check even numbers
    for (my $i = 3; $i <= $n; $i+=2) {
        if (is_prime($i)) { push @result, $i}
    }
    return @result;
}

#better than $", because no need interpolate result
$,=' ';
#\n printed after array, only in print function
$\="\n";
print primes_from_1_to_n(@ARGV);
