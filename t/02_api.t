#!/usr/bin/perl -w

# Basic first pass API testing for PPI

use strict;
use lib ();
use UNIVERSAL 'isa';
use File::Spec::Functions ':ALL';
BEGIN {
	$|++;
	unless ( $ENV{HARNESS_ACTIVE} ) {
		require FindBin;
		chdir ($FindBin::Bin = $FindBin::Bin); # Avoid a warning
		lib->import( catdir( updir(), updir(), 'modules') );
	}
}

# Load the API to test
use Class::Autouse ':devel';
use PPI;
use PPI::Lexer;
use PPI::Lexer::Dump;
use PPI::Format::HTML;

# Execute the tests
use Test::More 'tests' => 925;
use Test::ClassAPI;

# Ignore various imported or special functions
$Test::ClassAPI::IGNORE{'DESTROY'}++;
$Test::ClassAPI::IGNORE{'refaddr'}++;

# Execute the tests
Test::ClassAPI->execute('complete');
exit(0);

# Now, define the API for the classes
__DATA__

PPI::Base=abstract
PPI::Element=abstract
PPI::Node=abstract
PPI::Document=class
PPI::Tokenizer=class
PPI::Lexer=class
PPI::Lexer::Dump=class
PPI::Token=abstract
PPI::Token::Whitespace=class
PPI::Token::Pod=class
PPI::Token::Data=class
PPI::Token::End=class
PPI::Token::Comment=class
PPI::Token::Bareword=class
PPI::Token::Label=class
PPI::Token::Structure=class
PPI::Token::Number=class
PPI::Token::Symbol=class
PPI::Token::ArrayIndex=class
PPI::Token::Operator=class
PPI::Token::Magic=class
PPI::Token::Cast=class
PPI::Token::SubPrototype=class
PPI::Token::Attribute=class
PPI::Token::DashedBareword=class
PPI::Token::Quote::Simple=abstract
PPI::Token::Quote::Full=abstract
PPI::Token::Quote::Single=class
PPI::Token::Quote::Double=class
PPI::Token::Quote::Execute=class
PPI::Token::Quote::OperatorSingle=class
PPI::Token::Quote::OperatorDouble=class
PPI::Token::Quote::OperatorExecute=class
PPI::Token::Quote::Words=class
PPI::Token::Quote::Regex=class
PPI::Token::Regex::Match=class
PPI::Token::Regex::Replace=class
PPI::Token::Regex::Transform=class
PPI::Token::Regex::Pattern=class
PPI::Format::HTML=class

[PPI::Base]
err_stack=method
errclear=method
errstr=method
errstr_console=method

[PPI::Element]
new=method
clone=method
parent=method
top=method
document=method
previous_sibling=method
next_sibling=method
remove=method
delete=method
content=method
tokens=method
significant=method
location=method

[PPI::Node]
PPI::Element=isa
add_element=method
children=method
child=method
schild=method
contains=method
find=method
find_any=method
remove_child=method
prune=method

[PPI::Document]
PPI::Node=isa
load=method
save=method
index_locations=method
flush_locations=method

[PPI::Token]
PPI::Element=isa
new=method
add_content=method
set_class=method
set_content=method
length=method
is_a=method

[PPI::Token::Whitespace]
PPI::Token=isa
null=method
tidy=method

[PPI::Token::Pod]
PPI::Token=isa
lines=method
merge=method

[PPI::Token::Data]
PPI::Token=isa

[PPI::Token::End]
PPI::Token=isa

[PPI::Token::Comment]
PPI::Token=isa
line=method

[PPI::Token::Bareword]
PPI::Token=isa

[PPI::Token::Label]
PPI::Token=isa

[PPI::Token::Structure]
PPI::Token=isa

[PPI::Token::Number]
PPI::Token=isa

[PPI::Token::Symbol]
PPI::Token=isa

[PPI::Token::ArrayIndex]
PPI::Token=isa

[PPI::Token::Operator]
PPI::Token=isa

[PPI::Token::Magic]
PPI::Token=isa

[PPI::Token::Cast]
PPI::Token=isa

[PPI::Token::SubPrototype]
PPI::Token=isa

[PPI::Token::Attribute]
PPI::Token=isa
identifier=method
parameters=method

[PPI::Token::DashedBareword]
PPI::Token=isa

[PPI::Token::Quote::Simple]
PPI::Token=isa
PPI::Token::Quote=isa
get_string=method

[PPI::Token::Quote::Full]
PPI::Token=isa
PPI::Token::Quote=isa
sections=method

[PPI::Token::Quote::Single]
PPI::Token=isa
PPI::Token::Quote=isa
PPI::Token::Quote::Simple=isa

[PPI::Token::Quote::Double]
PPI::Token=isa
PPI::Token::Quote=isa
PPI::Token::Quote::Simple=isa
interpolations=method
simplify=method

[PPI::Token::Quote::Execute]
PPI::Token=isa
PPI::Token::Quote=isa

[PPI::Token::Quote::OperatorSingle]
PPI::Token=isa
PPI::Token::Quote=isa

[PPI::Token::Quote::OperatorDouble]
PPI::Token=isa
PPI::Token::Quote=isa

[PPI::Token::Quote::OperatorExecute]
PPI::Token=isa
PPI::Token::Quote=isa

[PPI::Token::Quote::Words]
PPI::Token=isa
PPI::Token::Quote=isa

[PPI::Token::Quote::Regex]
PPI::Token=isa
PPI::Token::Quote=isa

[PPI::Token::Regex::Match]
PPI::Token=isa

[PPI::Token::Regex::Replace]
PPI::Token=isa

[PPI::Token::Regex::Transform]
PPI::Token=isa

[PPI::Token::Regex::Pattern]
PPI::Token=isa

[PPI::Tokenizer]
new=method
load=method
get_token=method
all_tokens=method
increment_cursor=method
decrement_cursor=method

[PPI::Lexer]
new=method
lex_file=method
lex_source=method
lex_tokenizer=method

[PPI::Lexer::Dump]
new=method
print=method
dump_string=method
dump_array=method
dump_array_ref=method

[PPI::Format::HTML]
PPI::Base=isa
Exporter=isa
serialize=method
escape_html=method
escape_whitespace=method
escape_debug_html=method
wrap_page=method
line_label=method
syntax_string=method
syntax_page=method
debug_string=method
debug_page=method
