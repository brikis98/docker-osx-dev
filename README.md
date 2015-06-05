# A productive development environment with Docker on OS X

[Docker](https://www.docker.com/) and [Boot2Docker](http://boot2docker.io/) are
awesome for running containers on OS X, but if you try to use them to do
iterative development by mounting a source folder from OS X into your Docker 
container, you will run into two major problems:

1. Mounted volumes on VirtualBox use vboxsf, which is *extremely* slow, so
   compilation and startup times for code in mounted folders is 10-20x slower.
2. File watching is broken since vboxsf does not trigger the inotify file 
   watching mechanism. The only workaround is to enable polling, which is *much*
   slower to pick up changes and eats up a lot of resources.

I tried many different solutions (see [Alternatives](#alternatives)) that didn't
work until I finally stumbled across one that does:
[rsync](http://en.wikipedia.org/wiki/Rsync). With rsync, build and compilation 
performance in mounted folders is on par with native OS X performance and 
standard file watching mechanisms work properly too. However, setting it up 
correctly is a painful process that involves many steps, so to make life 
easier, I've packaged this process up in this **docker-osx-dev** project. 

For more info, check out the blog post [A productive development environment 
with Docker on OS X](http://www.ybrikman.com/writing/2015/05/19/docker-osx-dev/).

# Status

Alpha. I've tested it on my own computer and am able to code productively, but
I welcome others to try it and give me feedback (or submit pull requests!).

Note: this project is inherently a temporary workaround. I hope that in the 
future, someone will build a better alternative to vboxsf for mounting source 
code from OS X, and makes this entire project obsolete. Until that day comes, I 
will continue to use these hacky scripts to keep myself productive.

# Install

Prerequisite: [HomeBrew](http://brew.sh/) must be installed.

The `docker-osx-dev` script has an `install` command that can setup your entire 
Docker development environment on OS X, including installing Docker and 
Boot2Docker:

```sh
curl -o /usr/local/bin/docker-osx-dev https://raw.githubusercontent.com/brikis98/docker-osx-dev/master/src/docker-osx-dev
chmod +x /usr/local/bin/docker-osx-dev
docker-osx-dev install
```

Three notes about the `install` command:

1. It is idempotent, so if you have some of the dependencies installed already, 
   it will **not** overwrite them.
2. When the install completes, it prints out instructions for one `source` 
   command you have to run to pick up important environment variables in your 
   current shell, so make sure not to skip that step!
3. Once the install completes, you can use the `docker-osx-dev` script to sync 
   files, as described in the next section.

# Usage

The `install` command will install, configure, and run Boot2Docker on your 
system, so the only thing left to do is to run the `docker-osx-dev` script and
tell it what folders to sync. If you run it with no arguments, it will sync the 
current folder to the Boot2Docker VM:

```
> cd /foo/bar
> docker-osx-dev
[INFO] Performing initial sync of paths: /foo/bar
[INFO] Watching: /foo/bar
```

Alternatively, you can use the `-s` flag to specify what folders to sync
(run `docker-sox-dev -h` to see all supported options):

```
> docker-osx-dev -s /foo/bar
[INFO] Performing initial sync of paths: /foo/bar
[INFO] Watching: /foo/bar
```

Now, in a separate tab, you can run a Docker container and mount the current
folder in it using the `-v` parameter. For example, here is how you can fire up 
the tiny [Alpine Linux image](https://registry.hub.docker.com/u/gliderlabs/alpine/)
and get a Linux console in seconds:

```
> cd /foo/bar
> docker run -v $(pwd):/src -it --rm gliderlabs/alpine:3.1 sh
/ # cd /src
/ # echo "I'm in a $(uname) container and my OS X files are being synced to $(pwd)!"
I'm in a Linux container and my OS X files are being synced to /src!
```

As you make changes to the files in the `/foo/bar` folder on OS X, using the 
text editors, IDEs, and tools you're used to, they will be automatically
synced to the `/src` folder in the Docker image. Moreover, file watchers should 
work normally in the Docker container for any framework that supports hot 
reload (e.g. Grunt, SBT, Jekyll) without any need for polling, so you should be 
able to follow a "make a change and refresh the page" development model.

If you are using [Docker Compose](https://docs.docker.com/compose/), 
docker-osx-dev will automatically sync any folders marked as
[volumes](https://docs.docker.com/compose/yml/#volumes) in `docker-compose.yml`. 
For example, let's say you had the following `docker-compose.yml` file:

```yml
web:  
  image: training/webapp
  volumes:
    - /foo:/src
  ports:
    - "5000:5000"
db:
  image: postgres    
```

First, run `docker-osx-dev`:

```
> docker-osx-dev
[INFO] Using sync paths from Docker Compose file at docker-compose.yml
[INFO] Performing initial sync of paths: /foo
[INFO] Watching: /foo
```

Notice how it automatically found `/foo` in the `docker-compose.yml` file. 
Now you can start your Docker containers:

```sh
docker-compose up
```

This will fire up a [Postgres 
database](https://registry.hub.docker.com/u/library/postgres/) and the [training 
webapp](https://registry.hub.docker.com/u/training/webapp/) (a simple "Hello, 
World" Python app), mount the `/foo` folder into `/src` in the webapp container, 
and expose port 5000. You can now test this webapp by going to:

```
http://dockerhost:5000
```

When you install docker-osx-dev, it adds an entry to your `/etc/hosts` file so
that `http://dockerhost` works as a URL for testing your Docker containers.

# How it works

The `install command` installs all the software you need:

1. [Docker](https://www.docker.com/)
2. [Boot2Docker](http://boot2docker.io/)
3. [Docker Compose](https://docs.docker.com/compose/)
4. [VirtualBox](https://www.virtualbox.org/)
5. [fswatch](https://github.com/emcrisostomo/fswatch)
6. The `docker-osx-dev` script which you can use to start/stop file syncing

The `install` command also:

1. Adds the Docker environment variables to your environment file (e.g. 
   `~/.bash_profile`) so it is available at startup.
2. Adds an entry to `/etc/hosts` so that `http://dockerhost` works as a valid
   URL for your docker container for easy testing.

Instead of using VirtualBox shared folders and vboxsf, docker-osx-dev keeps 
files in sync by using [fswatch](https://github.com/emcrisostomo/fswatch) to
watch for changes and [rsync](http://en.wikipedia.org/wiki/Rsync) to quickly
sync the files to the Boot2Docker VM. By default, the current source folder 
(i.e. the one you're in when you run `docker-osx-dev`) is synced. If you use 
`docker-compose`, docker-osx-dev will sync any folders marked as 
[volumes](https://docs.docker.com/compose/yml/#volumes). Run `docker-osx-dev -h`
to see all the other options supported.

# Limitations and known issues

File syncing is currently one way only. That is, changes you make on OS X
will be visible very quickly in the Docker container. However, changes in the
Docker container will **not** be propagated back to OS X. This isn't a 
problem for most development scenarios, but time permitting, I'll be looking
into using [Unison](http://www.cis.upenn.edu/~bcpierce/unison/) to support
two-way sync. The biggest limitation at the moment is getting a build of 
Unison that will run on the Boot2Docker VM.

# Contributing

Contributions are very welcome via pull request. This project is in a very early
alpha stage and it needs a lot of work. Take a look at the 
[issues](https://github.com/brikis98/docker-osx-dev/issues) for known bugs and
enhancements, especially the ones marked with the 
[help wanted](https://github.com/brikis98/docker-osx-dev/labels/help%20wanted)
tag. 

## Running the code locally

To run the local version of the code, just clone the repo and run your local 
copy of `docker-osx-dev`:

```
> git clone https://github.com/brikis98/docker-osx-dev.git
> cd docker-osx-dev
> ./src/docker-osx-dev
```

## Running unit tests

To run the unit tests, install [bats](https://github.com/sstephenson/bats) 
(`brew install bats`) and run the corresponding files in the `test` folder:

```
> ./test/docker-osx-dev.bats 
 ✓ index_of doesn't find match in empty array
 ✓ index_of finds match in 1 item array
 ✓ index_of doesn't find match in 1 item array
 ✓ index_of finds match in 3 item array

[...]

51 tests, 0 failures
```

## Running integration tests

I started to create integration tests for this project in 
`test/integration-test.sh`, but I hit a wall. The point of the integration test
would be to run Boot2Docker in a VM, but most CI providers (e.g. TravisCI and 
CircleCI) already run your build in their own VM, so this would require running 
a VM-in-a-VM. As described in [#7](https://github.com/brikis98/docker-osx-dev/issues/7),
I can't find any way to make this work. If anyone has any ideas, please take a 
look! 

# Alternatives

Below are some of the other solutions I tried to make Docker productive on OS X
(I even created a [StackOverflow Discussion](http://stackoverflow.com/questions/30090007/whats-the-right-way-to-setup-a-development-environment-on-os-x-with-docker)
to find out what other people were doing.) With most of them, file syncing was 
still too slow to be usable, but they were useful to me to learn more about the
Docker ecosystem, and perhaps they will be useful for you if docker-osx-dev 
doesn't work out:

1. [boot2docker-vagrant](https://github.com/blinkreaction/boot2docker-vagrant):
   Docker, Vagrant, and the ability to choose between NFS, Samba, rsync, and 
   vboxsf for file syncing. A lot of the work in this project inspired 
   docker-osx-dev.
2. [dinghy](https://github.com/codekitchen/dinghy): Docker + Vagrant + NFS. 
   I found NFS was 2-3x slower than running builds locally, which was much 
   faster than the 10-20x slowness of vboxsf, but still too slow to be usable.
3. [docker-unison](https://github.com/leighmcculloch/docker-unison): Docker +
   Unison. The [Unison File Synchronizer](http://www.cis.upenn.edu/~bcpierce/unison/)
   should be almost as fast as rsync, but I ran into [strange connection 
   errors](https://github.com/leighmcculloch/docker-unison/issues/2) when I 
   tried to use it with Docker.
4. [Polling in Jekyll](http://salizzar.net/2014/11/06/creating-a-github-jekyll-blog-using-docker/)
   and [Polling in SBT/Play](http://stackoverflow.com/a/26035919/483528). Some
   of the file syncing solutions, such as vboxsf and NFS, don't work correctly
   with file watchers that rely on inotify, so these are a couple examples of 
   how to switch from file watching to polling. Unfortunately, this eats up a
   fair amount of resources and responds to file changes slower, especially as
   the project gets larger.
5. [Hodor](https://github.com/gansbrest/hodor). Uses the [Unison File 
   Synchronizer](http://www.cis.upenn.edu/~bcpierce/unison/) to sync files. I
   have not had a chance to try this project out yet.

# License

This code is released under the MIT License. See LICENSE.txt.

# Changelog

* 06/05/15: merged the `setup.sh` and `docker-osx-dev` scripts together since
  they share a lot of the same code and bash scripts don't have any easy ways
  to define modules, download dependencies, etc.
* 05/25/15: Second version released. Removes Vagrant dependency and uses just
  rsync + Boot2Docker. If you had installed the first version, you should 
  delete your `Vagrantfile`, delete the old version of 
  `/usr/local/bin/docker-osx-dev`, and re-run the `setup.sh` script.
* 05/19/15: Initial version released. Uses Vagrant + rsync + Boot2Docker.

