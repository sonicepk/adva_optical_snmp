#! /usr/bin/perl

use strict;
use Net::SNMP;

my ($session, $error) = Net::SNMP->session(
   -hostname  => shift || $ARGV[0],
   #-hostname  => shift || 'adva1',
   -community => shift || 'public',
   -port      => shift || 161 
);

if (!defined($session)) {
   printf("ERROR: %s.\n", $error);
   exit 1;
}

my $software_ver = '1.3.6.1.4.1.2544.1.11.2.2.1.5.0';

my $result = $session->get_request(
   -varbindlist => [$software_ver]
);

if (!defined($result)) {
   printf("ERROR: %s.\n", $session->error);
   $session->close;
   exit 1;
}

printf("software version for host '%s' is %s\n",
   $session->hostname, $result->{$software_ver} 
);

$session->close;

exit 0;
