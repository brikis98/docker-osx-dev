# docker-osx-dev: a productive development environment with Docker on OS X

[Docker](https://www.docker.com/) and [Boot2Docker](http://boot2docker.io/) are
awesome for running containers on OS X, but if you try to use them to do
iterative development by mounting a source folder from OS X into your Docker 
container, you will run into two major problems:

1. Mounted volumes on VirtualBox use vboxsf, which is *extremely* slow, so
   compilation and startup times for code in mounted folders is 10-20x slower.
2. File watching is broken since vboxsf does not trigger the inotify file 
   watching mechanism. The only workaround is to enable polling, which is *much*
   slower to pick up changes and eats up a lot of resources.

I found a solution that allows me to be productive with Docker on OS X, but
[setting it up is a painful process](http://stackoverflow.com/a/30111077/483528)
that involves nearly a dozen steps. To make life easier, I've packaged this 
process up in this docker-osx-dev project. 

# Status

This project is largely a workaround. I hope that in the future, someone will 
build a better alternative to vboxsf for mounting source code from OS X, and 
makes this entire project obsolete. Until that day comes, I will continue to use
these hacky scripts to keep myself productive.

# License

This code is released under the MIT License. See LICENSE.txt.