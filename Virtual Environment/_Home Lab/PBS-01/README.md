# Description.
I have a couple of servers that are used for diffrent stuff, and I want to have valid backups of all my VMs.  
   
   
# Download Proxmox Backup Server  
Get the installer iso : https://www.proxmox.com/en/downloads/proxmox-backup-server/iso  
   
   
## Create VM
On PVE Host : IoT-01 -> Create VM
 - VM Id : 101
 - VM Name : PBS-01
 - ISO Image : proxmox-backup-server_3.1-1.iso
 - Disk Size : 32Gb
 - CPU Cores : 2
 - Type : Host
 - Memory : 4096
   
   
## Installation
1. Install Pboxmox Backup Server (Graphical)
2. Agree to the End USer License.
3. Select the drive where PBS are to be installed (32Gib QEMU Harddisk)
4. Change Country, Time zone and Keyboard Layout to match your need.
   > Denmark  
   > Europe/Copenhagen  
   > Danish  
5. Enter "root" password and a valid email address.
   > P@ssw0rd!  
   > My.Email@MyDomain.dk  
6. Select the Management interface and Enter Hostname, Ip Address, Gateway and DNS server.
   > ENS18  
   > PBS-01.MyDomain.local  
   > 10.10.10.11  
   > 10.10.10.1  
   > 1.1.1.1  
7. Install....
   
8. Open the website of new installed PBS.
   > https://10.10.10.11:8007
9. Login with "root" and supplied password.
   
   
### Proxmox post install scripts.  
Add the nessesary repos, and update PBS.
[Proxmox Backup Server - Post install](https://github.com/tteck/Proxmox/blob/main/misc/post-pbs-install.sh)  

`bash -c "$(wget -qLO - https://github.com/tteck/Proxmox/raw/main/misc/post-pbs-install.sh)"`  
   
   
## Configuration
If DHCP were selected during installation, the IP can be changed here.  
-> Configuration -> Network interfaces -> ens18 -> Edit
  > Assign IP : 10.10.10.11/24  
  > Gateway : 10.10.10.1  
   
   
### Create Users
The user is used to connect to PBS from PVE hosts.  
-> Access Control -> User Management -> Add
  > Name : Backup  
  > Realm : PBS  
  > Password : P@ssw0rd!  
   
   
### Backup Disk
On PVE Host : IoT-01 add the 2Tb backup disk to PBS-01.  
`ls -l /dev/disk/by-id/ata-WDC*`  
`qm set 101 -scsi2 /dev/disk/by-id/ata-WDC_?????????????????????????`  
   
   
### Replica Disk ( Has been changed, need to document )
I use SSHFS to map a Virtual disk image on my UDM-SE to the PBS server.  
   
On UDM-SE : Create "Replica" volume.  
I have a 14Tb drive and only need about 10Tb for Protect.  
> Enable SSH on UDM-SE, not part of this "guide"   
   
#  - `mkdir /volume1/pbs-replica`
#  - `mkdir /volume1/pbs-replica/mount`
  
  - `truncate /volume1/pbs-replica/disk-image.raw -s 1T`
  - `mke2fs -t ext4 -F /volume1/pbs-replica/disk-image.raw`
#  - `vi /etc/fstab`  
#    `/volume1/pbs-replica/disk-image.raw    /volume1/pbs-replica/mount  ext4    rw,relatime`
#  - `mount image.raw`
#  - `systemctl daemon-reload`
  
#  - Verify with mount output.
#    /volume1/pbs-replica/disk-image.raw on /volume1/pbs-replica/mount type ext4 (rw,relatime)
  
#    `df -h | grep pbs-replica`   
#    Filesystem                         Size  Used Avail Use% Mounted on  
#    /dev/loop1                         xxxT  xxxG  xxxG  xx% /volume1/pbs-replica/mount  
  
  
#### If there ever is a need to EXPAND the image.
1. Shutdown PBS
2. umount /volume1/replica-data/mount
3. truncate /volume1/replica-data/image/image.raw -s 3T   
   > Change the size to your need
4. parted /volume1/replica-data/image/image.raw resizepart 1 3299G   
   > If the max size is not supplied parted will ask
5. mount /volume1/replica-data/mount
6. resize2fs /dev/loop1
7. Start PBS
  
  
  
### Allow password less SSH from PBS to USM-SE
On PBS-01
- ssh-keygen -t rsa -b 4096 -f /root/.ssh/id_rsa.pub
  > Do NOT enter a passphrase.
- ssh-copy-id root@10.36.1.1
  
- mkdir /mnt/datastore/replica
- apt-get install sshfs
- vi /etc/fstab
  `sshfs#root@10.36.1.1:/volume1/replica-data/mount /mnt/datastore/replica fuse _netdev,rw,allow_other,reconnect,user,kernel_cache,auto_cache 0 0`
  
  
### Add Datastore ??
On PBS-01
-> Administration -> Directory -> Create: Directory
  > /dev/sdb
  > ext4
  > Backup
  > Add as Datastore

-> Datastore -> Add Datastore
  > Name : Replica
  > Backing Path : /mnt/replica

### Sync Job
On PBS-01
-> Datastore -> Sync Jobs -> Add
  > Local Datastore : Replica  
  > Location : Local  
  > Source Datastore : Backup  
  > Sync Schedule : Every day 00:00  
  > Remove vanished : True  


