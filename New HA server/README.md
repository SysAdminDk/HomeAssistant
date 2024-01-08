### Home Assistant Server

After some network issues, I have decided to have my Home Assistant server running locally, moving it away from the server I have hosted elsewhere.
Latency hasn’t been an issue, but if there is no internet, then the automation will stop working, and I don’t want to have a backup internet connection when it is only the HA server that needs to be moved home.

I have been looking for various options, including making the changes to my Dream Machine SE, to allow HA to run in a Docker, but the previous times I have tried that, something will break when updates are done on the UDM.
The latest version of this option can be found here.
unifios-utilities/nspawn-container at main · unifi-utilities/unifios-utilities (github.com)

There are also lots of the “1L” machines that are a good option for running Home Assistant, and a rackmount kit is also possible. An i3 with 8Gb and some SSD space are sufficient.  
TinyMiniMicro Archives - ServeTheHome

Also, lots of posts around using the new N100-based machines, there is more than enough power, but they are quite expensive, and I cannot find any rack-mount kits, other than just putting them on a shelf in the rack. (Not rack-mount in my book)

I found an older post on ServerBuilds.net where they are using older network/email/firewall/security Appliances to run pfSense or ONSense, which got me thinking 😊 and doing some eBay searching I ended up ordering a Pulse Secure PSA3000.

### The PSA3000 is just what I needed for Home Assistant.

The PSA3000 is based on the Intel Celeron J1900 with 8 GB of memory, with room for a couple of SSD disks for data storage.