# docker-unifi4-mdb3
Dockerfile for unifi4 with mongodb3.2. Originally based on the work by https://github.com/jacobalberty/unifi-docker, but has diverged significantly.

# Why
Mongo3 has built in support for the "wiredtiger" storage engine, which does snappy compression inline to the disk by default. This has huge performance and storage benefits.

# Using
If you want to modify the Dockerfile, clone this repo, modify it, and run `docker build .` from within it. If you plan to just use the image as is, you can pull it from my docker hub repo `docker pull travishegner/unifi4-mdb3`.

# Current Concerns
This particular image leaves apt in a broken dependency state. You will have trouble if you launch a shell in it and attempt to troubleshoot it. The mongodb-org package conflicts with the mongodb-server package but doesn't provide it. The unifi package depends on mongodb-server. I tried a dummy package to provide mongodb-server and depend on mongodb-org, but mongodb-org would not allow them to be installed together since it conflicts with mongodb-server.

This could be fixed by either the unifi team to change their depends line to allow "mongodb-org" as a dependency. It could also be fixed by the mongodb team if they "provide" mongodb-server. Take it up with them. The most appropriate fix would be for the unifi team to remove a dependency on any mongodb package, and allow one to run the mongodb instance anywhere they want. This would greatly improve flexibility.

In the meantime, if you /need/ to install a package to a running container, you should be able to do so with `apt-get download <package>` and `dpkg -i --force-conflicts <package>*.deb`, or some variation thereof.

# Enhancements to original
 * Fixed permissions to allow the service to run as "nobody".
 * Added an `init.sh` script to launch the unifi service, as well as capture signals to allow the clean termination of the mongodb instance, just in case the unifi service didn't terminate it properly. 
