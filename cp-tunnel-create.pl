#! /usr/bin/perl
#This script creates a tunnel(typically a 10G) from one Adva Optical FSP3000 R7 ROADM node
#to another using SNMP and the Adva GMPLS control plane. 
#Adva MIBS version 8.3.x
#Tested on Adva FSP R7 software 8.3.1 & 12.2.3.
#
# Errors/Corrections/Improvements to eoinpk.ek@gmail.com 
# Date: 11-9-2009, updated 16/9/2014.
# cp-program-create.pl
# Version 0.2
#
#There are 5 steps to creating the tunnel:
# 1 - Find the unique entity index (AID) for the source and destination modules. 
# 2 - Find the next available tunnel index ie unusedWdmTunnelIndex.
# 3 - Create the tunnel object using the information from 1 and 2 and some
# predefined parammeters like the type of circuit ie 10GE
# 4 - Activate the tunnel
# 5 - Put the tunnel into service if required. Can also be done via the element
# manager.
#
# Notes: We are using the TID(Target ID) rather than the IP addresses of the NEs.
# One side affect of using the TID for this script is that the hostname of the
# NE must be the same as the TID. 
# For example: ./cp-tunnel.pl adva1 adva2 MOD-1-6 MOD-1-6 Tunnel2
# adva1 must resolve to the IP address of the NE with a TID of adva1.
# This prints out the contents of all the tunnels starting from this NE.
# snmpwalk -v2c -c public adva2 DeployProvTunnelWdmEntry
# Need to destroy a tunnel, make sure its admin state is PPS and then you can
# destroy the tunnel object. Make sure to be using the correct tunnel index.
# snmpset -v2c -c private adva2 deployProvTunnelWdmRowStatus.855638272 = 6
# The last snmp session in this script will change the admin state of the
# tunnel from PPS to IS. Comment out if you only want to create the tunnel and
# not change its admin state.
 
use strict;
use Net::SNMP;

my $Src_TID = shift or Usage();
my $Dest_TID = shift or Usage();
my $Src_AID = shift or Usage();
my $Dest_AID = shift or Usage();
my $Tunnel_name = shift or Usage();

my $mod_src_oid;
my $mod_dest_oid;

#convert to upper case if not already
$Src_AID = uc $Src_AID;
$Dest_AID = uc $Dest_AID;

