![Tests](https://github.com/yesodweb/authenticate/workflows/Tests/badge.svg)

Authentication methods for Haskell web applications.

Note for Rpxnow: 
By default on some (all?) installs wget does not come with root certificates
for SSL.  If this is the case then Web.Authenticate.Rpxnow.authenticate will
fail as wget cannot establish a secure connection to rpxnow's servers.

A simple *nix solution, if potentially insecure (man in the middle attacks as
you are downloading the certs) is to grab a copy of the certs extracted from
those that come with firefox, hosted by CURL at
http://curl.haxx.se/ca/cacert.pem , put them somewhere (for ex,
~/.wget/cacert.pem) and then edit your ~/.wgetrc to include:
ca_certificate=~/.wget/cacert.pem

This should fix the problem.
