# Securely download ISOs for Debian/Ubuntu 

This downloads the ISO and verifies it's checksums
based on the keyring of the distro.

Note that there is a hen/egg problem with keyrings,
as you cannot verify keyrings yourself.

However often they are part of the Distro,
so quite often you already have the keyring on some trusted system.

Exception: Devuan - I found no way to verify their keyring with some already installed Devuan.


## Usage

Requirements:

- For Debian: `sudo apt-get install debian-keyring`
- For Ubuntu: `sudo apt-get install ubuntu-keyring`
- For Devuan: `wget https://files.devuan.org/devuan-devs.gpg`
  - The script looks for this file also in `keyrings/*/devuan-devs.gpg`
  - Note that downloading keys from websites is **not recommended** and **insecure as hell**.
  - Perhaps see https://unix.stackexchange.com/q/465797 for answers.

Then run:

	./download-debian-netinstall.sh

or something like:

	./download-debian-netinstall.sh debian-daily
	./download-debian-netinstall.sh debian-weekly
	./download-debian-netinstall.sh debian-10.0.0
	./download-debian-netinstall.sh debian-archive-9.9.0
	./download-debian-netinstall.sh debian-archive-9.9.0:i386
	./download-debian-netinstall.sh kubuntu-18.04.1
	./download-debian-netinstall.sh ubuntu-server-18.04.2
	./download-debian-netinstall.sh devuan-jessie-1.0.0
	./download-debian-netinstall.sh devuan-ascii-2.0.0

There is no autodetection whatsoever.  So you have to adopt to the distro in question:

- Devuan needs the name and version
- Debian works with the version, but older ones are in debian-archive
- Ubuntu works with any version, but there is no archive of intermediate versions


## License

Public Domain

## Historic

[GIST](https://gist.github.com/hilbix/0085d19470d5ac754cf26118c824e057)

