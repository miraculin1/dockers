#! /usr/bin/bash

docker build --network host -t $1 . \
  --build-arg http_proxy=$http_proxy \
  --build-arg https_proxy=$https_proxy

