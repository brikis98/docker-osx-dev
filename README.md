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

I found a solution that allows me to be productive with Docker on OS X by using
Vagrant and Rsync. However, [setting it up is a painful process](http://stackoverflow.com/a/30111077/483528)
that involves nearly a dozen steps, so to make life easier, I've packaged this 
process up in this docker-osx-dev project. 

# Status

This project is largely a workaround. I hope that in the future, someone will 
build a better alternative to vboxsf for mounting source code from OS X, and 
makes this entire project obsolete. Until that day comes, I will continue to use
these hacky scripts to keep myself productive.

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
start the Docker server:

```sh
docker-osx-dev start
```

You can now run whatever Docker containers you like. For example, here is how 
you can fire up the tiny [Alpine Linux image](https://registry.hub.docker.com/u/gliderlabs/alpine/)
and get a Linux console in seconds:

```sh
> docker run -it --rm gliderlabs/alpine:3.1 sh
/ # echo "I'm now in a Linux container"
I'm in a Linux container
```

You can use the `-v` flag to mount the current source folder:

```sh
> docker run -it --rm -v $(pwd):/src gliderlabs/alpine:3.1 sh
/ # cd /src
/src # ls

[... A list of the files you had in that folder on OS X ...]
```

docker-osx-dev uses [rsync](http://en.wikipedia.org/wiki/Rsync)
to keep the files in sync between OS X and your Docker containers with virtually
no performance penalty. Your builds should run quickly and file watchers should
work normally!

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

This would fire up a Postgres database and the training webapp (a simple "Hello, 
World" Python app), mount the current directory into `/src` in the webapp 
container (using rsync, so it'll be fast), and expose port 5000. You can now
test this webapp by going to:

```
http://dockerhost:5000
```

Notice the use of `dockerhost` in the URL. The docker-osx-dev script 
automatically adds the proper IP to your `/etc/hosts` file so you don't have to
mess around with Vagrant or Docker IP addresses. 

# How it works

This `setup.sh` script installs all the software you need:

1. [Docker](https://www.docker.com/)
2. [Docker Compose](https://docs.docker.com/compose/)
3. [VirtualBox](https://www.virtualbox.org/)
4. [Vagrant](https://www.vagrantup.com/)
5. [vagrant-gatling-rsync](https://github.com/smerrill/vagrant-gatling-rsync)

It also adds the $DOCKER_HOST environment variable to `~/.bash_profile` or
`~/.bashrc` file so it is available at startup and adds the IP address of the
Vagrant box to `/etc/hosts` as `dockerhost` so you can visit 
`http://dockerhost:12345` in your browser for easy testing.

Instead of using vboxsf, docker-osx-dev keeps files in sync by running the
[vagrant-gatling-rsync](https://github.com/smerrill/vagrant-gatling-rsync) in
the background, which uses [rsync](http://en.wikipedia.org/wiki/Rsync) to 
quickly copy changes from OS X to your Docker container. By default, the current
source folder (i.e. the one with the `Vagrantfile`) is synced. If you use 
`docker-compose`, docker-osx-dev will sync any folders marked as 
[volumes](https://docs.docker.com/compose/yml/#volumes).

# License

This code is released under the MIT License. See LICENSE.txt.