#!/bin/sh

# vhostx
#
# Is a nice little script to setup a new virtualhost in Ubuntu based upon the
# excellent virtualhost script by Patrick Gibson <patrick@patrickg.com> for OS X.
#
# This script has been updated to work on Mint 13 with 
# Nginx and probably works on Debian as well, but this has
# not been tested (yet). Feel free to test it on other Linux distributions, and
# let me know so that I can update the compatibility list in the read me.
# If you encounter any issues feel free to post bugreports & patches to
# https://github.com/sanguis/vhostx/issues

# == SCRIPT VARIABLES ==
#
# If you are using this script on a production machine with a static IP address,
# and you wish to setup a "live" virtualhost, you can change the following '*'
# address to the IP address of your machine.
 IP_ADDRESS="127.0.0.1"
#
# By default, this script places files in /home/[username]/Sites. If you would like
# to change this uncomment the following line:
#
#DOC_ROOT_PREFIX="/var/www"
#
# Configure the nginx-related paths if these defaults do not work for you.
#
 NGINX_CONFIG_PORTS="ports.conf"
 NGINX_CONFIG_FILENAME="nginx.conf"
 NGINX_CONFIG="/etc/nginx"
 NGINX_BIN="/etc/init.d/nginx"
#
# Set the virtual host configuration directory
 NGINX_VIRTUAL_HOSTS_ENABLED="sites-enabled"
 NGINX_VIRTUAL_HOSTS_AVAILABLE="sites-available"
#
# By default, use the site folders that get created will be owned by this group
 OWNER_GROUP="www-data"
#
# don't want to be nagged about "fixing" your DocumentRoot?  Set this to "yes".
 SKIP_DOCUMENT_ROOT_CHECK="yes"
#
# If Nginx works on a different port than the default 80, set it here
 NGINX_PORT="80"
#
# Set the errorlog for the VirtualHost
 ERROR_LOG="/var/log/nginx"

# Set to yes, if you want the script to create an index.html file 
# NB: If there's no index.html or index.php the script will add one 
 CREATE_INDEX="no"

# == DO NOT EDIT BELOW THIS lINE UNLESS YOU KNOW WHAT YOU ARE DOING ==
# Ubuntu version dash script version. do not change!
VERSION=".1"

if [ `whoami` != 'root' ]; then
    echo "You must be running with root privileges to run this script."
    echo "Enter your password to continue..."
    sudo $0 $* || exit 1
fi

if [ -z $USER -o $USER = "root" ]; then
    if [ ! -z $SUDO_USER ]; then
        USER=$SUDO_USER
    else
        USER=""
        echo "ALERT! Your root shell did not provide your username."
        while : ; do
            if [ -z $USER ]; then
                while : ; do
                    echo -n "Please enter *your* username: "
                    read USER
                    if [ -d /Users/$USER ]; then
                        break
                    else
                        echo "$USER is not a valid username."
                    fi
                done
            else
                break
            fi
        done
    fi
fi

if [ -z $DOC_ROOT_PREFIX ]; then
    DOC_ROOT_PREFIX="/home/$USER/Sites"
fi

usage()
{
    cat << __EOT
    Usage: sudo vhostx.sh <name>
    sudo vhostx.sh --delete <name>
    where <name> is the one-word name you'd like to use. (e.g. mysite)

    Note that if "vhostx.sh" is not in your PATH, you will have to write
    out the full path to it: eg. /Users/$USER/Desktop/vhostx.sh <name>

__EOT
    exit 1
}

if [ -z $1 ]; then
    usage
else
    if [ $1 = "--delete" ]; then
        if [ -z $2 ]; then
            usage
        else
            VIRTUALHOST=$2
            DELETE=0
        fi
    elif [ $1 = "--version" ]; then 
        echo "vhostx version: "$VERSION
        exit 1
    else
        VIRTUALHOST=$1
    fi
fi

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Delete the virtualhost if that's the requested action
#
if [ ! -z $DELETE ]; then
    echo -n "- Deleting virtualhost, $VIRTUALHOST... Continue? [Y/n]: "
    
    read continue

    case $continue in
        n*|N*) exit
    esac

    if grep -q -E "$VIRTUALHOST$" /etc/hosts ; then
        echo "  - Removing $VIRTUALHOST from /etc/hosts..."
        echo -n "  * Backing up current /etc/hosts as /etc/hosts.original..."
        cp /etc/hosts /etc/hosts.original
        sed "/$IP_ADDRESS\t$VIRTUALHOST/d" /etc/hosts > /etc/hosts2
        mv -f /etc/hosts2 /etc/hosts
        echo "done"

        if [ -e $NGINX_CONFIG/$NGINX_VIRTUAL_HOSTS_ENABLED/$VIRTUALHOST ]; then
            DOCUMENT_ROOT=`grep DocumentRoot $NGINX_CONFIG/$NGINX_VIRTUAL_HOSTS_ENABLED/$VIRTUALHOST | awk '{print $2}'`

            if [ -d $DOCUMENT_ROOT ]; then
                echo -n "  + Found DocumentRoot $DOCUMENT_ROOT. Delete this folder? [y/N]: "

                read resp

                case $resp in
                    y*|Y*)
                        echo -n "  - Deleting folder... "
                        if rm -rf $DOCUMENT_ROOT ; then
                            echo "done"
                        else
                            echo "Could not delete $DOCUMENT_ROOT"
                        fi
                        ;;
                esac
            fi
                echo -n "  - Deleting virtualhost file... ($NGINX_CONFIG/$NGINX_VIRTUAL_HOSTS_ENABLED/$VIRTUALHOST) and ($NGINX_CONFIG/$NGINX_VIRTUAL_HOSTS_AVAILABLE/$VIRTUALHOST) "
                rm $NGINX_CONFIG/$NGINX_VIRTUAL_HOSTS_ENABLED/$VIRTUALHOST
                rm $NGINX_CONFIG/$NGINX_VIRTUAL_HOSTS_AVAILABLE/$VIRTUALHOST
                echo "done"

                echo -n "+ Restarting Nginx... "
                $NGINX_BIN restart
                echo "done"
        fi
    else
        echo "- Virtualhost $VIRTUALHOST does not currently exist. Aborting..."
    fi

    exit
