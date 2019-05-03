package Local::Calc;

use 5.010;
use strict;
use warnings;
BEGIN{
	if ($] < 5.018) {
		package experimental;
		use warnings::register;
	}
}
no warnings 'experimental';

use Exporter 'import';
our @EXPORT_OK = qw(tokenize rpn evaluate);

=head1 DESCRIPTION

Эта функция должна принять на вход арифметическое выражение,
а на выходе дать ссылку на массив, состоящий из отдельных токенов.
Токен - это отдельная логическая часть выражения: число, скобка или арифметическая операция
В случае ошибки в выражении функция должна вызывать die с сообщением об ошибке

Знаки '-' и '+' в первой позиции, или после другой арифметической операции стоит воспринимать
как унарные и можно записывать как "U-" и "U+"

Стоит заметить, что после унарного оператора нельзя использовать бинарные операторы
Например последовательность 1 + - / 2 невалидна. Бинарный оператор / идёт после использования унарного "-"

=cut

sub tokenize {
	chomp(my $expr = shift);
	my @res;
    #remove spaces from string;
    #$expr =~ m/\s+/ and die "Bad sequence";
    $expr =~ s/\s+//g;

    #tokenize string
    for ($expr) {
        pos() = 0; #initialize pos() to remove error "Use of uninitialized value in numeric lt..." from output
        while (pos() < length()) {
            #scientific E-notation; 1.23e+4 1.22e3 1.74e-8
            if (/\G(\d?\.?\d+[eE][+\-]?\d+)/gc) {
                push @res, 0+$1;
            }
            #digit with dots: 2.3 .2
            #(?!\.) look forward there is no dots after numbers 
            elsif ( /\G(\d*\.\d+)(?!\.)/gc ) {
                push @res, 0+$1;
            }
            #regular digits
            elsif (/\G(\d+)/gc) {
                 push @res, $1;
                 #say "got digits $1";
            }
            #binary operators +-/*^
            #left: digit or closing bracket
            #right: digit or opening bracket or unary +- or dot
            elsif ( m!(?:\d|\))\G([+*/^\-])(?:\d|[+\-]|\(|\.)!gc  ) {
                #say "got binary ariph operator $1";
                push @res,$1;
                #digits matches after cursor, so have to move back for 1 position.
                #have to test to find infinte loop
                pos() -= 1;
            }
            #unary operators + and -
            #+ or - unary if:
            #left: beginig of line (^) or other ariphmetic operator: +-*/^ or opening bracket.
            #right: digit or dot or opening bracket
            #or another + or -
            #need somehow simplify
            elsif ( m!(?:^|[+*/^\-]|\()\G([+\-])(?:\d|\.|\(|[+\-])!gc ) {
                #say "got unary ariph operator $1";
                push @res, 'U'.$1;
                pos() -= 1;
            }
            #brackets
            elsif (/\G([\(\)])/gc) {
                push @res, $1;
            }
            else {
                die "Bad sequence";
            }
        }
    }
	return \@res;
}

=head1 DESCRIPTION

Эта функция должна принять на вход арифметическое выражение,
а на выходе дать ссылку на массив, содержащий обратную польскую нотацию
Один элемент массива - это число или арифметическая операция
В случае ошибки функция должна вызывать die с сообщением об ошибке

=cut

sub rpn {
    
    #https://en.wikipedia.org/wiki/Shunting-yard_algorithm

	my $expr = shift;
	my $source = tokenize($expr);
	my @rpn;
    my @chunks = @{$source};
    my @stack = ();
    #first element of array is operator priority, second - associativity ( r - right associative; l - left associative )
    my %op_hash = (
        '^'  => [ 4 , 'r' ] ,
        'U-' => [ 3 , 'r' ] ,
        'U+' => [ 3 , 'r' ] ,
        '*'  => [ 2 , 'l' ] ,
        '/'  => [ 2 , 'l' ] ,
        '+'  => [ 1 , 'l' ] ,
        '-'  => [ 1 , 'l' ] ,
        '('  => [ 0 , ''  ] ,
        ')'  => [ 0 , ''  ] 
    );
    my $ops_brackets_arr_ref = [keys %op_hash];
    #sophisticated way to get array of operators without brackets from keys of %op_hash
    #just practise with nested structures
    my $ops_arr_ref = [ grep { $op_hash{$_}->[0] } keys %op_hash ];
    my $break_inf_loop = 0;

    for my $c (@chunks) {
        #say "\ncurr token $c\nstack:@stack\nrpn:@rpn\n";
        given ($c) {
            #token is digit
            #Если токен — число, то добавить его в очередь вывода.
            when (/\d+/) { 
                push @rpn, $c;
            }
            #if the token is a function then push it onto the operator stack
            when (/U[+\-]/) { push @stack, $c; }
            #token is operator
            #dont understand how $c matches with elements from array ref to drop in this condition
            when ($ops_arr_ref) { 
                #while ((there is a function at the top of the operator stack)      #not relevent
                #or (there is an operator at the top of the operator stack with greater precedence)
                #or (the operator at the top of the operator stack has equal precedence and is left associative))
                #and (the operator at the top of the operator stack is not a left parenthesis):
                my $first_cond = 1 if ( $stack[-1] and $op_hash{ $c }->[0] < 0+$op_hash{ $stack[-1] }->[0] );
                my $second_cond = 1 if ( $stack[-1] and $op_hash{ $c }->[0] == 0+$op_hash{ $stack[-1] }->[0] and $op_hash{ $stack[-1] }->[1] eq 'l' );
                #say "1st: $first_cond; 2nd: $second_cond";

                while ( ($first_cond or $second_cond) and $stack[-1] ne '(' ) {
                    push @rpn, pop @stack;
                    $first_cond = 0;
                    $second_cond = 0;
                    $first_cond = 1 if ( $stack[-1] and $op_hash{ $c }->[0] < 0+$op_hash{ $stack[-1] }->[0]);
                    $second_cond = 1 if ( $stack[-1] and $op_hash{ $c }->[0] == 0+$op_hash{ $stack[-1] }->[0] and $op_hash{ $stack[-1] }->[1] eq 'l' );
                }
                push @stack, $c;
            }
            when ( '(' ) { push @stack, $c; } 
            when ( ')' ) { 
                while ( $stack[-1] ne '(' and $stack[-1] ) { push @rpn, pop @stack; }
                #remove ( from stack
                pop @stack;
            }
            default {
                die "Bad: '$_'";
            }
        }
    }
    while ( $stack[-1] ) {
        push @rpn, pop @stack;
    }
	return \@rpn;
}

=head1 DESCRIPTION

Эта функция должна принять на вход ссылку на массив, который представляет из себя обратную польскую нотацию,
а на выходе вернуть вычисленное выражение

=cut

sub evaluate {
	my $rpn = shift;
    my @rpn_arr = @{$rpn};
    my @stack = ();
    my %ops = (
        '+' => sub { $_[0] + $_[1] },
        '-' => sub { $_[0] - $_[1] },
        '*' => sub { $_[0] * $_[1] },
        '/' => sub { $_[0] / $_[1] },
        '^' => sub { $_[0] **$_[1] },
        'U-'=> sub { -$_[0] },
        'U+'=> sub { $_[0] }
    );
    for my $c (@rpn_arr) {
        if ( $c =~ /\d+/ ) { push @stack, $c }
        elsif ( $c =~ /^[+\-*\/^]$/ ) {
            my $right = pop @stack;
            my $left = pop @stack;
            my $res = $ops{ $c }->( $left , $right );
            push @stack, $res;
        }
        elsif ( $c =~ /^U[+\-]$/ ) {
            my $y = pop @stack;
            my $r = $ops{ $c }->( $y );
            push @stack, $r;
        }
    }
    return $stack[-1];
}

1;
