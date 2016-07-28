#!/bin/bash
git add -A packages
dpkg-scanpackages packages override 2> /dev/null | tee Packages | \
  gzip -9c > Packages.gz
