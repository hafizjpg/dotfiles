#!/bin/bash

pkill waybar
pkill qs
pkill swaync

waybar &
qs &
swaync &
