package PPI::RegexLib;

use strict;
use base 'Exporter';

use vars qw{@EXPORT_OK};
use vars qw{%RE};

BEGIN {
	
	# Create the regex hash
	%RE = ();
	
	# Add some primitive character classes
	$RE{ALPHA} = '[a-zA-Z]';
	$RE{ALNUM} = '[a-zA-Z0-9]';
	$RE{CLASS} = '[\w:]'; # Characters anywhere in a class name
	$RE{SYMBOL}{FIRST} = '[a-zA-Z_]'; # The first character in a perl symbol
 	# I refuse to support D'oh style modules, I've never seen it used.
	$RE{SYMBOL}{AFTER} = '(?:\w|::)'; # After the first character in a perl symbol
	$RE{SYMBOL}{IDENT} = '[$@%&*]';
	$RE{FILE}  = '[\w.]';   # Characters normally in a filename
	
	# Carriage return / newline
	$RE{newline}{local}         = '\n'; # Allow it to be set dynamically
	$RE{newline}{unix}          = '\012';
	$RE{newline}{mac}           = '\015';
	$RE{newline}{win32}         = '\015\012';
	$RE{newline}{crossplatform} = '(?:\015\012|\015|\012)';
	
	# Perl related
	$RE{perl}{symbol}  = "$RE{SYMBOL}{FIRST}$RE{SYMBOL}{AFTER}*";
	$RE{perl}{var}     = $RE{perl}{symbol};
	$RE{perl}{scalar}  = '\$' . $RE{perl}{symbol};
	$RE{perl}{array}   = '\@' . $RE{perl}{symbol};
	$RE{perl}{hash}    = '\%' . $RE{perl}{symbol};
	$RE{perl}{glob}    = '\*' . $RE{perl}{symbol};
	$RE{perl}{sub}     = '\&' . $RE{perl}{symbol};
	$RE{perl}{package} = "(?<!$RE{CLASS})$RE{perl}{symbol}(?:::$RE{perl}{symbol})*(?!$RE{CLASS})";
	$RE{perl}{class}   = $RE{perl}{'package'};
	$RE{perl}{pod}     = '=\w+';
	$RE{perl}{_pod}    = '=(\w+)';
	$RE{perl}{pre}     = '\b__[A-Z]+__\b';
	$RE{perl}{_pre}    = '\b__([A-Z]+)__\b';
	
	# Classify a single line of perl code
	$RE{perl}{line}{hashbang} = '^\#\!';
	$RE{perl}{line}{package}  = '^package\s+('.$RE{perl}{class}.')\s*;';
	$RE{perl}{line}{blank}    = '^\s*$';
	$RE{perl}{line}{comment}  = '^\s*#';
	$RE{perl}{line}{sub}      = '^\s*sub\s+('.$RE{perl}{symbol}.')';
	$RE{perl}{line}{use}      = '^\s*use\s+('.$RE{perl}{symbol}.')';
	$RE{perl}{line}{pod}      = '^'.$RE{perl}{_pod};

	# Common aliases
	$RE{p}      = $RE{perl};
	$RE{pl}     = $RE{perl}{line};
	$RE{xpnl}   = $RE{newline}{crossplatform};
	$RE{xpcrlf} = $RE{newline}{crossplatform};

	# Make the hash exportable	
	@EXPORT_OK = qw{%RE};
}

# Return a reference to the hash
sub RE() { \%RE }

1;