fi


FIRSTNAME=`pinky | awk '{print $2}' | tail -n 1`
cat << __EOT
Hi $FIRSTNAME! Welcome to vhostx.sh. This script will guide you through setting
up a name-based virtualhost
__EOT

echo -n "Do you wish to continue? [Y/n]: "

read continue

case $continue in
    n*|N*) exit
esac


# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Make sure $NGINX_CONFIG/$NGINX_CONFIG_FILENAME is ready for virtual hosting...
#
# If it's not, we will:
#
# a) Backup the original to $NGINX_CONFIG/$NGINX_CONFIG_FILENAME.original
# b) Add a NameVirtualHost 127.0.0.1 line
# c) Create $NGINX_CONFIG/virtualhosts/ (virtualhost definition files reside here)
# d) Add a line to include all files in $NGINX_CONFIG/virtualhosts/
# e) Create a _localhost file for the default "localhost" virtualhost
#
        if [ ! -d $NGINX_CONFIG/$NGINX_VIRTUAL_HOSTS_ENABLED ]; then
            mkdir $NGINX_CONFIG/$NGINX_VIRTUAL_HOSTS_ENABLED
        fi

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# If the virtualhost is not already defined in /etc/hosts, define it...
#
if grep -q -E "^$VIRTUALHOST" /etc/hosts ; then

    echo "- $VIRTUALHOST already exists."
    echo -n "Do you want to replace this configuration? [Y/n] "
    read resp

    case $resp in
        n*|N*)	exit
            ;;
    esac

else
    if [ $IP_ADDRESS != "127.0.0.1" ]; then
        cat << _EOT
        We would now normally add an entry in your /etc/hosts so that
        you can access this virtualhost using a name rather than a number.
        However, since you have set the virtualhost to something other than
        127.0.0.1, this may not be necessary. (ie. there may already be a DNS
        record pointing to this IP)

_EOT
        echo -n "Do you want to add this anyway? [y/N] "
        read add_net_info

        case $add_net_info in
            y*|Y*)	exit
                ;;
        esac
    fi
    echo
    echo "Creating a virtualhost for $VIRTUALHOST..."
    echo -n "+ Adding $VIRTUALHOST to /etc/host... "
    echo "$IP_ADDRESS\t$VIRTUALHOST" >> /etc/hosts
    echo "done"
fi


# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Ask the user where they would like to put the files for this virtual host
#
echo -n "+ Checking for $DOC_ROOT_PREFIX/$VIRTUALHOST... "

if [ ! -d $DOC_ROOT_PREFIX/$VIRTUALHOST ]; then
    echo "not found"
else
    echo "found"
fi

echo -n "  - Use $DOC_ROOT_PREFIX/$VIRTUALHOST as the virtualhost folder? [Y/n] "

read resp

case $resp in

    n*|N*)
        while : ; do
            if [ -z $FOLDER ]; then
                echo -n "  - Enter Full Path for folder: "
                read FOLDER
            else
                break
            fi
        done
        ;;

    *) FOLDER=$DOC_ROOT_PREFIX/$VIRTUALHOST
        ;;
esac


