#!/usr/bin/perl -w

# Basic first pass API testing for PPI

use strict;
use lib ();
use UNIVERSAL 'isa';
use File::Spec::Functions ':ALL';
BEGIN {
	$| = 1;
	unless ( $ENV{HARNESS_ACTIVE} ) {
		require FindBin;
		chdir ($FindBin::Bin = $FindBin::Bin); # Avoid a warning
		lib->import( catdir( updir(), updir(), 'modules') );
	}
}

# Load the API to test
use Class::Autouse ':devel';
use PPI;
use PPI::Tokenizer;
use PPI::Lexer;
use PPI::Dumper;
use PPI::Find;
use PPI::Transform;

# Execute the tests
use Test::More 'tests' => 2050;
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
PPI=class
PPI::Tokenizer=class
PPI::Lexer=class
PPI::Dumper=class
PPI::Find=class
PPI::Transform=abstract

# The abstract PDOM classes
PPI::Base=abstract
PPI::Element=abstract
PPI::Node=abstract
PPI::Token=abstract
PPI::Token::_QuoteEngine=abstract
PPI::Token::_QuoteEngine::Simple=abstract
PPI::Token::_QuoteEngine::Full=abstract
PPI::Token::Quote=abstract
PPI::Token::QuoteLike=abstract
PPI::Token::Regexp=abstract
PPI::Structure=abstract
PPI::Statement=abstract









#####################################################################
# PDOM Classes

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
statement=method
next_sibling=method
snext_sibling=method
previous_sibling=method
sprevious_sibling=method
next_token=method
previous_token=method
insert_before=method
insert_after=method
remove=method
delete=method
replace=method
content=method
tokens=method
significant=method
location=method

[PPI::Node]
PPI::Element=isa
add_element=method
elements=method
first_element=method
last_element=method
children=method
schildren=method
child=method
schild=method
contains=method
find=method
find_any=method
remove_child=method
prune=method

[PPI::Token]
PPI::Element=isa
new=method
add_content=method
set_class=method
set_content=method
length=method

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

[PPI::Token::Word]
PPI::Token=isa

[PPI::Token::Separator]
PPI::Token::Word=isa

[PPI::Token::Label]
PPI::Token=isa

[PPI::Token::Structure]
PPI::Token=isa

[PPI::Token::Number]
PPI::Token=isa

[PPI::Token::Symbol]
PPI::Token=isa
canonical=method
symbol=method
raw_type=method
symbol_type=method

[PPI::Token::ArrayIndex]
PPI::Token=isa

[PPI::Token::Operator]
PPI::Token=isa

[PPI::Token::Magic]
PPI::Token=isa
PPI::Token::Symbol=isa

[PPI::Token::Cast]
PPI::Token=isa

[PPI::Token::Prototype]
PPI::Token=isa
prototype=method

[PPI::Token::Attribute]
PPI::Token=isa
identifier=method
parameters=method

[PPI::Token::DashedWord]
PPI::Token=isa

[PPI::Token::_QuoteEngine]

[PPI::Token::_QuoteEngine::Simple]
PPI::Token::_QuoteEngine=isa
string=method

[PPI::Token::_QuoteEngine::Full]
PPI::Token::_QuoteEngine=isa

[PPI::Token::Quote]
PPI::Token=isa

[PPI::Token::Quote::Single]
PPI::Token=isa
PPI::Token::Quote=isa

[PPI::Token::Quote::Double]
PPI::Token=isa
PPI::Token::Quote=isa
interpolations=method
simplify=method

[PPI::Token::Quote::Literal]
PPI::Token=isa

[PPI::Token::Quote::Interpolate]
PPI::Token=isa

[PPI::Token::QuoteLike]
PPI::Token=isa

[PPI::Token::QuoteLike::Backtick]
PPI::Token=isa

[PPI::Token::QuoteLike::Command]
PPI::Token=isa

[PPI::Token::QuoteLike::Words]
PPI::Token=isa

[PPI::Token::QuoteLike::Regexp]
PPI::Token=isa

[PPI::Token::Regexp]
PPI::Token=isa

[PPI::Token::Regexp::Match]
PPI::Token=isa

[PPI::Token::Regexp::Substitute]
PPI::Token=isa

[PPI::Token::Regexp::Transliterate]
PPI::Token=isa

[PPI::Statement]
PPI::Node=isa
label=method

[PPI::Statement::Expression]
PPI::Statement=isa

[PPI::Statement::Scheduled]
PPI::Statement=isa
type=method
block=method

[PPI::Statement::Package]
PPI::Statement=isa
namespace=method
file_scoped=method

[PPI::Statement::Include]
PPI::Statement=isa
type=method
module=method
pragma=method
version=method

[PPI::Statement::Sub]
PPI::Statement=isa
name=method
prototype=method
block=method
forward=method
reserved=method

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

[PPI::Document]
PPI::Node=isa
load=method
save=method
index_locations=method
flush_locations=method

[PPI::Document::Fragment]
PPI::Document=isa





#####################################################################
# Non-PDOM Classes

[PPI]

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

[PPI::Dumper]
new=method
print=method
string=method
list=method

[PPI::Find]
new=method
clone=method
in=method
start=method
match=method
finish=method
errstr=method

[PPI::Transform]
matches=method
matches_file=method
matches_source=method
matches_document=method
transform=method
transform_file=method
transform_source=method
transform_document=method
