#!/usr/bin/perl

# Test the API for PPI
use strict;
use lib '../../modules'; # Development testing
use lib '../lib';        # Installation testing
use Class::Autouse qw{:devel};
use PPI;

# Execute the tests
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
PPI::Common=isa

[PPI::Token::Pod]
PPI::Common=isa
merge=method

[PPI::Token::Data]
PPI::Common=isa

[PPI::Token::End]
PPI::Common=isa

[PPI::Token::Comment]
PPI::Common=isa

[PPI::Token::Bareword]
PPI::Common=isa

[PPI::Token::Label]
PPI::Common=isa

[PPI::Token::Structure]
PPI::Common=isa

[PPI::Token::Number]
PPI::Common=isa

[PPI::Token::Symbol]
PPI::Common=isa

[PPI::Token::ArrayIndex]
PPI::Common=isa

[PPI::Token::Operator]
PPI::Common=isa

[PPI::Token::Magic]
PPI::Common=isa

[PPI::Token::Cast]
PPI::Common=isa

[PPI::Token::SubPrototype]
PPI::Common=isa

[PPI::Token::DashedBareword]
PPI::Common=isa

[PPI::Token::Quote::Single]
PPI::Common=isa

[PPI::Token::Quote::Double]
PPI::Common=isa

[PPI::Token::Quote::Execute]
PPI::Common=isa

[PPI::Token::Quote::OperatorSingle]
PPI::Common=isa

[PPI::Token::Quote::OperatorDouble]
PPI::Common=isa

[PPI::Token::Quote::OperatorExecute]
PPI::Common=isa

[PPI::Token::Quote::Words]
PPI::Common=isa

[PPI::Token::Quote::Regex]
PPI::Common=isa

[PPI::Token::Regex::Match]
PPI::Common=isa

[PPI::Token::Regex::Replace]
PPI::Common=isa

[PPI::Token::Regex::Transform]
PPI::Common=isa

[PPI::Token::Regex::Pattern]
PPI::Common=isa
