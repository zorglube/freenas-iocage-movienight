# freenas-iocage-movienight
This is a simple script to automate the installation of MovieNight in a FreeNAS jail. It will create a jail, download 
and install GO from [Golang](https://golang.org/dl/) and download compile and install the latest version of MovieNight from [MovieNight](https://github.com/zorchenhimer/MovieNight). 

## Status
This script has been built under FreeNAS 11.3 U4.1 with FreeBSD 11.3-Release-P11. It 
should work for FreeNAS 11.3, and it should also work with TrueNAS CORE 12.0. Feel free 
to report any bad operation or purpose any improvement.

## Usage
Since the COVID-19 has locked down everyone at home, we couldn't go to movie theater 
together. MovieNight is an solution to overcome that. Quoting the MovieNight developer: 
"This is a single-instance streaming server with chat. [...] platform for watching movies with a group of people online." If 
you wonder how to use after installation, have an look into the MovieNight manual [MovieNight](https://github.com/zorchenhimer/MovieNight). 

### Prerequisites
MovieNight don't need to access any data outside of the jail. At this point, since MN  
need an GO runtime, the runtime will be stored into the jail. 

### Warning 
This script isn't fully working at this time. 
At the end of the deployment you'll HAVE TO connect to the Jail and customise the MovieNight `settings.json` file the restart the Jail. 

### Installation
Download the repository to a convenient directory on your FreeNAS system by changing to that directory and running `git clone https://github.com/zorglube/freenas-iocage-movienight`. Then change into the new freenas-iocage-movienight directory and create a file called `mn-config` with your favorite text editor. In its minimal form, it would look like this: 
```
    JAIL_IP="10.1.1.3"
    DEFAULT_GW_IP="10.1.1.1"
    GO_DL_VERSION="go1.15.linux-amd64.tar.gz"
    TARGET="FreeBSD"
    ARCH="amd64"
    MN_REPO="https://github.com/zorchenhimer/MovieNight.git"
```

You'll find the value to set `GO_VERSION` from the download section of [GO Lang](https://golang.org/dl/)

Many of the options are self-explanatory, and all should be adjusted to suit your needs, but only a few are mandatory. The mandatory options are:

- `JAIL_IP`: is the IP address for your jail. You can optionally add the netmask in CIDR notation (e.g., 192.168.1.199/24). If not specified, the netmask defaults to 24 bits. Values of less than 8 bits or more than 30 bits are invalid.
- `DEFAULT_GW_IP`: is the address for your default gateway
- `GO_DL_VERSION`: The version of GO SDK you want to download.
- `TARGET`: one value from `android darwin dragonfly freebsd linux nacl netbsd openbsd plan9 solaris windows`.
- `ARCH`: one value from `386 amd64 amd64p32 arm arm64 ppc64 ppc64le mips mipsle mips64 mips64le mips64p32 mips64p32leppc s390 s390x sparc sparc64`.
- `MN_REPO`: `https://github.com/zorchenhimer/MovieNight.git` or `https://github.com/zorglube/MovieNight.git`

In addition, there are some other options which have sensible defaults, but can be adjusted if needed. These are:

- `JAIL_NAME`: The name of the jail, defaults to `movienight`
- `INTERFACE`: The network interface to use for the jail. Defaults to `vnet0`.
- `VNET`: Whether to use the iocage virtual network stack. Defaults to `on`.
- `UID`: User that make run MN into the jail, default is `movienight`. 
- `GID`: Group that make run MN into the jail, default is `movienight`.
- `UID_GID_ID`: USer ID and Group ID, default is `850`.


### Execution
Once you've downloaded the script and prepared the configuration file, run this script (`./movienight-jail.sh`). The script will run for several minutes. When it finishes, your jail will be created and `movienight` will be installed.

### Test
To test your installation, enter your Movie Night jail IP address and port `8089` e.g. `10.1.1.3:8089` in a browser. If the installation was successful, you should see a Movie 
Night home page.

## Movie Night running configuration 
If you want to use some run arguments at the Movie Night start, have a look here [MovieNight_Configuration](https://github.com/zorglube/MovieNight#configuration) 
to choose your option, then edit the service startup file `/usr/local/etc/rc.d/movienight` 
customize the line `command_args=""`

## Support and Discussion
Useful sources of support include the [MovieNight](https://github.com/zorchenhimer/MovieNight). 

Questions or issues about this resource can be raised in [issues](https://github.com/zorglube/freenas-iocage-movienight/issues).  
 
