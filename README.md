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
- Alternatively you can do `git submodule update --init` to get a copy of some keyrings I came across.
  I think they are valid, but please do not trust me alone.  Go verify.
  How you do verification is up to you (I do not know a good way.  Download from the website and compare is not very secure.)

Then run:

	./download-debian-netinstall.sh

or something like:

	./download-debian-netinstall.sh debian-daily
	./download-debian-netinstall.sh debian-weekly
	./download-debian-netinstall.sh debian-11.1.0
	./download-debian-netinstall.sh debian-archive-9.9.0
	./download-debian-netinstall.sh debian-archive-9.9.0:i386
	./download-debian-netinstall.sh kubuntu-18.04.1
	./download-debian-netinstall.sh ubuntu-20.04.3
	./download-debian-netinstall.sh ubuntu-server-18.04.2
	./download-debian-netinstall.sh ubuntu-live-server-20.04
	./download-debian-netinstall.sh devuan-jessie-1.0.0
	./download-debian-netinstall.sh devuan-ascii-2.0.0
	./download-debian-netinstall.sh devuan-ascii-2.1
	./download-debian-netinstall.sh devuan-beowulf-3.1.1

There is no autodetection whatsoever.  So you have to adopt to the distro in question:

- Devuan needs the name and version
- Debian works with the version, but older ones are in debian-archive
- Ubuntu works with any version, but there is no archive of intermediate versions
- And you must give the versions in full, as they are named in the download

Notes:

- Old versions of Debian are now downloaded using `jigdo-lite` as a fallback automatically

- Refreshing/resuming/rechecking downloads is supported.
  - `wget` then checks timestamps and downloads only changed files.
  - `jigdo-lite` can also resume broken downloads easily

- `DATA/` keeps all the downloaded data
- `ISO/` receives softlinks to the downloaded `DATA/`.
  - Softlink `ISO/` where you want the (relative) softlinks to the `.iso`s to show up.

- This script is proxy aware.  To set a proxy do something like this:

  ```
  export http_proxy=http://10.0.0.1:3128/
  export https_proxy=http://10.0.0.1:3128/
  ./download-debian-netinstall.sh
  ```

- You can put the `export`-lines in a file `~/.proxy.conf`

This here worked very well for ProxMox out of the box:

- Following assumes your Datacenter Storage `ISO image` content is at `/zfs/ISO`
  - `git clone --recursive https://github.com/hilbix/download-debian.git /zfs/ISO/download-debian/`
  - `ln -s ../template/iso /zfs/ISO/download-debian/ISO`
  - `/zfs/ISO/download-debian/download-debian-netinstall.sh 12.5.0`
- I really have no clue what the ProxMox UI advanced options for ISO "Download from URL" should tell me, sorry.
  - `Verify certificates` sounds promising, however what is it supposed to do for me?
  - Why is there no hash value shown on the `ISO Images` view?  Why is there no "verified" batch or something like that?
  - `download-debian` (this here) securely verifies the downloads before linking them to the destination, so you cannot accidentally use compromized data.
  - I do no think this is the best we can do, instead I think this just is the absolute bare minimum which always must be ensured by default.  (YMMV)
  - However it looks like ProxMox does not even try to block you from downloading tampered data.
  - And I do not understand why there is lacking an authentication step or how it is supposed to work.
  - Perhaps I am just simply too stupid to understand, how ProxMox secures us against acidentally downloading compromized content by default.


## License

Public Domain

## Historic

[GIST](https://gist.github.com/hilbix/0085d19470d5ac754cf26118c824e057)

