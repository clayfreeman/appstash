#!/bin/bash

git commit -am 'bump version'
make clean
make package FINALPACKAGE=1
make clean-packages
git checkout gh-pages
bash update.sh
git push -u origin master
