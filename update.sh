#!/bin/bash
git add -A debs
dpkg-scanpackages debs override 2> /dev/null | tee Packages | \
  gzip -9c > Packages.gz
