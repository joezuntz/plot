plot
====

Command line Python plotting
Joe Zuntz
University of Manchester

Purpose
-------

This simple python script plots columns of data from text and FITS files,
and from standard input.

It uses matplotlib, and with the right options can be just about publication
quality, but is really designed for quick-look data analysis.

It executes arbitrary inputs, so please do not run in exposed to the web or 
anything like that.


Usage
-----

Basic usage is:
    plot filename.txt          #plot columns 1 and 2
    plot -x2 -y3 filename.txt  #plot columns 2 and 3

There are a great many options - see them with:
    plot --help

