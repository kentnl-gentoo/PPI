#!/usr/bin/perl

# Test the API for PPI
use strict;
use lib '../../modules'; # Development testing
use lib '../lib';        # Installation testing
use Class::Autouse qw{:devel};
use PPI;

# Execute the tests
use Test::More 'tests' => 629;
use Test::ClassAPI;
Test::ClassAPI->execute;

exit(0);

# Now, define the API for the classes
__DATA__

PPI::Common=abstract
PPI::Element=abstract
PPI::Tokenizer=class
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
PPI::Token::DashedBareword=class
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

[PPI::Common]
err_stack=method
errstr=method
errstr_console=method

[PPI::Tokenizer]
new=method
get_token=method
all_tokens=method
increment_cursor=method
decrement_cursor=method

[PPI::Element]
parent=method
previous_sibling=method
next_sibling=method
extract=method
delete=method
class=method
content=method
tokens=method
significant=method

[PPI::Token]
PPI::Common=isa
PPI::Element=isa
new=method
add_content=method
set_class=method
set_content=method
length=method
is_a=method

[PPI::Token::Whitespace]
PPI::Token=isa

[PPI::Token::Pod]
PPI::Token=isa
merge=method

[PPI::Token::Data]
PPI::Token=isa

[PPI::Token::End]
PPI::Token=isa

[PPI::Token::Comment]
PPI::Token=isa

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

[PPI::Token::DashedBareword]
PPI::Token=isa

[PPI::Token::Quote::Single]
PPI::Token=isa

[PPI::Token::Quote::Double]
PPI::Token=isa

[PPI::Token::Quote::Execute]
PPI::Token=isa

[PPI::Token::Quote::OperatorSingle]
PPI::Token=isa

[PPI::Token::Quote::OperatorDouble]
PPI::Token=isa

[PPI::Token::Quote::OperatorExecute]
PPI::Token=isa

[PPI::Token::Quote::Words]
PPI::Token=isa

[PPI::Token::Quote::Regex]
PPI::Token=isa

[PPI::Token::Regex::Match]
PPI::Token=isa

[PPI::Token::Regex::Replace]
PPI::Token=isa

[PPI::Token::Regex::Transform]
PPI::Token=isa

[PPI::Token::Regex::Pattern]
PPI::Token=isa
