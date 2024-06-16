# Exposing Start9 services using socat

This guide describes a process for exposing ports on StartOS v0.3.5.x or earlier.
When StartOS v0.3.6 is released, this guide should become obsolete, so proceed only if
you're impatient and understand the risks you're taking. I plan to create more guides
that will describe how to install and connect to Tailscale so that you can use the
exposed ports from any other device in your tailnet, and how to use that Tailscale
connection to expose services on the Internet using a VPS.

1. Create a backup: https://docs.start9.com/0.3.5.x/user-manual/backups/backup-create
1. SSH to your Start9: https://docs.start9.com/0.3.5.x/user-manual/ssh
1. Enable the chroot-and-upgrade context

        sudo /usr/lib/startos/scripts/chroot-and-upgrade

    __Start9 warning__:

    > THIS IS NOT A STANDARD DEBIAN SYSTEM  
    > USING apt COULD CAUSE IRREPARABLE DAMAGE TO YOUR START9 SERVER  
    > PLEASE TURN BACK NOW!!!  
    > 
    > If you are SURE you know what you are doing, and are willing to accept the DIRE CONSEQUENCES of doing so, you can run the following command to disable this protection:  
    >     sudo rm /usr/local/bin/apt  
    > 
    > Otherwise, what you probably want to do is run:  
    >     sudo /usr/lib/startos/scripts/chroot-and-upgrade  
    > You can run apt in this context to add packages to your system.  
    > When you are done with your changes, type "exit" and the device will reboot into a system with the changes applied.  
    > This is still NOT RECOMMENDED if you don't know what you are doing, but at least isn't guaranteed to break things.  

1. Become root user

        sudo -i

1. Install tailscale ([View script source](https://github.com/tailscale/tailscale/blob/main/scripts/installer.sh))

        curl -fsSL https://tailscale.com/install.sh | sh

1. Exit and allow your Start9 to reboot

        exit

1. SSH to your Start9 again, become root user and enable tailscale

        tailscale up --hostname start9

1. Follow the link that is displayed to login

1. You can now access any services that you exposed using [start9-socat](start9-socat)
    - Note, you may want to add SSL encryption using [nginx-reverse-proxy](nginx-reverse-proxy)
