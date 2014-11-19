#! /usr/bin/perl
# This script will return the status of all the client interfaces in an Adva FSP R7 network. This is useful for finding interfaces that are probably not used. 
#
# Written by eoinpk.ek@gmail.com
# 11/9/2014
# Version 0.1
use strict;
use Net::SNMP;

my $Src_TID = shift or Usage();

sub Usage{
        print STDERR "Usage: find_unused_interfaces.pl hostname\n";
        exit(1);
}

#printf ("The input arguments are:\n

#Step 1 find the Module Source Src_AID index
#
# Create the SNMP session
my ($session, $error) = Net::SNMP->session(
   -hostname  => $Src_TID,
   -community => 'public',
   -port      => 161,
   -version   => 'snmpv2c'
);

# Was the session created?
if (!defined($session)) {
   printf("ERROR: %s.\n", $error);
   exit 1;
}

#IF-MIB Interfaces table
#Name: ifDescr
#Oid:1.3.6.1.2.1.2.2.1.2
#Composed Type: DisplayString
#Base Type: OCTET STRING
#Status: current
#Access: read-only
#Kind: Column
#SMI Type: OBJECT-TYPE
#Size 0 .. 255
#Module: IF-MIB

my $OID_ifDescr = '.1.3.6.1.2.1.2.2.1.2';

my $mod_src_oid;

#printf("\n== Blocking ifDescr request : ifDescr \n");

my $result;

my $myhash_ref = {}; #define a hash reference

#want to match  CH-[1-9]-[0-9]{0,}-N. ie Only find Network interfaces on transponders. 
if (defined($result = $session->get_table(-baseoid => $OID_ifDescr))) {
   foreach my $oid (sort(keys(%{$result}))) {
    if ($result->{$oid} =~ /^CH-[1-9]-[0-9]{0,}-N*/){
        $mod_src_oid = substr($oid,21);
	$myhash_ref->{$mod_src_oid} = $result->{$oid};
        }
   }
   if(!defined $mod_src_oid){
        printf("ERROR: Unable to find OID \n");
        exit 1;
        }
}
else {
   printf("ERROR: %s.\n\n", $session->error());
   exit 1;
}
#

#Name: ifOperStatus
#Oid: 1.3.6.1.2.1.2.2.1.8
#Composed Type: Enumeration
#Base Type: ENUM
#Status: current
#Access: read-only
#Kind: Column
#SMI Type: OBJECT-TYPE
#Value List 
#up (1)
#down (2)
#testing (3)
#unknown (4)
#dormant (5)
#notPresent (6)
#lowerLayerDown (7)

my $OID_ifOperStatus = '.1.3.6.1.2.1.2.2.1.8';

my $interface_status;
print("Hostname:", $session->hostname());
for my $key (sort(keys(%$myhash_ref)))
	{
	my $OID_my_ifOperStatus = $OID_ifOperStatus.'.'.$key;
	if(defined ($interface_status = $session->get_request(-varbindlist => [$OID_my_ifOperStatus],))){
		for($interface_status->{$OID_my_ifOperStatus}){
			if($interface_status->{$OID_my_ifOperStatus} == 1){ printf("\nInterface %s = Up",$myhash_ref->{$key})}
			elsif($interface_status->{$OID_my_ifOperStatus} == 2){ printf("\nInterface %s = Down",$myhash_ref->{$key})}
			elsif($interface_status->{$OID_my_ifOperStatus} == 3){ printf("\nInterface %s = Testing",$myhash_ref->{$key})}
			elsif($interface_status->{$OID_my_ifOperStatus} == 4){ printf("\nInterface %s = Unknown",$myhash_ref->{$key})}
			elsif($interface_status->{$OID_my_ifOperStatus} == 5){ printf("\nInterface %s = Unknown",$myhash_ref->{$key})}
			elsif($interface_status->{$OID_my_ifOperStatus} == 6){ printf("\nInterface %s = Not Present",$myhash_ref->{$key})}
			elsif($interface_status->{$OID_my_ifOperStatus} == 7){ printf("\nInterface %s = Unknown",$myhash_ref->{$key})}
			else { printf("\nInterface %s = Unknown",$myhash_ref->{$key})}
		}
	}
else {
   printf("ERROR: %s.\n\n", $session->error());
   exit 1;
}
	}
print ("\n");

$session->close;
exit 0;

