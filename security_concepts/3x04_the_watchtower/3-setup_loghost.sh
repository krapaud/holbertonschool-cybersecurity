#!/bin/bash
grep -nE 'imudp|imtcp|514' /etc/rsyslog.conf
