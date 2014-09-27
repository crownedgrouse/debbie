# debbie #

.DEB Built In Erlang.

## Overview ##

``debbie`` is an Erlang module that creates DEBIAN binary or sources packages from an usual DEBIAN package directory structure on disk.
``debbie`` use [edgar](https://github.com/crownedgrouse/edgar) for Gnu AR format, and [swab](https://github.com/crownedgrouse/swab) for fakeroot or Uid/Gid setting. 
``debbie`` is *FULL* Erlang, and no external command is done, allowing to create DEBIAN packages on any plateform where Erlang can run.

No need of a DEBIAN machine or VM, but obviously, only cross-compiled or multi-platform applications must be used if your local platform is incompatible with your target platform... ``debbie`` is not magic !

No need to have root privilege, neither ``fakeroot`` command, UID/GID are modified in embedded TAR files.
Specific global non-root UID/GID and user/group names can also be set to data packed in data.tar.gz, otherwise default is set to 0/root.

## Example ##

Considere this below *trivial* DEBIAN binary package structure for 'myapp' application :

```
tree /path/to/my/debian/structure/
├── DEBIAN
│   └── control
├── etc
│   └── myapp.ini
└── usr
    └── bin
        └── myapp
```

(note : a valid DEBIAN package should have more files, like copyright, Man pages, etc... See [Debian policy](https://www.debian.org/doc/debian-policy/).

Creating a .deb package, in a erl shell, is simple as :

```
debbie:fy([{root_path, "/path/to/my/debian/structure/"}]).
```

The file ``debian.deb`` is created in ``/path/to/my/debian/structure/`` directory.

## Limitation ##

Only few controls is done : presence of ``control`` file and something to pack, i.e. at least another directory than DEBIAN/debian under root path.
No attempt is done to check if control files are valid.
It's up to you, or another module/application, to create a valid DEBIAN package structure.

## Documentation ##

A complete documentation is available.

Simply run `make docs` and open `doc/index.html` in your favorite browser, this will insure you having the documentation related to your version.

## Quick Start ##

```
git clone git://github.com/crownedgrouse/debbie.git
cd debbie
make
erl -pa `pwd`/ebin -pa `pwd`/deps/edgar/ebin -pa `pwd`/deps/swab/ebin
```

## Contributing ##

Contributions are welcome. Please use pull-requests.

