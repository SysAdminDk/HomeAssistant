### Home Assistant Server

After some network issues, I have decided to have my Home Assistant server running locally, moving it away from my colocated server.  
Latency hasn’t been an issue, but if there is no internet, then the automation will stop working, and I don’t want to have a backup internet connection when it is only the HA server that needs to be moved home.  

I have been looking for various options.  
  
1. Making changes to my Dream Machine SE, allowing HA and more to run in Docker, but the previous times I have tried that, something always breaks on updates the UDM SE.  
The latest version of this option can be found here, use with caution.  
https://github.com/unifi-utilities/unifios-utilities/tree/main/nspawn-container  
  
2. The "1L" machines thats great for running Home Assistant, and more, some of them also can be fitted in a rackmount kit.  
Any cheap one with an Intel I3 with 8Gb and 80GB SSD space are more than sufficient.  
https://www.servethehome.com/tag/tinyminimicro/  
  
3. Found lots of posts out there about using the new N100-based machines.  
Unfortunately I cannot find any rack-mount kits. (January 2024)  
  
Sure most of the options above can also be put on a shelf in the rack that is not rack-mount in my book.
  
4. Then I found an older post on ServerBuilds.net where they are using older network/email/firewall/security Appliances to run pfSense or ONSense.  
https://forums.serverbuilds.net/t/guide-spice-up-your-rack-with-these-stylish-sexy-chassis-for-your-pfsense-build/5273  
  
  
### Requirements   
That got me thinking about the requirements.  
  
1. 1U Rackmount server (Short Depth)  
2. CPU and Memory to run required services for Home Assistant.  
3. Front IO  
4. Lowpower (Under 20W)  
5. IPMI / ILO / IDrac, somekind of Out Off Band Management is nice feature.  

I then found an Ebay seller that have lots of 1U rack servers based on the Supermicro CSE-512 case.  
Unfortunately that case is a little to deep for my network rack, and the seller doesn't ship to Denmark, I dont know anybody in Germany that could be used as a proxy the purchase.  
https://www.ebay.com/sch/i.html?item=276181252711&rt=nc&_trksid=p4429486.m3561.l161211&_ssn=first-colo  
  
After that I figured it must be based on the Supermicro CSE-505 (Front I/O) or Supermicro CSE-504 (Rear I/O)
Browsing Ebay for CSE-504/505 based servers leed me to the Pulse Secure PSA3000/5000 Security Appliance Firewall.  
The PSA3000 is cheap 1U and there are multiple avalible on EBay.  
https://www.ebay.com/sch/i.html?_from=R40&_trksid=p2334524.m570.l1313&_nkw=Pulse+secure+PSA3000&_sacat=0&_odkw=PSA3000&_osacat=0  
  
  
### The PSA3000 is just what I needed for Home Assistant.  
  
I ended up with ordering one of this cool little box, and got one deliverd for less than $150.  
It is based on a Supermicro X10SBA-L motherboard with the Intel Celeron J1900 that can handle 8 GB of memory, the case have room for a couple of disks (No Raid), if the extra network card is removed, a pcie card.  
There is another version of that motherboard X10SBA with more SATA and mSATA, but for just running a couple of VMs the L version is just fine.  
Since the case is a custom version of the SuperChassis 505, and access to the other onboard network is wanted, a little customization is needed.  
  
![PSA3000](https://github.com/SysAdminDk/HomeAssistant/blob/main/Virtual%20Environment/images/PSA3000.png?raw=true)
  
  
I have decided to run Home Assistant as a regular VM and for that reason decided to install Proxmox Virtual Environment.  
How to prepare and install proxmox can be found here.  
https://www.proxmox.com/en/proxmox-virtual-environment/get-started
  
To monitor power consumption of the host, have have put a Athom Smart plug infront of the PSU, and with full load I cannot get it ower 15W  

A review of the motherbord can be found on Serve the Home.  
https://www.servethehome.com/supermicro-x10sba-review/
  
I am fully aware that the hardware platform is about 10 years old, but they are built for enterprise, and as loong as there is enouph power in the machine for my HA to run smooth, it will last.  
An extra for spare parts is also only around $150.  
  