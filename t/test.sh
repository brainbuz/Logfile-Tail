#!/bin/bash

set -e

for i in t/*.t ; do echo $i ; perl -I. $i ; done
