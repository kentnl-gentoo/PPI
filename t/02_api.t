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
use Test::More 'tests' => 1667;
use Test::ClassAPI;

# Ignore various imported or special functions
$Test::ClassAPI::IGNORE{'DESTROY'}++;
$Test::ClassAPI::IGNORE{'refaddr'}++;

# Execute the tests
Test::ClassAPI->execute('complete');
exit(0);

# Now, define the API for the classes
__DATA__

# Explicitly list the core classes
PPI::Base=abstract
PPI::Element=abstract
PPI::Node=abstract
PPI::Document=class
PPI::Document::Fragment=class
PPI::Tokenizer=class
PPI::Lexer=class
PPI::Lexer::Dump=class
PPI::Format::HTML=class

# Only list the non-classes for data objects
PPI::Token=abstract
PPI::Token::Quote::Simple=abstract
PPI::Token::Quote::Full=abstract
PPI::Structure=abstract





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
elements=method
children=method
schildren=method
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

[PPI::Document::Fragment]
PPI::Document=isa

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
canonical=method

[PPI::Token::ArrayIndex]
PPI::Token=isa

[PPI::Token::Operator]
PPI::Token=isa

[PPI::Token::Magic]
PPI::Token=isa
PPI::Token::Symbol=isa

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





[PPI::Statement]
PPI::Node=isa
label=method

[PPI::Statement::Expression]
PPI::Statement=isa

[PPI::Statement::Scheduled]
PPI::Statement=isa

[PPI::Statement::Package]
PPI::Statement=isa

[PPI::Statement::Include]
PPI::Statement=isa

[PPI::Statement::Sub]
PPI::Statement=isa
name=method
forward=method

[PPI::Statement::Variable]
PPI::Statement=isa
type=method
variables=method

[PPI::Statement::Compound]
PPI::Statement=isa
type=method

[PPI::Statement::Break]
PPI::Statement=isa

[PPI::Statement::Null]
PPI::Statement=isa

[PPI::Statement::Data]
PPI::Statement=isa

[PPI::Statement::End]
PPI::Statement=isa

[PPI::Statement::Unknown]
PPI::Statement=isa

[PPI::Structure]
PPI::Node=isa
braces=method
start=method
finish=method

[PPI::Structure::Block]
PPI::Structure=isa

[PPI::Structure::Subscript]
PPI::Structure=isa

[PPI::Structure::Constructor]
PPI::Structure=isa

[PPI::Structure::Condition]
PPI::Structure=isa

[PPI::Structure::List]
PPI::Structure=isa

[PPI::Structure::ForLoop]
PPI::Structure=isa

[PPI::Structure::Unknown]
PPI::Structure=isa
