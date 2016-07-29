#!/bin/bash

make clean
make package FINALPACKAGE=1
make clean-packages
git checkout gh-pages
