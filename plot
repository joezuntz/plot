#!/usr/bin/env python

"""
A command line plotting program.

With lots of options.

Under no circumstances should you make this accessible to the web.
Iy 

"""

import os
import sys
import warnings
warnings.simplefilter('ignore')
try:
	import pyfits
except:
	pass
from sys import argv,stderr,stdin



stdin_data=None

from optparse import OptionParser
usage = "usage: %prog [options] filenames ..."
parser = OptionParser(usage)
parser.add_option("-x", dest="x", type='str', default=1, help="Index of x column, one-based (0 for position index), or col name if using FITS data")
parser.add_option("-y", dest="y", type='str', default=2, help="Index of y column, or col name if using FITS data")
parser.add_option("-e", dest="e", type='int', default=None, help="Index of error bar column, if any")
parser.add_option("-c", dest="c", type='int', default=None, help="Index of colour column, if any")
parser.add_option("-z", "--xy", dest="xy", action="append", help="Plot pairs of columns specified as x,y")

parser.add_option("--log", action="store_true", dest="log", default=False,help="Both axes logarithmic")
parser.add_option("--xl", "--xlog", action="store_true", dest="xlog", default=False, help="Logarithmic x axis")
parser.add_option("--yl", "--ylog", action="store_true", dest="ylog", default=False,help="Logarithmic y axis")
parser.add_option("-k", "--skip", dest="skip", type='int', default=0, help="Skip the first SKIP rows of the files")
parser.add_option("-E", "--every", dest="every", type='int', default=1, help="Plot every n'th point")
parser.add_option("-m", "--math", dest="math", action="append", help="Apply modifications to the x and y here, for example, plot file -m 'x=x*2'  -m 'y=log(y)' ")

parser.add_option("-p", "--points", dest="style", action='store_const', default="-", const = ".", help="Plot with lines rather than points")
parser.add_option("-d", "--dots", dest="style", action='store_const', default="-", const = ",", help="Plot with dots rather than points")
parser.add_option("-l", "--linespoints", dest="style", action='store_const', default="-", const = ".-", help="Plot with lines and points")

parser.add_option("-t", "--title", dest="title", default="Plot", help="Plot title")
parser.add_option("--xt", "--xtitle", dest="xtitle", default="x", help = "Title of x axis")
parser.add_option("--yt", "--ytitle", dest="ytitle", default="y", help = "Title of y axis")
parser.add_option("-w", "--tex", action="store_true",  dest="tex", default=False, help="Use latex for the labels")


parser.add_option("--xmin",  dest="xmin", type='float',default=None,help="x range minimum")
parser.add_option("--xmax",  dest="xmax", type='float',default=None,help="x range minimum")
parser.add_option("--ymin",  dest="ymin", type='float',default=None,help="y range minimum")
parser.add_option("--ymax",  dest="ymax", type='float',default=None,help="y range minimum")

parser.add_option("-o", "--out", dest="file", default="",  help="Filename to save to.")
parser.add_option("-s", "--show", dest="show", action="store_true", default=False, help="Show plot regardless of saving")

parser.add_option("--spec", "--spectrum", action="store_true", dest="spectrum", default=False, help="Plot the power spectrum of the y axis")
parser.add_option("-a", "--moving-average", action="store",  dest="moving_average", type='int',default=0, help="Generate a moving average plot (both axes)")
parser.add_option("-f", "--fit-poly", action="store",  dest="poly", type='int', default=0, help="Fit a polynomial of the specified order and plot it")

parser.add_option("-H", "--histogram", "--hist", action="store_true", dest="histogram", default=False, help="Plot a histogram of the y column, and ignore the x column")
parser.add_option("-S", "--step", action="store_true",  dest="hist_step", default=False, help="Plot unfilled (step-style) when doing histograms")
parser.add_option("-b", "--bins", action="store", type='int', dest="bins", default=0, help="The number of histogram bins")
parser.add_option("-n", "--norm", action="store_true",  dest="norm", default=False, help="Normalize the histogram")