sub Usage{
        print STDERR "Usage: cp-tunnel-create.pl Src_TID Dest_TID Module_Src_AID Module_Dest_AID Tunnel_Name\n
        example: ./cp-tunnel-create.pl adva1 adva2 MOD-1-6 MOD-1-6 Tunnel2 \n
	example: ./cp-tunnel-create.pl adva1 adva2 PTP-1-14-NE MOD-1-6 Tunnel3\n
        Note1: Tunnel name must be unique.
	Note2: Single port cards use AID of MOD-X-X while multiport use PTP-X-X-XX\n";
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

printf("\n== Blocking Get entity table request : entityIndexAid \n");

my $result;
my $Src_search_table;
my $strip;

if ($Src_AID =~ /^MOD/){ $Src_search_table = $OID_entityIndexAid; $strip = 30;}
if ($Src_AID =~ /^PTP/){ $Src_search_table = $OID_ptpEntityIndexAid; $strip = 31;}


if (defined($result = $session->get_table(-baseoid => $Src_search_table))) {
   foreach my $oid (keys(%{$result})) {
    if ($result->{$oid} eq $Src_AID){
        $mod_src_oid = substr($oid,$strip);
        printf("Found Source AID index %s => %s :mod_src_oid %s\n", $oid, $result->{$oid}, $mod_src_oid);
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
#Step 1a find the Module Destination Dest_AID index
#
# Create the SNMP session
my ($session, $error) = Net::SNMP->session(
   -hostname  => $Dest_TID,
   -community => 'public',
   -port      => 161,
   -version   => 'snmpv2c'
);

# Was the session created?
if (!defined($session)) {
   printf("ERROR: %s.\n", $error);
   exit 1;
}

#Entitiy table
#.1.3.6.1.4.1.2544.2.5.5.2.1.5
#entityIndexAid OBJECT-TYPE
#-- FROM       ADVA-MIB, ADVANEW-MIB
#-- TEXTUAL CONVENTION SnmpAdminString
#
my $OID_entityIndexAid = '.1.3.6.1.4.1.2544.2.5.5.2.1.5';

printf("\n== Blocking get entity table request: entityIndexAid\n");

my $result;
my $Dst_search_table;
if ($Dest_AID =~ /^MOD/){ $Dst_search_table = $OID_entityIndexAid; $strip = 30;}
if ($Dest_AID =~ /^PTP/){ $Dst_search_table = $OID_ptpEntityIndexAid; $strip = 31;}

if (defined($result = $session->get_table(-baseoid =>$Dst_search_table))) {
   foreach my $oid (keys(%{$result})) {
   #find the oid that matches the AID in the table,
    if ($result->{$oid} eq $Dest_AID){
        $mod_dest_oid = substr($oid,$strip);#truncate the oid to the index only.
        printf("Found Destination AID index %s => %s :mod_dest_oid %s\n", $oid, $result->{$oid}, $mod_dest_oid);
        }
   }     
    if(!defined $mod_dest_oid){
        printf("ERROR: Unable to find Dest_AID %s\n", $Dest_AID);
        exit 1;
        }
}
else {
   printf("ERROR: %s.\n\n", $session->error());
   exit 1;
}

$session->close;
#
# Step 2 fine the next available tunnel index
#
# we need to find the next available tunnel index id available for
# provisioning.
# FROM       FspR7-MIB
# SYNTAX        Unsigned32
# MAX-ACCESS    read-only
# STATUS        current
# DESCRIPTION   "This object is used to retrieve unused tunnel ID for
# provisioning purpose."
# ::= { iso(1) org(3) dod(6) internet(1) private(4) enterprises(1)
# advaMIB(2544) products(1) fspR7(11) fspR7MIB(2)
# deploymentProvisioningMIB(5) controlPlaneDeployProv(8) 1 }
#
my ($session, $error) = Net::SNMP->session(
   -hostname  => shift || $Src_TID,
   -community => shift || 'private',
   -port      => shift || 161,
);

if (!defined($session)) {
   printf("ERROR: Fails first session %s.\n", $error);
   exit 1;
}

my $OID_unusedWdmTunnelIndex = '.1.3.6.1.4.1.2544.1.11.2.5.8.1.0';

my $result = $session->get_request(
   -varbindlist => [$OID_unusedWdmTunnelIndex]
);

if (!defined($result)) {
   printf("ERROR: %s.\n", $session->error);
   $session->close;
   exit 1;
}

my $new_tunnel_index = $result->{$OID_unusedWdmTunnelIndex};

$session->close;

printf("The new_tunnel_index is %s.\n", $new_tunnel_index);

#
#Step 3 create the tunnel object first using by setting RowStatus to 5
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
my $OID_deployProvTunnelWdmRowStatus = '.1.3.6.1.4.1.2544.1.11.2.5.8.14.1.1';
#my $OID_deployProvTunnelWdmRowStatus = '.1.3.6.1.4.1.2544.1.11.2.5.8.46.1.1';
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

my $OID_deployProvTunnelWdmTunnelId = '.1.3.6.1.4.1.2544.1.11.2.5.8.14.1.2';
#TunnelId is just text ie vis_SNMP
my $OID_deployProvTunnelWdmTunnelType = '.1.3.6.1.4.1.2544.1.11.2.5.8.14.1.5';
#TunnelType is either {undefined(0), p2p(1)
my $OID_deployProvTunnelWdmTunnelNo = '.1.3.6.1.4.1.2544.1.11.2.5.8.14.1.3';
#TunnelNo is 0
my $OID_deployProvTunnelWdmToTid = '.1.3.6.1.4.1.2544.1.11.2.5.8.14.1.6';
#TunnelWdmToTid is the Target id of the tunnel endpoint, rather than the
#IP address. We use the Tid.
my $OID_deployProvTunnelWdmConnectionDirection = '.1.3.6.1.4.1.2544.1.11.2.5.8.14.1.10';
#{undefined(0), bi(1), uni(2)
my $OID_deployProvTunnelWdmFacilityType = '.1.3.6.1.4.1.2544.1.11.2.5.8.14.1.11';
#we use ifTypeOtu2Lan(76)
my $OID_deployProvTunnelWdmTerminationLevel = '.1.3.6.1.4.1.2544.1.11.2.5.8.14.1.12';
#{undefined(0), phys(1), otnOtu(2), otnOdu(3), otnOpu(4),
#sonetSection(5), sonetLine(6), sonetPath(7), none(8) we use Opu
#termination for 10GE LAN.
my $OID_deployProvTunnelWdmFecType = '.1.3.6.1.4.1.2544.1.11.2.5.8.14.1.13';
#{undefined(0), gFec(1), eFec(2), noFec(3), eFec1(4), eFec2(5), eFec3(6)
#we use gfec(1).
my $OID_deployProvTunnelWdmStuff = '.1.3.6.1.4.1.2544.1.11.2.5.8.14.1.14';
#{undefined(0), yes(1), no(2). We use stuffing 1.
my $OID_deployProvTunnelWdmRecoveryType = '.1.3.6.1.4.1.2544.1.11.2.5.8.14.1.16';
#{undefined(0), none(1), protection(2), protectionMust(3), restoration(4).
#we use none(1).
my $OID_deployProvTunnelWdmFromAid = '.1.3.6.1.4.1.2544.1.11.2.5.8.14.1.8';
#From Aid this is MOD-1-5 for example.
my $OID_deployProvTunnelWdmToAid = '.1.3.6.1.4.1.2544.1.11.2.5.8.14.1.9';
#To Aid. MOD-1-7 is 101320448. Add 256 for MOD‐1-8.

printf "The new_oid_for_tunnel_index for host '%s' is %s.\n",
              $session->hostname(), $OID_deployProvTunnelWdmRowStatus.'.'.$new_tunnel_index;

my $result = $session->set_request(
   -varbindlist =>
   [
      $OID_deployProvTunnelWdmRowStatus.'.'.$new_tunnel_index, INTEGER, '5',
      $OID_deployProvTunnelWdmTunnelId.'.'.$new_tunnel_index, OCTET_STRING, $Tunnel_name,
      $OID_deployProvTunnelWdmTunnelType.'.'.$new_tunnel_index, INTEGER, '1',
      $OID_deployProvTunnelWdmTunnelNo.'.'.$new_tunnel_index, UNSIGNED32, '0',
      $OID_deployProvTunnelWdmToTid.'.'.$new_tunnel_index, OCTET_STRING,$Dest_TID,
      $OID_deployProvTunnelWdmConnectionDirection.'.'.$new_tunnel_index, INTEGER, '1',
      $OID_deployProvTunnelWdmFacilityType.'.'.$new_tunnel_index, INTEGER, '76',
      $OID_deployProvTunnelWdmTerminationLevel.'.'.$new_tunnel_index, INTEGER, '4',
      $OID_deployProvTunnelWdmFecType.'.'.$new_tunnel_index, INTEGER, '1',
      $OID_deployProvTunnelWdmStuff.'.'.$new_tunnel_index, INTEGER, '1',
      $OID_deployProvTunnelWdmRecoveryType.'.'.$new_tunnel_index, INTEGER, '1',
      $OID_deployProvTunnelWdmFromAid.'.'.$new_tunnel_index, INTEGER32, $mod_src_oid,
      $OID_deployProvTunnelWdmToAid.'.'.$new_tunnel_index, INTEGER32, $mod_dest_oid,
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

#
#Step 4 - make the created tunnel object active. It will now appear in the Adva
#element manager control plane tunnel table.
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

my $result = $session->set_request(
   -varbindlist =>
   [
   $OID_deployProvTunnelWdmRowStatus.'.'.$new_tunnel_index, INTEGER, '1',
   ],
);
# check the results
if (defined $result) {
     for my $key (keys %{$result}){
        my $value = $result->{$key};
                if ($value eq 1) {
                printf "Tunnel created successfully:\n",
                }
                else{
                printf "Something is wrong - Check:\n",
                }
      }
}


if (!defined $result) {
    printf "ERROR: Failed to queue set request for host '%s' or unable to
    activate the tunnel. Is the Tunnel name unique?: %s.\n";
    $session->hostname(), $session->error();
    $session->close;
    exit 1;
     }

$session->close;

#In this session we can put the tunnel into service if required. You may not want
#to automatically do this. Equalisation of all roadms involved in the tunnel 
#will automatically be done on putting the tunnel into service.

#my ($session, $error) = Net::SNMP->session(
#   -hostname  => shift || $Src_TID,
#   -community => shift || 'private',
#   -port      => shift || 161,
#);

#if (!defined($session)) {
#   printf("ERROR: %s.\n", $error);
#   exit 1;
#}
#my $OID_controlPlaneWdmEntityStateAdmin = '.1.3.6.1.4.1.2544.1.11.2.4.1.3.1.1';
#controlPlaneWdmEntityStateAdmin OBJECT-TYPE
#-- FROM       FspR7-MIB
#-- TEXTUAL CONVENTION FspR7AdminState
#SYNTAX        INTEGER {undefined(0), uas(1), is(2), ains(3), mgt(4),
#mt(5), dsbld(6), pps(7)}
#
#my $result = $session->set_request(
#   -varbindlist =>
#   [
#   $OID_controlPlaneWdmEntityStateAdmin.'.'.$new_tunnel_index, INTEGER, '2'
#   ],
#);
#
# check the results
#if (defined $result) {
#     for my $key (keys %{$result}){
#        my $value = $result->{$key};
#                if ($value eq 2) {
#                printf "Tunnel put in service successfully:\n",
#                }
#                else{
#                printf "Something is wrong - Check:\n",
#                }
#      }
#}
#if (!defined $result) {
#    printf "ERROR: Failed to queue set request for host '%s': %s.\n",
#    $session->hostname(), $session->error();
#    $session->close;
#    exit 1;
#     }
#
#
exit 0;
