adva_optical_snmp
=================

Some Adva Optical SNMP perl scripts.

The cp-tunnel-create and delete scripts can be used to create services over an Adva Optical network from a command line rather than via the FSP Manager. This can be useful and quicker than using the manager. Services(tunnels) created with the create script can then be dicovered and imported into the FSP Manager by completing an inventory check on the tunnel source box. 

Typically I use a bash script with the software version or the interface scripts to iterate over a large list of boxes. 
 