# Create the folder if we need to...
if [ ! -d $FOLDER ]; then
    echo -n "  + Creating folder $FOLDER... "
    su $USER -c "mkdir -p $FOLDER"
    # If $FOLDER is deeper than one level, we need to fix permissions properly
    case $FOLDER in
        */*)
            subfolder=0
            ;;

        *)
            subfolder=1
            ;;
    esac

    if [ $subfolder != 1 ]; then
        # Loop through all the subfolders, fixing permissions as we go
        #
        # Note to fellow shell-scripters: I realize that I could avoid doing
        # this by just creating the folders with `su $USER -c mkdir ...`, but
        # I didn't think of it until about five minutes after I wrote this. I
        # decided to keep with this method so that I have a reference for myself
        # of a loop that moves down a tree of folders, as it may come in handy
        # in the future for me.
        dir=$FOLDER
        while [ $dir != "." ]; do
            chown $USER:$OWNER_GROUP $DOC_ROOT_PREFIX/$dir
            dir=`dirname $dir`
        done
    else
        chown $USER:$OWNER_GROUP $DOC_ROOT_PREFIX/$FOLDER
    fi

    echo "done"
fi


# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Create a default index.html if there isn't already one there
#
if [ $CREATE_INDEX == 'yes']; then
    if [ ! -e $FOLDER/index.html -a ! -e $FOLDER/index.php ]; then

        cat << __EOF >$FOLDER/index.html
        <html>
        <head>
        <title>Welcome to $VIRTUALHOST</title>
        </head>
        <style type="text/css">
        body, div, td { font-family: "Lucida Grande"; font-size: 12px; color: #666666; }
        b { color: #333333; }
        .indent { margin-left: 10px; }
        </style>
        <body link="#993300" vlink="#771100" alink="#ff6600">

        <table border="0" width="100%" height="95%"><tr><td align="center" valign="middle">
        <div style="width: 500px; background-color: #eeeeee; border: 1px dotted #cccccc; padding: 20px; padding-top: 15px;">
        <div align="center" style="font-size: 14px; font-weight: bold;">
        Congratulations!
        </div>

        <div align="left">
        <p>If you are reading this in your web browser, then the only logical conclusion is that the <b><a href="http://$VIRTUALHOST/">http://$VIRTUALHOST/</a></b> virtualhost was setup correctly. :)</p>

        <p>You can find the configuration file for this virtual host in:<br></p>
        <table class="indent" border="0" cellspacing="3">
        <tr>
        <td><b>$NGINX_CONFIG/$NGINX_VIRTUAL_HOSTS_AVAILABLE/$VIRTUALHOST</b></td>
        </tr>
        </table>
        </p>

        <p>You will need to place all of your website files in:<br>
        <table class="indent" border="0" cellspacing="3">
        <tr>
        <td><b><a href="file://$DOC_ROOT_PREFIX/$FOLDER">$DOC_ROOT_PREFIX/$FOLDER</b></a></td>
        </tr>
        </table>

            </div>

            </div>
            </td></tr></table>

            </body>
            </html>
__EOF
            chown $USER:$OWNER_GROUP $DOC_ROOT_PREFIX/$FOLDER/index.html

        fi
    fi

    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    # Create a default virtualhost file
    #
    echo -n "+ Creating virtualhost file... "
    cat << __EOF >$NGINX_CONFIG/$NGINX_VIRTUAL_HOSTS_AVAILABLE/$VIRTUALHOST
  server {
        server_name $VIRTUALHOST;
        root $FOLDER;
        index index.html index.htm index.php;
        location = / {
          error_page 404 index.php;
        }


        location = /favicon.ico {
                log_not_found off;
                access_log off;
        }

        if (!-e \$request_filename) {
                rewrite ^/(.*)$ /index.php?q=\$1 last;
        }


# hide protected files
        location ~* .(engine|inc|info|install|module|profile|po|sh|.*sql|theme|tpl(.php)?|xtmpl)$|^(code-style.pl|Entries.*|Repository|Root|Tag|Template)$ {
                deny all;
        }

# hide backup_migrate files
        location ~* ^/files/backup_migrate {
                deny all;
        }
# Fighting with ImageCache? This little gem is amazing.
        location ~ ^/sites/.*/files/imagecache/ {
                try_files \$uri @rewrite;
        }
# Catch image styles for D7 too.
        location ~ ^/sites/.*/files/styles/ {
                try_files \$uri @rewrite;
        }
# serve static files directly
        location ~* ^.+.(jpg|jpeg|gif|css|png|js|ico)$ {
                access_log        off;
                expires           30d;
                log_not_found off;
        }
#set variable for max client size and define upload_max_file_size all at once
        set upload_size 10M;

        client_max_body_size @upload_size;

        location ~ \.php$ {
                fastcgi_split_path_info ^(.+\.php)(/.+)$;
#NOTE: You should have "cgi.fix_pathinfo = 0;" in php.ini
                include fastcgi_params;
                fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
                fastcgi_intercept_errors on;
                fastcgi_pass unix:/var/run/php5-fpm.sock;
                fastcgi_param MAX_FILE_SIZE @upload_size;
        }
}
    
__EOF


    # Enable the virtual host
    ln -s $NGINX_CONFIG/$NGINX_VIRTUAL_HOSTS_AVAILABLE/$VIRTUALHOST $NGINX_CONFIG/$NGINX_VIRTUAL_HOSTS_ENABLED/$VIRTUALHOST

    echo "done"


    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    # Restart apache for the changes to take effect
    #
    echo -n "+ Restarting Nginx "
    $NGINX_BIN restart
    echo "done"

    cat << __EOF

    http://$VIRTUALHOST/ is setup and ready for use.

__EOF


    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    # Launch the new URL in the browser
    #
    echo -n "Launching virtualhost... "
    sudo -u $USER -H xdg-open http://$VIRTUALHOST/ &
    echo "done"

