#!/bin/bash
git add -A deb
dpkg-scanpackages deb override 2> /dev/null | tee Packages | \
  gzip -9c > Packages.gz
git commit -am 'new release'
git push -u origin gh-pages
git checkout master
