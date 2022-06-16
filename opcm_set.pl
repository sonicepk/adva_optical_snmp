#! /usr/bin/env perl
#
#This script will let you set the attenuation level on an Adva Variable Attenuator Card OPM40
#
#Author:  eoinpk.ek@gmail.com
#Version 0.1
#
use strict;
use Net::SNMP;

my $Src_TID = shift or Usage();
my $Src_AID = shift or Usage();
my $VOA_DB = shift or Usage();

my $mod_src_oid;
my $mod_dest_oid;

#convert to upper case if not already
$Src_AID = uc $Src_AID;

sub Usage{
        print STDERR "Usage: opcm-set.pl Src_TID Module_Src_AID VOA x10 in dB\n
        example: ./opcm-set.pl 10.10.10.90 CH-1-2-N1 20 \n";
        exit(1);
}

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

#Entitiy table - required to find single port cards of the format MOD-X-X
#.1.3.6.1.4.1.2544.2.5.5.2.1.5
#entityIndexAid OBJECT-TYPE
#-- FROM       ADVA-MIB, ADVANEW-MIB
#-- TEXTUAL CONVENTION SnmpAdminString
#
my $OID_entityIndexAid = '.1.3.6.1.4.1.2544.2.5.5.2.1.5';

#ptpEntityIndexAid OBJECT-TYPE - required to find port cards of the format PTP-X-X-X
#    SYNTAX      SnmpAdminString
#    MAX-ACCESS  read-only
#    STATUS      current
#    DESCRIPTION
#        "Name"
#    ::=  { ptpEntityEntry 5 }
my $OID_ptpEntityIndexAid = '.1.3.6.1.4.1.2544.2.5.5.10.1.5';

#printf("\n== Blocking Get entity table request : entityIndexAid \n");

my $result;
my $Src_search_table;
my $strip;

if ($Src_AID =~ /^CH/){ $Src_search_table = $OID_entityIndexAid; $strip = 30;}

if (defined($result = $session->get_table(-baseoid => $Src_search_table))) {
   foreach my $oid (keys(%{$result})) {
    if ($result->{$oid} eq $Src_AID){
        $mod_src_oid = substr($oid,$strip);
	#        printf("Found Source AID index %s => %s :mod_src_oid %s\n", $oid, $result->{$oid}, $mod_src_oid);
        }
   }
   if(!defined $mod_src_oid){
        printf("ERROR: Unable to find Src_AID %s.\n", $Src_AID);
        exit 1;
        }
}
else {
   printf("ERROR: %s.\n\n", $session->error());
   exit 1;
}

$session->close;
#
#createAndWait. Then populate the entries for the tunnel ie AID indexes, type
#of connection etc.
#
my ($session, $error) = Net::SNMP->session(
   -hostname  => shift || $Src_TID,
   -community => shift || 'private',
   -port      => shift || 161,
);

if (!defined($session)) {
   printf("ERROR: %s.\n", $error);
   exit 1;
}
my $OID_deployProvIfVoaSetpoint = '.1.3.6.1.4.1.2544.1.11.2.5.4.1.1.80';

#printf "The set VOA for host '%s' is %s.\n",
              $session->hostname(), $OID_deployProvIfVoaSetpoint.'.'.$mod_src_oid;

my $result = $session->set_request(
   -varbindlist =>
   [
      $OID_deployProvIfVoaSetpoint.'.'.$mod_src_oid, UNSIGNED32, $VOA_DB
   ],
 );

 #    printf "Request queued for activation\n";

if (!defined $result) {
    printf "ERROR: Unable to create object or exists already Failed to queue
    set request for host '%s': %s.\n";
    $session->hostname(), $session->error();
    $session->close;
    exit 1;
     }
$session->close;

exit 0;
