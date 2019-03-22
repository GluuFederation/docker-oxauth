# Changelog

Here you can see an overview of changes between each release.

## Version 3.1.5_01

Released on March 23rd, 2019.

* Upgraded to Gluu Server 3.1.5.

## Version 3.1.4_03

Released on February 16th, 2019.

* Added missing `idp-signing.crt` and `passport-rp.jks` files.

## Version 3.1.4_02

Released on January 16th, 2019.

* Added `http-forwarded` module to Jetty.

## Version 3.1.4_01

Released on November 12th, 2018.

* Upgraded to Gluu Server 3.1.4.

## Version 3.1.3_05

Released on September 18th, 2018.

* Changed base image to use Alpine 3.8.1.

## Version 3.1.3_04

Released on September 12th, 2018.

* Added feature to connect to secure Consul (HTTPS).

## Version 3.1.3_03

Released on August 31st, 2018.

* Added Tini to handle signal forwarding and reaping zombie processes.

## Version 3.1.3_02

Released on July 20th, 2018.

* Added wrapper to manage config via Consul KV or Kubernetes configmap.

## Version 3.1.3_01

Released on June 6th, 2018.

* Upgraded to Gluu Server 3.1.3.

## Version 3.1.2_01

Released on June 6th, 2018.

* Upgraded to Gluu Server 3.1.2.

## Version 3.1.1_rev1.0.0-beta3

Released on March 14th, 2018.

* Added feature to enable/disable remote debugging of JVM.

## Version 3.1.1_rev1.0.0-beta2

Released on October 11th, 2017.

* Use latest oxauth-server build.

## Version 3.1.1_rev1.0.0-beta1

Released on October 6th, 2017.

* Migrated to Gluu Server 3.1.1.

## Version 3.0.1_rev1.0.0-beta3

Released on August 16th, 2017.

* Fixed base64 encryption when synchronizing keys.

## Version 3.0.1_rev1.0.0-beta2

Released on July 25th, 2017.

* Fixed extraction process of custom oxAuth files where empty directories couldn't be copied to pre-defined custom directories.

## Version 3.0.1_rev1.0.0-beta1

Released on July 7th, 2017.

* Added working oxAuth v3.0.1.
* Added feature to synchronize `oxauth-keys.jks`.
