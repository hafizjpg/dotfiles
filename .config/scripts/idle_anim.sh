#!/usr/bin/env bash
# Smoothly transition brightness
for i in {10..1}; do
    brightnessctl set "${i}%"
    sleep 0.05
done