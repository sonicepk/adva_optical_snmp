#! /usr/bin/env perl
# This script will return the Set Attenuation Levels for an Adva OPCM card.  
#
# Written by eoinpk.ek@gmail.com
# 16/6/2022 
# Version 0.1
use strict;
use Net::SNMP;

my $Src_TID = shift or Usage();

sub Usage{
        print STDERR "Usage: opcm_read.pl hostname\n";
        exit(1);
}

#Find the Module Source Src_AID index
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

#opticalIfDiagAttenuationOfVoa OBJECT-TYPE
#    SYNTAX        Unsigned32
#    UNITS         "0.1 dB"
#    MAX-ACCESS    read-only
#    STATUS        current
#    DESCRIPTION   "Variable Attenuator attenuation in dB"
#    ::= { opticalIfDiagEntry 10 }
#

my $OID_opticalIfDiagAttenuationOfVoa = '.1.3.6.1.4.1.2544.1.11.2.4.3.5.1.10';

my $Interface_VOA;
print("Hostname:", $session->hostname());
for my $key (sort(keys(%$myhash_ref)))
	{
	my $OID_ch_opticalIfDiagAttenuationOfVoa = $OID_opticalIfDiagAttenuationOfVoa.'.'.$key;
	if(defined ($Interface_VOA = $session->get_request(-varbindlist => [$OID_ch_opticalIfDiagAttenuationOfVoa],))){
	printf("\nInterface %s = %1.1fdB",$myhash_ref->{$key},$Interface_VOA->{$OID_ch_opticalIfDiagAttenuationOfVoa}/10)}
else {
   printf("ERROR: %s.\n\n", $session->error());
   exit 1;
}
	}
print ("\n");

$session->close;
exit 0;

