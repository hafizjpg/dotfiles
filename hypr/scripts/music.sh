#!/bin/bash

playerctl metadata --format "{{ artist }} - {{ title }}" 2>/dev/null | cut -c1-50
