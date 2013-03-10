#!/usr/bin/env python
# http://www.gnu.org/software/make/manual/make.html
import json, os, re, subprocess, sys

try:
	import argparse
except:
	sys.stderr.write("This script requires Python 2.7 or later\n")
	sys.exit(2)

# Return information about the build tool itself.
def tool_info():
	result = {'name' : 'make', 'globs': ['Makefile']}
	return json.dumps(result)

# Return information about a particular build file.
def build_info(path):
	# Make's -p option will print the database associated with the makefile, but unfortunately
	# it's returned in some ad-hoc format from the Paleozoic era so we need to rely on some
	# crappy heuristics to figure out what's what.
	def parse_targets(content):
		# Search for 'targets : prerequisites' where targets are space separated list of file names.
		# It's not clear what we'd do for multiple targets so, for now, we'll only handle the case
		# where there is one target.
		#
		# File names can contain nearly everything which causes us problems because we don't
		# want to return the implicit rule targets. So we'll arbitrarily rule out certain characters
		# that should rarely appear in the targets we care about.
		targets = []
		regex = re.compile(r'(?<! Not\ a\ target:)\s*\n([^#%=:\r\n\t ]+) \s* : \s* ([a-zA-Z#] | $)', re.VERBOSE | re.MULTILINE)
		for match in regex.finditer(content):
			target = match.group(1)
			if target != ".PHONY" and target != ".SUFFIXES" and target != "make":
				if "/" not in target:				# skip targets that are relative paths (TODO: may want to make this a setting)
					targets.append(target)
		return targets
		
	# There are tons of automatic and environment variables so we'll only add the ones coming
	# straight from the Makefile.
	def parse_variables(content):
		variables = []
		regex = re.compile(r'(?<= \n \043 \040 makefile \040 \(from) .+ \n ([\w_-]+) \s+ = \s+ (.+) $', re.VERBOSE | re.MULTILINE)
		for match in regex.finditer(content):
			name = match.group(1)
			value = match.group(2)
			variables.append([name, value.strip()])
		
		return variables
	
	path = os.path.expanduser(path)
	wd = os.path.dirname(path)
	args = ['make', '-p', '-f', path]
	process = subprocess.Popen(args, cwd = wd, stdout = subprocess.PIPE, stderr = subprocess.PIPE)
	(stdout, stderr) = process.communicate()
	
	result = {}
	if process.returncode == 0:
		result['error'] = ''
		result['targets'] = parse_targets(stdout)
		result['variables'] = parse_variables(stdout)
	elif stderr:
		result['error'] = "`%s` returned with error '%s'" % (' '.join(args), stderr)
	else:
		result['error'] = "`%s` returned with return code %s" % (' '.join(args), process.returncode)
	
	return json.dumps(result)

# Return a command line that can be used to perform a build.
def build_command(path, target, flags):
	if flags and flags[0] != ' ':
		flags = ' ' + flags
	
	(directory, filename) = os.path.split(os.path.expanduser(path))
	if filename != 'Makefile':
		flags = ' -f %s' % filename + flags
	
	result = {
		'cwd': directory,
		'command': "make%s %s" % (flags, target)
	}
	return json.dumps(result)

def validate_options(options):
	if options.flags and not (options.path and options.path):
		sys.stderr.write("--flags only makes sense with --path and --target\n")
		sys.exit(1)

# Parse command line.
parser = argparse.ArgumentParser(description = "Used by Mimsy to interact with Makefiles.")
parser.add_argument("--flags", default = '', help = 'make flags used when building a target')
parser.add_argument("--path", help = 'path to the Makefile')
parser.add_argument("--target", help = 'name of the Makefile target to build')
parser.add_argument("--version", "-V", action = 'version', version = '%(prog)s 0.1')
options = parser.parse_args()

# Process command line.
validate_options(options)
if options.path and options.target:
	print build_command(options.path, options.target, options.flags)
elif options.path:
	print build_info(options.path)
else:
	print tool_info()
	