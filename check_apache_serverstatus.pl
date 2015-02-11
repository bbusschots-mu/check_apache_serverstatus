#!/usr/bin/perl

use strict;
use warnings;
use Carp;
use Getopt::Std; # for commandline argument processing
use English qw( -no_match_vars );  # for eval error special variable
use Parse::Apache::ServerStatus; # from CPAN, for parsing Apache status page
use Math::Round; # for rounding percentages to 2 decimal places

#
# Process arguments
#

# get the arguments, and support --help and --version
my %flags; # a hashref to store the arguments in
$Getopt::Std::STANDARD_HELP_VERSION = 1;
sub VERSION_MESSAGE {
    print "check_apache_serverstatus.pl version 0.2 (released February 2015)\n";
    return;
}
sub HELP_MESSAGE{
    print <<'END_HELP';

A plguin for checking the status of an Apache Web server using the server-status
module.

As well as checking that Apache is up, this plugin also checks if there are
enough free slots, and, if there are an in-ordinate number of slots in the R
state (reading request), which is a symptom of a slowlorios-style (D)DOS attack.

Required Flags:
-H      The hostname for the server to be checked

Optional Flags:
-c      The % of free slots below which a critical state is triggered as an
        integer (defaults to 10).
-w      The % of free slots below which a warning is triggered as an integer,
        must be a greater than -c (defaults to 33). 
-r      The % of R slotgs above which a warning is triggered as an integer
        (defaults to 33).
-t      The timeout to wait for a reply from the server in seconds (defaults to
        10).

Exit Codes:
0       SUCCESS  - The server responded to the status request, the percentage
                   of free slots is above -w, and the percentage of slots in an
                   R state is below -r. I.e., the server looks healthy. 
1       WARNING  - The server responded to the status request, but either the
                   percentage of free slots is greater than -w but less than -c,
                   or the percentage of slots in an R state i greater than -r.
2       CRITICAL - The server did not respond at all, or the percentage of free
                   slots is below -c.

END_HELP
    return;
}
my $args_legal = getopts('H:c:w:r:v', \%flags);
unless($args_legal){
    print "ERROR - invalid arguments received\n";
    exit 3;
}

# process required flags
my $hostname = $flags{'H'};
unless($hostname){
    print "ERROR - invalid arguments received\n";
    exit 3;
}

# process optional flags
my $critical = 10;
if($flags{'c'} && $flags{'c'} =~ m/^\d+$/sx){
    $critical = $flags{'c'}
}
my $warning = 33;
if($flags{'w'} && $flags{'w'} =~ m/^\d+$/sx){
    $warning = $flags{'w'};
}
## no critic (ProhibitNegativeExpressionsInUnlessAndUntilConditions);
unless($warning > $critical){
    $warning = $critical;
}
## use critic
my $r_warning = 33;
if($flags{'r'} && $flags{'r'} =~ m/^\d+$/sx){
    $r_warning = $flags{'r'};
}
my $timeout = 10;
if($flags{'t'} && $flags{'t'} =~ m/^\d+$/sx){
    $timeout = $flags{'t'};
}
#
# try get the data from the status page
#

# instantiate a parse object
my $prs = Parse::Apache::ServerStatus->new(
        url => "http://$hostname/server-status",
        timeout => $timeout,
);

# try get the status page form the server
my $stats;
eval{
    $stats = $prs->get or croak($prs->errstr);
    1; # force a true return on successful execution
}or do{
    # return a critical state
    print "CRITICAL - failed to access server status page ($EVAL_ERROR)\n";
    exit 2;
};

#
# Parse the result
#

# calcualte needed totals and percentages
my $total_slots = $stats->{'_'} + $stats->{'S'} + $stats->{'R'} + $stats->{'W'}
                  + $stats->{'K'}+ $stats->{'D'} + $stats->{'C'} + $stats->{'L'}
                  + $stats->{'G'} + $stats->{'I'} + $stats->{q{.}};
my $total_free = $stats->{'_'} + $stats->{q{.}};
my $percent_free = nearest(0.01, $total_free/$total_slots * 100);
my $percent_r    = nearest(0.01, $stats->{'R'}/$total_slots * 100);
my $req_per_sec = $stats->{'rs'};
if($req_per_sec =~ m/^[.]/sx){
	$req_per_sec = '0'.$req_per_sec;
}

my $performance_data = " | free_slots=${percent_free}%;${warning};${critical} r_slots=${percent_r}%;${r_warning} requests_per_sec=$req_per_sec";

# first deal with the critical state
if($percent_free < $critical){
    my $out = "CRITICAL - only ${percent_free}% ($total_free) of $total_slots slots free (";
    if($percent_r > $r_warning){
        $out .= 'WARNING - '
    }
    $out .= $stats->{'R'}." in R state) ${performance_data}\n";
    print $out;
    exit 2;
}

# then deal with the number of free slots being in a warning stage
if($percent_free < $warning){
    my $out = "WARNING - only ${percent_free}% ($total_free) of $total_slots slots free (";
    if($percent_r > $r_warning){
        $out .= 'WARNING - '
    }
    $out .= $stats->{'R'}." in R state) ${performance_data}\n";
    print $out;
    exit 1;
}

# finally deal with too many Rs
if($percent_r > $r_warning){
    print 'WARNING - '.$percent_r.'% of slots in R state ('.$stats->{'R'}." slots) - potential slowloris attack! (${percent_free}% = $total_free out of $total_slots slots free) ${performance_data}\n";
    exit 1;
}

# finally, if we got this far, all is well, so return success
print "OK - ${percent_free}% of slots free ($total_free out of $total_slots) - ${percent_r}% in R state ($stats->{R} slots) ${performance_data}\n";
exit 0;