#!/bin/bash

if [ ! -f "/tmp/disk.img" ]; then
  dd if=/dev/zero of=/tmp/disk.img bs=1M count=1
fi

losetup /dev/loop0 /tmp/disk.img

if [ $? -eq 0 ]; then
  ln -s /dev/loop0 /dev/sda1
  ln -s /dev/loop0 /dev/sdb1
fi
