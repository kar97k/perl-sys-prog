package Local::JSONParser;

use strict;
use warnings;
use base qw(Exporter);
use Encode;
use feature 'say';
use feature 'switch';
our @EXPORT_OK = qw( parse_json );
our @EXPORT = qw( parse_json );

sub get_string {
    #break if it is not json string
    my $str = shift;
    #say "get string $str";
    #string is a sequence of symbols between double quotes. 
    #there may be a shielded double quotes in string
    my ($begin, $end) = get_pair_position($str, '"');
    my $process_str = substr $str, $begin, ($end - $begin -1);
    pos($process_str) = 0;
    while (pos($process_str) < length($process_str)) {
        #how to extend \w to "any unicode symbol" and exept " and \ from this group ?
        if ($process_str =~ /\G([a-zA-Z0-9!@#$%^&*()_+\-=\[\]{};':"\\|,.<>\/?\ ]+)/gc) { next; }  #say "word $1";
        #shielded symbols like \t \u \t or hexedecimal \u23af
        elsif ($process_str =~ m!\G\\((?:[bfnrt"\\/]|u[0-9a-fA-F]{4}))!gc) { next; } #say "backslash seq$1";
        #match кириллица
        elsif ($process_str =~ m!\G\P{M}+!gc) { next; }
        else {return 0;} #say "else string";
    }
    #return string without quotes
    return $process_str;
}

sub get_number {
    my $str = shift;
    unless ($str =~ m!(-?(?:0|[1-9][0-9]*)(?:\.\d+)?(?:[eE][+\-]*\d+)?)!) { return 0; }
    $str = $1;
    return $str;
}

sub get_object {
    my $str = shift;
    
    #get string that may be object

    my ($begin, $end) = get_pair_position($str, '{');
    #$obj_str contains string between curly brackets
    my $obj_str = substr $str, $begin, ($end - $begin -1);
    #say "get object: $obj_str";

    #process string and convert into perl structures
 
    my $key; 
    my $value;
    my %res_hash;
    pos($obj_str) = 0;

    #empty object {}
    if ($obj_str =~ m/^\s*$/s) { return \%res_hash; }

    #regular objects
    next_pair:
    #get key
    $key = get_string($obj_str)                                                 or die "can't match string in key of object $obj_str";
    $key = process_unicode($key);
    #say "key $key";
    #place regexp coursour after $key on position of second double quote;
    pos($obj_str) = (get_pair_position($obj_str, '"'))[1];
    #place regexp coursour after semicolon
    $obj_str =~ m/\G\s*:/gc                                                     or die "no semicolon after key in $obj_str";

    #get_value
    #cut before semicolon
    $obj_str = substr $obj_str, pos($obj_str);
    pos($obj_str) = 0;
    $value = get_value($obj_str);
    #say "value $value";
    #place regexp coursour after value
    if (ref $value eq 'HASH') {
        pos($obj_str) = (get_pair_position($obj_str, '{'))[1];
    }
    elsif (ref $value eq 'ARRAY') {
        pos($obj_str) = (get_pair_position($obj_str, '['))[1];
    }
    else {
        if ($obj_str =~ m/\G\s*"/) { 
            pos($obj_str) = (get_pair_position($obj_str, '"'))[1];
            $value = process_unicode($value); 
        }
        else { 
            $obj_str =~ m/\G\s*/gc; 
            pos($obj_str) += length($value);
        }
    }
    $res_hash{$key} = $value;

    #next pair key value 

    if ($obj_str =~ m/\G\s*,/gc) {
        $obj_str = substr $obj_str, pos($obj_str);
        pos($obj_str) = 0;
        goto next_pair;
    } 
    if ($obj_str =~ m/\G\s*$/g) { return \%res_hash }
    else { die "Symbols after value $value" }
}

sub get_value {
    my $str = shift;
    #get first symbol of object {, array [, string " or number (digit or -)
    $str =~ m/^\s*([\{\[\"\d+\-])/;
    #say "get_value match $1";
    given ($1) {
        when ('"') { return get_string($str); }        #say "str";
        when (m/\d|-/) { return get_number($str); }    #say "digit";
        when ('{') { return get_object($str); }        #say "obj";
        when ('[') { return get_array($str); }         #say "array";
        default { return undef; }
    }
    return undef;
}

sub get_array {
    my ($arr_str) = @_;
	
    my ($begin, $end) = get_pair_position($arr_str, '[');
	#don't include square bracket
    #arr_str now contains string between brackets 
    $arr_str = substr $arr_str, $begin, ($end - $begin - 1);
    #say "get array: $arr_str";

    #process string and convert into perl structures
    
    my $value;
    my @res_arr = ();
    pos($arr_str) = 0;
    
    if ($arr_str =~ m/^\s*$/s) { return \@res_arr};

    next_object:
    
    $value = get_value($arr_str);
    #say "value in array $value";
    if (ref $value eq 'HASH') {
        pos($arr_str) = (get_pair_position($arr_str, '{'))[1];
    }
    elsif (ref $value eq 'ARRAY') {
        pos($arr_str) = (get_pair_position($arr_str, '['))[1];
    }
    else {
        if ($arr_str =~ m/\G\s*"/) { 
            pos($arr_str) = (get_pair_position($arr_str, '"'))[1]; 
            $value = process_unicode($value);
        }
        else { 
            $arr_str =~ m/\G\s*/gc;
            pos($arr_str) += length($value); 
        }
    }
    push @res_arr, $value;
    if ($arr_str =~ m/\G\s*,/gc) {
        $arr_str = substr $arr_str, pos($arr_str);
        pos($arr_str) = 0;
        goto next_object;
    }
    
    if ($arr_str =~ m/\G\s*$/g) { return \@res_arr } 
    else { die "Symbols after value $value" }
}

sub get_pair_position {
	#get string and token " { [ 
	#return position of token and it's pair
    #if json structure contains nested structures, number of opening brackets is equal to number of closing braсkets, so returns position of corresponding bracket
    my ($str, $token) = @_;
    #say "gonna find pair in $str";
    my $token_pair;
    # [ is a metacharacter for regexp
    $str =~ m/\Q$token\E/g;
    my $begin = pos($str);
    given ($token) {
        when ('"') { $str =~ m/\G.*?(?<!\\)"/gc; return ($begin, pos($str)); }
        when ('{') { $token_pair = '}' }
        when ('[') { $token_pair = ']' }
        default { last; }#return undef; }
    }

    my $cnt = 1;
    while (pos($str) < length($str) and $cnt > 0 ) {
        if ($str =~ /\G.*?([\Q$token|$token_pair\E])/sgc) {
            if ( $1 eq $token ) { $cnt++;} #say "in $cnt";}
            elsif ( $1 eq $token_pair ) { $cnt--;} #say "on $cnt";}
        }
        else {last; } #return undef} #die "not equal number of $token and $token_pair"}#last;}
    }
    my $end = pos($str);
    return ($begin, $end);
}

sub process_unicode {
    my $str = shift;
    my %map_cntrl_characters = (
        'b'   =>    "\b",
        'f'   =>    "\f",
        't'   =>    "\t",
        'n'   =>    "\n",
        'r'   =>    "\r"
    );
    #киррилица
    if ($str =~ m/(\P{M}+)/) { $str = decode('utf8', $str) } 

    #1) remove \ before shielded " \ / : convert \" into "
    #2) convert \u123f into symbol
    #3) convert \t,\n, \r  into escape sequences
    #4) move coursour to the next \
    $str =~ s{\G(?:(?:\\(["\\/]))|(?:\\u(....))|(?:\\([trnbf]))|(.*?)(?=\\))}{ $1 ? $1 : $2 ? pack 'U*', hex($2) : $3 ? $map_cntrl_characters{$3} : $4 }ge;
    #use Data::Dumper;
    ##if \P{M}
    #$str = decode('utf8', $str);
    return $str;
}

sub parse_json {
	my $source = shift;
    my $result;
    if ($source !~ m/^\s*[{\[].*[}\]]\s*$/s) { die "not an object or array given: $source" };
    $result = get_value($source);

	# This is an example, what function should return
    #use JSON::XS; 
    #return JSON::XS->new->utf8->decode($source);
	return $result;
}

1;