parser.add_option("-F", "--fits", action="store_true", dest="force_fits", default=False, help="Force a file to be read as a FITS file regardless of its suffix")
parser.add_option("-j", "--extension", action="store", dest="extension", default='1', help="FITS extension number to read.")
parser.add_option("-N", "--nofits", action="store_false", dest="use_fits", default=True, help="Do not plot the file as FITS, regardless of its suffix")

parser.add_option("-L", "--nolegend", action="store_true",  dest="nolegend", default=False, help="Do not include a legend on the plot")
parser.add_option("-P", "--legend-position", action="store",  dest="legend_pos", default='upper left', help="Where to put the legend - 'upper left', 'center', etc.'")



def make_spec_plotter(plotter):
	"""
	Return a function that plots spectra, from another plotting functions
	(so e.g. you can combine spectra and logs)
	"""
	def spec_plotter(x,y,*args,**kwargs):
		s = abs(fft(y))**2
		return plotter(x,s,*args,**kwargs)
	return spec_plotter

def make_hist_plotter(opt):
	"""
	Return a function that plots histograms, with options like the number of 
	bins and whether to take logs 
	"""
	bins=opt.bins
	if bins==0: bins=10
	xlog=opt.xlog
	ylog=opt.ylog
	if opt.log:
		xlog=True
		ylog=True
	normed=opt.norm
	hist_range=None
	histtype='bar'
	if opt.hist_step:
		histtype='step'
	if opt.xmin is not None and opt.xmax is not None:
		hist_range = (opt.xmin, opt.xmax)
	def hist_plotter(x,y,*args,**kwargs):
		if ylog: y=log10(y)
		hist(y,bins=bins,log=xlog,normed=normed, range=hist_range, histtype=histtype)
	return hist_plotter
		
def loglog_errorbar(*args, **kwargs):
	#Do a null log plot first
	loglog()
	#then the error bar plot
	return errorbar(*args, **kwargs)

def choose_plotter(opt):
	"""
	Return a function the generates plots based on the options chosen (log, hist, etc. )
	"""
	if opt.histogram:
		plotter=make_hist_plotter(opt)
	elif opt.e is not None and ((opt.xlog and opt.ylog) or opt.log):
		plotter=loglog_errorbar
	elif (opt.xlog and opt.ylog) or opt.log:
		plotter=loglog
	elif opt.xlog:
		plotter=semilogx
	elif opt.ylog:
		plotter=semilogy
	elif opt.e is not None:
		plotter=errorbar
	elif opt.c is not None:
		plotter = scatter
	else:
		plotter=plot
	if opt.spectrum:
		plotter = make_spec_plotter(plotter)
	return plotter

def polystr(p):
	""" Convert polynomial coefficients of the type used by the 
	numpy.poly* functions into a nice readable form"""
	out=""
	degree=len(p)-1
	if degree==1:
		out = "y = %g x" % (p[0])
	else:
		out = "y = %g x^{%d}" % (p[0],degree)
	for i,term in enumerate(p[1:]):
		i = degree-i-1
		if term<0:
			term=-term
			sign='-'
		else:
			sign='+'
		if i==0:
			out += " %c %g" % (sign,term)
		elif i==1:
			out += " %c %gx" % (sign,term)
		else:
			out += " %c %gx^{%d}" % (sign,term,i)
	return out
		

def plot_col(data,i,j,fmt,filename,plotter,extra_math,e,c,averaging,poly,tex):
	"""
	Plot one or two columns of data with the specified plotting function.
	Columns are numbered from one; if zero, use the row index.
	Lots of extra options.
	"""
	try:
		ix=int(i)-1
	except:
		ix=i
	try:
		jx=int(j)-1
	except:
		jx=j
	try:
		ex=int(e)-1
	except:
		ex=e
	try:
		cx=int(c)-1
	except:
		cx=e
	try:
		n=len(data.dtype.fields)
	except:
		n=data.ndim
