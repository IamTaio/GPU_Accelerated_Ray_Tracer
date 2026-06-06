# syntax=docker/dockerfile:1
FROM nvidia/cuda:12.4.0-devel-ubuntu22.04

WORKDIR /app

RUN apt-get update && apt-get install -y \
    gcc curl git build-essential gdb \
    libglfw3-dev libglm-dev \
    ripgrep fd-find wget xz-utils unzip \
    x11-apps xauth cmake \
    && rm -rf /var/lib/apt/lists/*

COPY . .
# # Gets overwritten by docker-compose anyways, so they'll have to build it manually.
# RUN cmake -B build/Release -DCMAKE_BUILD_TYPE=Release -S /app && \
#     cmake --build build/Release && \
#     cmake -B build/Debug -DCMAKE_BUILD_TYPE=Debug -S /app && \
#     cmake --build build/Debug
    