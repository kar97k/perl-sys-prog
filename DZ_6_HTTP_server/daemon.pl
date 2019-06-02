#!/usr/bin/env perl

use 5.016;
use strict;
use warnings;
use Fcntl;
use Fcntl ':flock';
use Socket ':all';
use Getopt::Std;
use POSIX;

our $opt_s = "";
getopts('s:');

my $pfile = "/tmp/daemon.pid";
my $pfd;

OPEN: {
    no strict 'subs';
    my $flags = -e $pfile ? O_RDWR :
    #битовые маски?
    (O_CREAT | O_EXCL | O_RDWR);
    my $errno = -e $pfile ? 'ENOENT' : 'EEXIST';
    #Argument "O_RDWR" isn't numeric in sysopen;        
    #use Fcntl fixed
    #unless (sysopen($pfd, $pfile, 2)) {
    unless (sysopen($pfd, $pfile, $flags)) {
        redo OPEN if $!{$errno};
        die "open $pfile: $!";
    }
}

#break logic of pid number in /tmp/daemon.pid if set this snippet after flock block
my $pid = fork and exit;
defined $pid or die "Failed to spawn: $!";
setsid();

if (flock($pfd, LOCK_EX | LOCK_NB)) {
    seek $pfd, 0, 0;
    syswrite $pfd, "$$";
} else {
    chomp(my $pid = <$pfd>);
    if ($opt_s eq 'stop') {
        say "Going to stop server $pid";
        kill TERM => $pid;
        exit;
    } else {
        die "Already running (pid $pid)\n";
    }
}

my $log_name = "/var/log/server_nazarov/server_nazarov.log";
open my $log_fd, ">>", $log_name or die "$log_name open failed: $!";
syswrite($log_fd, "Server started at ". localtime()."\n");

close STDIN; open STDIN, '<', '/dev/null';
open STDOUT, '>&', $log_fd or die "Failed to dup STDOUT: $!";
open STDERR, '>&', $log_fd or die "Failed to dup STDOUT: $!";
$0 = "server nazarov";

my $work = 1;
$SIG{INT} = $SIG{TERM} = sub {
    $0 = "daemon - stopping";
    syswrite($log_fd, "Server got SIGINT, stopped at ". localtime()."\n");
    sleep 5;
    unless ($work--) {
        warn "Forced exit\n";
        exit;
    }
};

$SIG{HUP} = sub {
    #gzip old log, create new
    my ($S, $M, $H, $d, $m, $y) = localtime(time); $m += 1; $y += 1900;
    rename($log_name, my $oldlog = join ("-", $log_name, $d, $m, $y, $H, $M, $S)) or die "Cannot rename $log_name: $!";
    #my $oldlog = join ("-", $log_name, $d, $m, $y, $H, $M, $S);
    #close $log_fd;
    #open ($log_fd, "|-", "/bin/gzip -c > $oldlog.gz") or die "error starting gzip $!";
    #close $oldlog;
    #unlink $oldlog;
    if (open my $newlog, ">>", "$log_name") {
        $log_fd = $newlog;
        open STDOUT, '>&', $log_fd or die "Failed to dup STDOUT: $!";
        open STDERR, '>&', $log_fd or die "Failed to dup STDOUT: $!";
    } else {
        warn "$log_name open failed: $!";
    }
};

socket my $srv, AF_INET, SOCK_STREAM, IPPROTO_TCP or die $!; 
setsockopt $srv, SOL_SOCKET, SO_REUSEADDR, 1 or die $!; 
bind $srv, sockaddr_in(5533, inet_aton('192.168.17.75')) or die $!; 
listen $srv, SOMAXCONN or die $!; 

$SIG{CHLD} = 'IGNORE';

while (my $peer = accept my $cln, $srv) {
    defined(my $chld = fork()) or die "fork: $!";
    if ($chld) { close $cln; }
    else {
        my ($port, $addr) = sockaddr_in($peer);
        my $ip = inet_ntoa($addr);
        my $host = gethostbyaddr($addr, AF_INET);
        say "I am child $$, client connected from $ip:$port ($host)";
        my $root = "/home/g.nazarov/server/";
        my $req = <$cln>;
        #my $full_packet_req = sysread($cln, my $req, 4096);

        say "I am $$: \$req is $req";
        my ($method, $path) = $req =~ /^([A-Z]+)\s\/([^\s]+)\sHTTP/;
        given ($method) {
            when ($method eq 'GET') {
                # '/' symbol in the end of path means it is a directory
                if ($path =~ /^.*\/$/) {
                    opendir(my $dh, $root.$path) or do {
                        my $err = "Could not open directory '$root$path' $!\n";
                        syswrite $cln, "HTTP/1.1 404 Not Found\nContent-Length: ".
                        length($err). "\n\n$err\n"; 
                        exit;
                    };
                    my @list; 
                    push @list, $_ for readdir($dh); 
                    closedir($dh) or warn $!;
                    my $data; 
                    $data .= $_ for join "\n", @list;
                    $data .= "\n";
                    syswrite $cln, "HTTP/1.1 200 OK\nContent-Length: ".
                    length($data). "\n\n$data\n";
                    exit;
                } else {
                    open(my $fh, '<:raw', $root.$path) or do {
                        my $err = "Could not open file '$root$path' $!\n";
                        syswrite $cln, "HTTP/1.1 404 Not Found\nContent-Length: ".
                        length($err). "\n\n$err\n"; 
                        exit;
                    };
                    my $data = do { local $/; <$fh> };
                    syswrite $cln, "HTTP/1.1 200 OK\nContent-Length: ".
                    length($data). "\n\n$data\n";
                    exit;
                }
            }
            when ($method eq 'PUT') {
                    syswrite $cln, "HTTP/1.1 100 Continue\n\n";
                    #Client sends file without waiting for answer, don't know why
                    my $ans_ans = sysread($cln, my $file_content, 4096);
                    open(my $fh, '>', $root.$path);
                    syswrite $fh, $file_content;
                    close($fh);
                    my $answer = "Succesfully created $path, check it with GET request\n";
                    syswrite $cln, "HTTP/1.1 201 Created\n".
                    "Content-Location: /$path\n".
                    "Content-Length: ".length($answer)."\n\n$answer";
                    exit;
                }
            when ($method eq 'DELETE') {
                    if (-f $root.$path) { 
                        say "going to delete $root$path"; 
                        unlink $root.$path;
                        syswrite $cln, "HTTP/1.1 204 No Content\n";
                        exit;
                    }
                }
            default {
                syswrite $cln, "HTTP/1.1 415 Not allowed\n".
                "Content-Length: 0\n\n"; 
                exit;
            }
        }
    }
    #sleep 1;
    #doesn't print every second, print all strings when got SIGINT
    #print {$log_fd} "Work through print\n";

    #syswrite($log_fd, "work through syswrite\n");
    #say "$$ do work";
    #do_work();
}
