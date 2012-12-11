## Downloading

You can grab the [script here](https://github.com/sanguis/vhostx/raw/master/vhostx.sh) (Option-click to download.)

## Credit!
This is a port of Patrick Gibson's fantastic virtualhost.sh that was written for Apache, this is based on the Ubuntu branch and is to far off from the scope of the original project to justify just a forked branch.

## Usage
1. Create a VirtualHost:
sudo ./vhostx <name>
where <name> is the one-word name you'd like to use. (e.g. mysite.dev)

Note that if "vhostx.sh" is not in your PATH, you will have to write
out the full path to where you've placed: eg. /usr/bin/vhostx.sh <name>

2. Remove a VirtualHost:
sudo ./vhost --delete <site>

where <site> is the site name you used when you first created the host.

## Script variables

If you are using this script on a production machine with a static IP address, and you wish to setup a "live" virtualhost, you can change the following '*' address to the IP address of your machine.

IP_ADDRESS="127.0.0.1"

By default, this script places files in /home/[username]/Sites. If you would like to change this uncomment the following line:

DOC_ROOT_PREFIX="/var/www"

There are more varables in the script besure to change them if needed.
