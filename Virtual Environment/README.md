### Home Assistant Server

After some network issues, I have decided to have my Home Assistant server running locally, moving it away from my colocated server.
Latency hasn’t been an issue, but if there is no internet, then the automation will stop working, and I don’t want to have a backup internet connection when it is only the HA server that needs to be moved home.

I have been looking for various options, including making the changes to my Dream Machine SE, to allow HA to run in a Docker, but the previous times I have tried that, something will always break when updates are done on the UDM SE.
The latest version of this option can be found here, use with caution.

https://github.com/unifi-utilities/unifios-utilities/tree/main/nspawn-container

There are also lots of the "1L" machines that is a good option for running Home Assistant, and a rackmount kit is also possible for some of them.
An i3 with 8Gb and some SSD space are sufficient.  

https://www.servethehome.com/tag/tinyminimicro/

Also, lots of posts around using the new N100-based machines, there is more than enough power, but they are qurrently quite expensive, and I cannot find any rack-mount kits.
Sure all of the options above can be put on a shelf in the rack. (Not rack-mount in my book)

Then I found an older post on ServerBuilds.net where they are using older network/email/firewall/security Appliances to run pfSense or ONSense.

https://forums.serverbuilds.net/t/guide-spice-up-your-rack-with-these-stylish-sexy-chassis-for-your-pfsense-build/5273

Which got me thinking, I realy wanted a true rackmount server, if there were IPMI (OOBM) that is always a nice feature to have.
I found an Ebay seller that have lots of 1U rack servers based on the Supermicro CSE-512 case, unfortunately the seller doesn't ship to Denmark,
and I dont know anybody in Germany that could be used as a proxy the purchase.

https://www.ebay.com/sch/i.html?item=276181252711&rt=nc&_trksid=p4429486.m3561.l161211&_ssn=first-colo


### The PSA3000 is just what I needed for Home Assistant.

All of my searched ended up with this cool little box, Pulse Secure PSA3000 Security Appliance Firewall.
Which is based on the Intel Celeron J1900 that can handle 8 GB of memory, and the case have room for a couple of SSD disks for data storage (No Raid), and room for a pcie card

![PSA3000](https://github.com/SysAdminDk/HomeAssistant/blob/main/Virtual%20Environment/images/PSA3000.png?raw=true)


I have decided to run Home Assistant as a regular VM and for that reason decided to install Proxmox Virtual Environment.
How to prepare and install proxmox can be found here.

https://www.proxmox.com/en/proxmox-virtual-environment/get-started

To monitor power consumption of the host, have have put a Athom Smart plug infront of the PSU, and with full load I cannot get it ower 15W

