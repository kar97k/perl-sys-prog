#!/usr/bin/env perl

#  скрипт - распечатать словами число из аргумента.
#  Поддержать числа до миллиарда

my %units = (
        0 => "",
        1 => "один",
        2 => "два",
        3 => "три",
        4 => "четыре",
        5 => "пять",
        6 => "шесть",
        7 => "семь",
        8 => "восемь",
        9 => "девять"
);

my %one_tens = (
        10 => "десять",
        11 => "одиннадцать",
        12 => "двенадцать",
        13 => "тринадцать",
        14 => "четырнадцать",
        15 => "пятнадцать",
        16 => "шестнадцать",
        17 => "семнадцать",
        18 => "восемнадцать",
        19 => "девятнадцать",
);

my %tens = (
        0 => "",
        2 => "двадцать",
        3 => "тридцать",
        4 => "сорок",
        5 => "пятьдесят",
        6 => "шестьдесят",
        7 => "семьдесят",
        8 => "восемьдесят",
        9 => "девяносто"
);

my %hundreds = (
        0 => "",
        1 => "сто",
        2 => "двести",
        3 => "триста",
        4 => "четыреста",
        5 => "пятьсот",
        6 => "шестьсот",
        7 => "семьсот",
        8 => "восемьсот",
        9 => "девятьсот"
);

my %thousands = (
        0 => "",
        1 => "одна",
        2 => "две",
        3 => "три",
        4 => "четыре",
        5 => "пять",
        6 => "шесть",
        7 => "семь",
        8 => "восемь",
        9 => "девять"
);

sub hundred_words {
        my $num = shift;
        my @arr_num = split //, $num;
        my $res_str;
        #if number of one digit get, make 001 form 1, goto 3-rd digit processing
        if (scalar @arr_num == 1) { unshift @arr_num, 0, 0; goto onedigit;  }
        #if number of two digits get, make 034 from 34, goto 2-nd digit processing
        if (scalar @arr_num == 2) { unshift @arr_num, 0; goto twodigits;  }
        if (scalar @arr_num == 3) {
                #processing first digit
                $res_str .= "$hundreds{ $arr_num[0] }";
                #processing second digit
                if ($arr_num[1] != 0) {
                        twodigits:
                        if ($arr_num[0] != 0) {$res_str .= ' '}; #without it, 019 became " девятнадцать" (with space character before 'д')
                        #process numbers 10 - 19
                        if ($arr_num[1] == 1) {
                                my $two_digit_num = $arr_num[1].$arr_num[2];
                                $res_str .= "$one_tens{ $two_digit_num }";
                        }
                        #process numbers 20 - 99
                        else {
                                #second digit
                                $res_str .= "$tens{ $arr_num[1] }";
                                #third digit
                                if ($arr_num[2] != 0) {
                                        $res_str .= ' ';
                                        onedigit:
                                        $res_str .= $units{ $arr_num[2] };
                                }
                        }
                }
                else {
                        #processing third digit
                        if ($arr_num[2] != 0 ) {
                                $res_str .= ' ';
                                $res_str .= "$units{ $arr_num[2] }";
                        }
                }
        }
        return $res_str;
}

#1 тысяча;
#2,3,4 тысячи;
#5,6,7,8,9 тысяч;
#10,11, ..., 19 тысяч
#
#один тысяча не правильно; одна тысяча
#два тысячи не правильно; две тысячи

sub thousand_words {
        my $num = shift;
        my @arr_num = split //, $num;
        my $word_string = hundred_words($num);
        my $last_digit = $arr_num[$#arr_num];
        if ( $num == 0 ) { $word_string .= "" }
        elsif ( scalar @arr_num > 1 && $arr_num[$#arr_num - 1] == 1 ) { $word_string .= " тысяч"}
        elsif ($last_digit == 1) { $word_string =~ s/один$/одна/; $word_string .= " тысяча" }
        elsif ($last_digit == 2 or $last_digit == 3 or $last_digit == 4) {
                if ($last_digit == 2) { $word_string =~ s/два$/две/ }
                $word_string .= " тысячи"
        }
        else { $word_string .= " тысяч" }
        #print "before $word_string";
        return $word_string;
}

#1 миллион; 2,3,4 миллиона; 5,6,7,8,9 миллионов; 10 - 19 миллионов;
sub million_words {
        my $num = shift;
        my @arr_num = split //, $num;
        my $word_string = hundred_words($num);
        my $last_digit = $arr_num[$#arr_num];
        if ( scalar @arr_num > 1 && $arr_num[$#arr_num - 1] == 1 ) { $word_string .= " миллионов"}
        elsif ($last_digit == 1) { $word_string .= " миллион" }
        elsif ($last_digit == 2 or $last_digit == 3 or $last_digit == 4) { $word_string .= " миллиона" }
        else { $word_string .= " миллионов" }
        return $word_string;
}

sub num_to_word {
        my $str = shift;
        #remove spaces between digits
        $str =~ s/\s+//g;
        unless ($str =~ m/^\d+$/) {print "Not a number was inputed"; return 1;};
        if (length $str > 9) { print "Too big number"; return 1;}
        my $result = hundred_words(substr($str, -3));
        if ( length $str > 3 ) { $result = thousand_words( substr($str, -6, 3) ).' '.$result; }
        if ( length $str > 6 ) { $result = million_words( substr($str, -9, 3) ).' '.$result; }
        $result =~ s/\s{2,}/ /g;
        $result =~ s/\s+$//;
        return $result;
}

print num_to_word(@ARGV);
print "\n";