#	n=data.ndim
	if n == 1:
		y = data
	else:
		y=data[jx]
	if ix == -1 or n == 1:
		x = arange(len(y))
	else:
		x=data[ix]
	if extra_math:
		for command in extra_math:
			exec(command)
	if averaging:
		x = movavg(x,averaging)
		y = movavg(y,averaging)
	label=filename
	if tex:
		label=label.replace("_","\_")
	if e is None:
		if c is None:
			plotter(x,y,fmt,label=filename)
		else:
			plotter(x,y,c=data[c],label=filename)
	else:
		if c is None:
			plotter(x,y,data[ex],fmt=fmt,label=filename)
		else:
			raise ValueError("Not yet implemented error bars on colour plots")
			plotter(x,y,data[ex],c=data[c-1],fmt=fmt,label=filename)

	if poly:
		p = np.polyfit(x,y,poly)
		poly_x = np.linspace(x.min(), x.max(), 1000)
		poly_y = np.polyval(p,poly_x)
		label = polystr(p)
		if tex:
			label = "$"+label+"$"
		plot(poly_x,poly_y,'-',label=label)
		
		


def plot_files(files,opt,wait=False):
	""" Loop through the listed files, loading and plotting 
	them according to the options"""
	n = len(files)
	plotter = choose_plotter(opt)
	if n==0:
		files = ["-"]
	for filename in files:
		if filename=="-":
			try:
				data=loadtxt(stdin,unpack=True,skiprows=opt.skip)
			except KeyboardInterrupt:
				sys.stderr.write("\nWith no options I plot from standard input.\n")
				sys.stderr.write("For help: plot --help\n")
				sys.exit(1)
			if data.ndim==2:
				data = data[:,::opt.every]
			else:
				data = data[::opt.every]

		elif (filename.endswith(".fits") or opt.force_fits) and opt.use_fits :
			try:
				ext=opt.extension
				try:
					ext=int(ext)
				except:
					pass
				data=pyfits.getdata(filename,ext).transpose()
				if data.ndim==2:
					data = data[:,::opt.every]
				else:
					data = data[::opt.every]
			except NameError:
				raise ValueError("You cannot plot FITS files without pyfits installed.  It was not found")
		else:
			data=loadtxt(filename,unpack=True,skiprows=opt.skip)
			if data.ndim==2:
				data = data[:,::opt.every]
			else:
				data = data[::opt.every]

		if filename == '-':
			filename="Standard Input"
		if not opt.xy: 
			plot_col(data,opt.x,opt.y,opt.style,filename,plotter,opt.math, opt.e, opt.c,opt.moving_average, opt.poly, opt.tex)
		if opt.xy:
			for xy in opt.xy:
				x,y = xy.split(",")
				plot_col(data,x,y,opt.style,str(xy),plotter,opt.math, opt.e, opt.c,opt.moving_average, opt.poly, opt.tex)
		if opt.xmin is not None:
			xlim(xmin=opt.xmin)
		if opt.xmax is not None:
			xlim(xmax=opt.xmax)
		if opt.ymin is not None:
			ylim(ymin=opt.ymin)
		if opt.ymax is not None:
			ylim(ymax=opt.ymax)
	if not opt.nolegend: legend(loc=opt.legend_pos)
	xlabel(opt.xtitle)
	ylabel(opt.ytitle)
	title(opt.title)
	minorticks_on()
	grid()

#
# There is a reason this is not in a "main" function.
# Because we want to expose all the pylab functions
# to the user easily so they can use them with the
# -m option (e.g. plot -m 'y=exp(y)') we need to import
# everything from pylab into module scope.
# You can probably do that from inside I function but
# I do not know how.
# 
options,plotfiles = parser.parse_args()
if (not options.use_fits) and options.force_fits:
	stderr.write("You have specified both to use FITS mode and not to use it.  It will not be used.\n")
import matplotlib
if options.file and (not options.show):
	matplotlib.use("Agg")
if options.tex:
	matplotlib.rc('text',usetex=True)
from pylab import *
plot_files(plotfiles,options)
if options.file:
	savefig(options.file)
if options.show or (not options.file):
	show()

