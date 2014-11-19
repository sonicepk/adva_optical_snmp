#! /usr/bin/perl
#This script deletes a tunnel from one Adva Optical FSP3000 R7 ROADM node
#to another using SNMP and the Adva GMPLS control plane. 
#Adva MIBS version 8.3.x
#Tested on Adva FSP R7 software 8.3.1
#
# Errors/Corrections/Improvements to eoinpk.ek@gmail.com 
# Date: 11-9-2009
# cp-program-delete.pl
# Version 0.1
#
#There are 2 steps to deleting the tunnel:
# 1 - Find the tunnel OID and hence unique tunnel index. 
# 2 - Destroy the tunnel.
#
# This prints out the contents of all the tunnels created from this NE.
# snmpwalk -v2c -c public adva2 DeployProvTunnelWdmEntry
# Need to destroy a tunnel, make sure its admin state is PPS and then you can
# destroy the tunnel object.
# snmpset -v2c -c private adva2 deployProvTunnelWdmRowStatus.855638272 = 6
#
use strict;
use Net::SNMP;

my $Src_TID = shift or Usage();
my $Tunnel_name = shift or Usage();

#Step 1 find the Tunnel OID
my $tunnel_oid;

sub Usage{
        print STDERR "Usage: cp-tunnel-delete.pl Src_TID Tunnel_Name\n
        example: ./cp-tunnel-delete.pl adva1 Tunnel2 \n";
        exit(1);
}

#printf ("The input arguments are:\n Source hostname/TID %s\n
#         Tunnel Name %s \n ",$Src_TID, $Tunnel_name);

#
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

#DeployProvTunnelWdmEntry table
#.1.3.6.1.4.1.2544.1.11.2.5.8.14.1.2
#deployProvTunnelWdmTunnelId OBJECT-TYPE
#-- FROM       FspR7-MIB
#-- TEXTUAL CONVENTION SnmpAdminString
# SYNTAX        OCTET STRING (0..255)

my $OID_deployProvTunnelWdmTunnelId = '.1.3.6.1.4.1.2544.1.11.2.5.8.14.1.2';

printf("\n== Blocking get_table(): deployProvTunnelWdmTunnelId\n");

my $result;

if (defined($result = $session->get_table(-baseoid => $OID_deployProvTunnelWdmTunnelId))) {
   foreach my $oid (sort(keys(%{$result}))) {
   printf ("valid Tunnel names for host %s are: %s \n", $Src_TID, $result->{$oid});
    if ($result->{$oid} eq $Tunnel_name){
        $tunnel_oid = substr($oid,36);
        printf("Found tunnel OID %s => %s :tunnel_oid %s\n", $oid, $result->{$oid}, $tunnel_oid);
        }
   }
   if(!defined $tunnel_oid){
        printf("ERROR: Unable to find Tunnel_OID %s.\n", $Tunnel_name);
        exit 1;
        }
}
else {
   printf("ERROR: %s.\n\n", $session->error());
   exit 1;
}
$session->close;
#
#Step 2 Delete(Destroy) the tunnel using the tunnel_OID
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
my $OID_deployProvTunnelWdmRowStatus = '.1.3.6.1.4.1.2544.1.11.2.5.8.14.1.1';
#deployProvTunnelWdmRowStatus OBJECT-TYPE
#-- FROM       FspR7-MIB
#-- TEXTUAL CONVENTION RowStatus
# SYNTAX        INTEGER {active(1), notInService(2), notReady(3),
#createAndGo(4), createAndWait(5), destroy(6)}
#MAX-ACCESS    read-write
#STATUS        current
#DESCRIPTION   "RowStatus"
#::= { iso(1) org(3) dod(6) internet(1) private(4)
#enterprises(1) advaMIB(2544) products(1) fspR7(11)
#fspR7MIB(2) deploymentProvisioningMIB(5)
#controlPlaneDeployProv(8) deployProvTunnelWdmTable(14)
#deployProvTunnelWdmEntry(1) 1 }

my $result = $session->set_request(
   -varbindlist =>
   [
      $OID_deployProvTunnelWdmRowStatus.'.'.$tunnel_oid, INTEGER, '6',
   ],
 );

if (defined $result) {
     for my $key (keys %{$result}){
        my $d_oid = $result->{$key};
                if ($d_oid eq 6) {
                printf "Tunnel deleted successfully\n",
                }
                else{
                printf "Somthing is wrong - check!\n",
                }
      }
}else{
    printf "ERROR: Unable to delete object or tunnel does not exist:\n '%s': %s.\n";
    $session->hostname(), $session->error();
    $session->close;
    exit 1;
     }
     
$session->close;

exit 0;
