check_apache_serverstatus
=========================

A Nagios plugin which uses the Apache server-status page to check that the server has enough free slots. The plugin also checks for an excessive number of slots in the R state, which can be symptomatic of a slowloris-style denial of service attack.
