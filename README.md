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
work until I finally stumbled across one that does: Vagrant and Rsync. Using
this combination, build and compilation performance in mounted folders is on
par with native OS X and normal file watching works properly too. However, 
setting it up correctly is a painful process that involves nearly a dozen steps, 
so to make life easier, I've packaged this process up in this docker-osx-dev 
project. 

# Status

Alpha. I've tested it on my own computer and am able to code productively, but
I welcome others to try it and give me feedback (or submit pull requests!).

Note: this project is inherently a temporary workaround. I hope that in the 
future, someone will build a better alternative to vboxsf for mounting source 
code from OS X, and makes this entire project obsolete. Until that day comes, I 
will continue to use these hacky scripts to keep myself productive.

# Install

Prerequisite: [HomeBrew](http://brew.sh/) must be installed.

To install docker-osx-dev and all of its dependencies, run:

```sh
curl https://raw.githubusercontent.com/brikis98/docker-osx-dev/master/setup.sh | bash
```

To setup docker-osx-dev for a new project, run:

```sh
docker-osx-dev init
```

This will create a [Vagrantfile](http://docs.vagrantup.com/v2/vagrantfile/) in
the same folder. You should commit this file to source control. You only need
to do this once per project.

# Usage

Once you've setup a project with docker-osx-dev, use the following command to
start Vagrant, Docker, and file syncing:

```sh
docker-osx-dev start
```

You can now run whatever Docker containers you like. For example, here is how 
you can fire up the tiny [Alpine Linux image](https://registry.hub.docker.com/u/gliderlabs/alpine/)
and get a Linux console in seconds:

```
> echo "I'm running in $(uname)"
I'm running in Darwin

> docker run -it --rm gliderlabs/alpine:3.1 sh
/ # echo "Now I'm running in $(uname)!"
Now I'm running in Linux!
```

You can use the `-v` flag to mount a source folder. For example, here is how
you can mount the current directory on OS X so it shows up under `/src` in the
Docker container:

```
> ls -al
total 16
drwxr-xr-x  4 brikis98  staff  136 May 16 14:05 .
drwxr-xr-x  7 brikis98  staff  238 May 16 14:04 ..
-rw-r--r--  1 brikis98  staff   12 May 16 14:05 bar
-rw-r--r--  1 brikis98  staff    4 May 16 14:05 foo

> docker run -it --rm -v $(pwd):/src gliderlabs/alpine:3.1 sh
/ # cd /src
/src # ls -al
total 12
drwxrwxrwx    2 1000     users           80 May 16 21:06 .
drwxr-xr-x   25 root     root          4096 May 16 21:07 ..
-rw-rw-rw-    1 1000     users           12 May 16 21:06 bar
-rw-rw-rw-    1 1000     users            4 May 16 21:06 foo

```

docker-osx-dev uses [rsync](http://en.wikipedia.org/wiki/Rsync)
to keep the files in sync between OS X and your Docker containers with virtually
no performance penalty. In the example above, any build you run in the `/src` 
folder of the Docker container should work just as quickly as if you ran it in
OS X. Also, file watchers should work normally for any development environment 
that supports hot reload (i.e. make a change and refresh the page).

If you are using [Docker Compose](https://docs.docker.com/compose/), 
docker-osx-dev will automatically use rsync to mount any folders marked as
[volumes](https://docs.docker.com/compose/yml/#volumes). For example, let's say 
you had the following `docker-compose.yml` file:

```yml
web:  
  image: training/webapp
  volumes:
    - .:/src
  ports:
    - "5000:5000"
db:
  image: postgres    
```

You could run this file as follows:

```sh
docker-compose up
```

This would fire up a [Postgres 
database](https://registry.hub.docker.com/u/library/postgres/) and the [training 
webapp](https://registry.hub.docker.com/u/training/webapp/) (a simple "Hello, 
World" Python app), mount the current directory into `/src` in the webapp 
container (using rsync, so it'll be fast), and expose port 5000. You can now
test this webapp by going to:

```
http://dockerhost:5000
```

(When you install docker-osx-dev, it prints instructions on how to configure
`dockerhost` as a URL for your Docker containers).

Finally, to shut down Docker and Vagrant, you can run:

```
docker-osx-dev stop
```

# How it works

The `setup.sh` script installs all the software you need:

1. [Docker](https://www.docker.com/)
2. [Docker Compose](https://docs.docker.com/compose/)
3. [VirtualBox](https://www.virtualbox.org/)
4. [Vagrant](https://www.vagrantup.com/)
5. [vagrant-gatling-rsync](https://github.com/smerrill/vagrant-gatling-rsync)
6. The docker-osx-dev script which you can use to start/stop Docker and Vagrant

The `setup.sh` also:

1. Adds the `$DOCKER_HOST` environment variable to `~/.bash_profile` or
   `~/.bashrc` file so it is available at startup.
2. Prints instructions on how to add the IP address of the Vagrant box to 
   `/etc/hosts` as `dockerhost` so you can visit `http://dockerhost:12345` in 
   your browser for easy testing. The script would add this entry automatically,
   but you need sudo privileges to modify `/etc/hosts`.

Instead of using vboxsf, docker-osx-dev keeps files in sync by running the
[vagrant-gatling-rsync](https://github.com/smerrill/vagrant-gatling-rsync) in
the background, which uses [rsync](http://en.wikipedia.org/wiki/Rsync) to 
quickly copy changes from OS X to your Docker container. By default, the current
source folder (i.e. the one with the `Vagrantfile`) is synced. If you use 
`docker-compose`, docker-osx-dev will sync any folders marked as 
[volumes](https://docs.docker.com/compose/yml/#volumes).

# Limitations and known issues

1. File syncing is currently one way only. That is, changes you make on OS X
   will be visible very quickly in the Docker container. However, changes in the
   Docker container will **not** be propagated back to OS X. This isn't a 
   problem for most development scenarios, but time permitting, I'll be looking
   into using [Unison](http://www.cis.upenn.edu/~bcpierce/unison/) to support
   two-way sync.
2. Too may technologies. I'd prefer to not have to use Vagrant, but it makes
   using rsync very easy. Time permitting, I'll be looking into using rsync
   directly with Boot2Docker.

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

# License

This code is released under the MIT License. See LICENSE.txt.