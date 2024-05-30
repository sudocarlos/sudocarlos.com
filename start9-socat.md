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

1. Install socat

        apt install socat

1. Exit and allow your Star9 to reboot

        exit

1. Create a socat systemd service

        cat << 'EOF' > /lib/systemd/system/socat@.service

        [Unit]
        Description=socat %i forward
        Wants=podman.service
        After=podman.service

        [Service]
        Type=simple
        Restart=always
        RestartSec=3
        EnvironmentFile=/etc/embassy.socat/%i.conf
        ExecStart=/usr/bin/socat tcp-listen:${EXPOSED_PORT},fork,reuseaddr tcp:${SERVICE_ADDR}:${SERIVCE_PORT}

        [Install]
        WantedBy=multi-user.target
        EOF

1. Create a directory for socat service environment files

        mkdir -p /etc/embassy.socat/

1. Create a socat environment file 

        cat << 'EOF' > /etc/embassy.socat/btcpayserver.conf
        EXPOSED_PORT=8081
        SERVICE_PORT=80
        SERVICE_ADDR=btcpayserver.embassy
        EOF
    
    > Note: This example exposes BTCPayServer's web interface

1. Start the socat service

        systemctl start socat@btcpayserver.service

    > Note: This example uses the filename, `btcpayserver` (`.conf` extension omitted), to start the service  
    This works using the `%i` variable in `socat@.service` to load the environment file: `EnvironmentFile=/etc/embassy.socat/%i.conf`

1. Make sure the socat service is running

        systemctl status socat@btcpayserver.service
    
    __Example output__
    > Note: Look for `Active: active (running)` and verify the service, `btcpayserver.embassy`, and ports,
    `8081` and `80` are listed in the `CGroup:` entry

        ● socat@btcpayserver.service - socat btcpayserver forward
            Loaded: loaded (/lib/systemd/system/socat@.service; disabled; preset: enabled)
            Active: active (running) since Mon 2024-05-27 17:06:03 UTC; 2s ago
        Main PID: 2795077 (socat)
            Tasks: 1 (limit: 19004)
            Memory: 888.0K
                CPU: 3ms
            CGroup: /system.slice/system-socat.slice/socat@btcpayserver.service
                    └─2795077 /usr/bin/socat tcp-listen:8081,fork,reuseaddr tcp:btcpayserver.embassy:80

        May 27 17:06:03 yawning-jingle systemd[1]: Started socat@btcpayserver.service - socat btcpayserver forward.

1. Make sure your Start9 is now listening on the specified port

        netstat -plant | grep socat

    __Example output__
    > Note: `0.0.0.0:8081` shows that Start9 is listening on port 8081 using `socat` process ID `2795077`

        tcp        0      0 0.0.0.0:8081            0.0.0.0:*               LISTEN      2795077/socat       

1. Enable the socat service to start automatically

        systemctl enable socat@btcpayserver.service

1. Verify the service is now available at your Start9's IP address and the exposed port: http://10.0.0.2:8081
    - Get your Start9's IP address

            ip route | grep default | awk '{print $9}'

1. Create more services by repeating the previous steps, starting from 9

# Resources

- https://community.start9.com/t/diy-exposing-electrs-and-bitcoind-over-lan-in-startos-0-3/754  
