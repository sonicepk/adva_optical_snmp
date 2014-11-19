#!/usr/bin/env perl

use strict;
use warnings;

use Net::SNMP;

my $OID_sysUpTime = '1.3.6.1.2.1.1.3.0';
my $OID_sysContact = '1.3.6.1.2.1.1.4.0';
my $OID_sysLocation = '1.3.6.1.2.1.1.6.0';

# Hash of hosts and location data.

my %host_data = (
   '192.168.1.1'  => 'testlab',
   '192.168.1.2'  => 'testlab',
   '192.168.1.3'  => 'testlab',
);

# Create a session for each host and queue a get-request for sysUpTime.

for my $host (keys %host_data) {

   my ($session, $error) = Net::SNMP->session(
      -hostname    => $host,
      -community   => 'private',
      -nonblocking => 1,
   );

   if (!defined $session) {
      printf "ERROR: Failed to create session for host '%s': %s.\n",
             $host, $error;
      next;
   }

   my $result = $session->get_request(
      -varbindlist => [ $OID_sysUpTime ],
      -callback    => [ \&get_callback, $host_data{$host} ],
   );

   if (!defined $result) {
      printf "ERROR: Failed to queue get request for host '%s': %s.\n",
             $session->hostname(), $session->error();
   }

}

# Now initiate the SNMP message exchange.

snmp_dispatcher();

exit 0;

sub get_callback
{
   my ($session, $location) = @_;

   my $result = $session->var_bind_list();

   if (!defined $result) {
      printf "ERROR: Get request failed for host '%s': %s.\n",
             $session->hostname(), $session->error();
      return;
   }

   printf "The sysUpTime for host '%s' is %s.\n",
           $session->hostname(), $result->{$OID_sysUpTime};

   # Now set the sysContact and sysLocation for the host.

   $result = $session->set_request(
      -varbindlist =>
      [
         $OID_sysContact,  OCTET_STRING, 'my_name',
         $OID_sysLocation, OCTET_STRING, $location,
      ],
      -callback    => \&set_callback,
   );

   if (!defined $result) {
      printf "ERROR: Failed to queue set request for host '%s': %s.\n",
             $session->hostname(), $session->error();
   }

   return;
}

sub set_callback
{
   my ($session) = @_;

   my $result = $session->var_bind_list();

   if (defined $result) {
      printf "The sysContact for host '%s' was set to '%s'.\n",
             $session->hostname(), $result->{$OID_sysContact};
      printf "The sysLocation for host '%s' was set to '%s'.\n",
             $session->hostname(), $result->{$OID_sysLocation};
   } else {
      printf "ERROR: Set request failed for host '%s': %s.\n",
             $session->hostname(), $session->error();
   }

   return;
}
