#! /usr/bin/bash

docker build --network host -t cuda11_8_ros . \
  --build-arg http_proxy=$http_proxy \
  --build-arg https_proxy=$https_proxy

