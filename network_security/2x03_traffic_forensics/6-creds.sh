#!/bin/bash
tshark -r "$1" -Y 'urlencoded-form.key == "password" || urlencoded-form.key == "pass" || urlencoded-form.key == "pwd"' -T fields -e urlencoded-form.value
