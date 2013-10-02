check_apache_serverstatus
=========================

A Nagios plugin which uses the Apache server-status page to check that the 
server has enough free slots. The plugin also checks for an excessive number of
slots in the R (reading request) state, which can be symptomatic of a 
slowloris-style denial of service attack.

Usage
-----

Basic Usage:

    check_apache_serverstatus.pl -H [IP]
    
Show full list of available options:

    check_apache_serverstatus.pl --help
    
Prerequisites
-------------

1. The target Apache server must have mod_status enabled and visible at
   `http://[IP]/server-status`, and access to the server status page must
   be permitted from the Nagios server's IP.

2. The Nagios server must have the following Perl libraries installed 
   (all available from CPAN):
    - `Carp`
    - `Getopt::Std`
    - `Parse::Apache::ServerStatus`
    - `Math::Round`
    
Example Apache Config
---------------------

A sample of how Apache can be configured to enalbe the server status page. It
would be advisible to add this in a separate `.config` file in the `conf.d` 
folder rater than directly in `httpd.conf`:

    # This allows nagios to monitor apache
    ExtendedStatus On

    <Location /server-status>
    SetHandler server-status

    Order Deny,Allow
    Deny from all
    Allow from [nagios_server_ip] [other_trusted_ip(s)]
    </Location>
    
Example Nagios Check Command
----------------------------

    # check Apache status
    define command{
        command_name    check_apache_status
        command_line    /usr/lib/nagios/plugins/check_apache_serverstatus.pl -H $HOSTADDRESS$
    }