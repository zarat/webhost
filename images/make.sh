#!/bin/bash
cd "./ubuntu1804php72"
docker build -t ubuntu1804php72 .

cd "../ubuntu2204php81"
docker build -t ubuntu2204php81 .

cd "../ubuntu2404php83"
docker build -t ubuntu2404php83 .
