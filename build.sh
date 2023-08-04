#!/bin/bash
set -xe

[ -d build ] || git clone -b halium-12 https://gitlab.com/ubports/community-ports/halium-generic-adaptation-build-tools build
./build/build.sh "$@"
