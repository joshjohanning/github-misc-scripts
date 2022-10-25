#!/bin/bash

# make sure you have java installed
# sudo apt-get install default-jre
# or on mac: brew cask install java

wget https://repo1.maven.org/maven2/com/madgag/bfg/1.14.0/bfg-1.14.0.jar
git clone --mirror https://github.com/myorg/myrepo # the mirror is important
cp –r myrepo.git myrepo.git.bak # take a backup :)
touch passwords.txt # create a passwords.txt file and put your passwords in here (one per line)
java -jar bfg-1.14.0.jar --replace-text passwords.txt --no-blob-protection test-bfg-test.git # removes secrets in ALL branches
cd myrepo.git
# need to clean out the old refs before pushing
git reflog expire --expire=now --all && git gc --prune=now --aggressive
# when you're ready to push it back...
git push
