#!/usr/bin/perl

# Test the API for PPI
use strict;
use lib '../../modules'; # Development testing
use lib '../lib';        # Installation testing
use Class::Autouse qw{:devel};
use PPI;
use Test::ClassAPI;

# Execute the tests
Test::ClassAPI->execute();

exit(0);

# Now, define the API for the classes
__DATA__
[PPI::Tokenizer]
PPI::Common=isa
new=method
get_token=method
all_tokens=method
increment_cursor=method
decrement_cursor=method

[PPI::Token]
PPI::Common=isa
PPI::Element=isa
new=method
add_content=method
content=method
class=method
set_class=method
set_content=method
length=method
is_a=method
significant=method

# Now do this for ALL the token classes
[PPI::Token::Whitespace]
PPI::Common=isa
new=method
add_content=method
content=method
class=method
set_class=method
set_content=method
length=method
is_a=method
significant=method

[PPI::Token::Pod]
PPI::Common=isa
new=method
add_content=method
content=method
class=method
set_class=method
set_content=method
length=method
is_a=method
significant=method

[PPI::Token::Data]
PPI::Common=isa
new=method
add_content=method
content=method
class=method
set_class=method
set_content=method
length=method
is_a=method
significant=method

[PPI::Token::End]
PPI::Common=isa
new=method
add_content=method
content=method
class=method
set_class=method
set_content=method
length=method
is_a=method
significant=method

[PPI::Token::Comment]
PPI::Common=isa
new=method
add_content=method
content=method
class=method
set_class=method
set_content=method
length=method
is_a=method
significant=method

[PPI::Token::Bareword]
PPI::Common=isa
new=method
add_content=method
content=method
class=method
set_class=method
set_content=method
length=method
is_a=method
significant=method

[PPI::Token::Label]
PPI::Common=isa
new=method
add_content=method
content=method
class=method
set_class=method
set_content=method
length=method
is_a=method
significant=method

[PPI::Token::Structure]
PPI::Common=isa
new=method
add_content=method
content=method
class=method
set_class=method
set_content=method
length=method
is_a=method
significant=method

[PPI::Token::Number]
PPI::Common=isa
new=method
add_content=method
content=method
class=method
set_class=method
set_content=method
length=method
is_a=method
significant=method

[PPI::Token::Symbol]
PPI::Common=isa
new=method
add_content=method
content=method
class=method
set_class=method
set_content=method
length=method
is_a=method
significant=method

[PPI::Token::ArrayIndex]
PPI::Common=isa
new=method
add_content=method
content=method
class=method
set_class=method
set_content=method
length=method
is_a=method
significant=method

[PPI::Token::Operator]
PPI::Common=isa
new=method
add_content=method
content=method
class=method
set_class=method
set_content=method
length=method
is_a=method
significant=method

[PPI::Token::Magic]
PPI::Common=isa
new=method
add_content=method
content=method
class=method
set_class=method
set_content=method
length=method
is_a=method
significant=method

[PPI::Token::Cast]
PPI::Common=isa
new=method
add_content=method
content=method
class=method
set_class=method
set_content=method
length=method
is_a=method
significant=method

[PPI::Token::SubPrototype]
PPI::Common=isa
new=method
add_content=method
content=method
class=method
set_class=method
set_content=method
length=method
is_a=method
significant=method

[PPI::Token::DashedBareword]
PPI::Common=isa
new=method
add_content=method
content=method
class=method
set_class=method
set_content=method
length=method
is_a=method
significant=method

[PPI::Token::Quote::Single]
PPI::Common=isa
new=method
add_content=method
content=method
class=method
set_class=method
set_content=method
length=method
is_a=method
significant=method

[PPI::Token::Quote::Double]
PPI::Common=isa
new=method
add_content=method
content=method
class=method
set_class=method
set_content=method
length=method
is_a=method
significant=method

[PPI::Token::Quote::Execute]
PPI::Common=isa
new=method
add_content=method
content=method
class=method
set_class=method
set_content=method
length=method
is_a=method
significant=method

[PPI::Token::Quote::OperatorSingle]
PPI::Common=isa
new=method
add_content=method
content=method
class=method
set_class=method
set_content=method
length=method
is_a=method
significant=method

[PPI::Token::Quote::OperatorDouble]
PPI::Common=isa
new=method
add_content=method
content=method
class=method
set_class=method
set_content=method
length=method
is_a=method
significant=method

[PPI::Token::Quote::OperatorExecute]
PPI::Common=isa
new=method
add_content=method
content=method
class=method
set_class=method
set_content=method
length=method
is_a=method
significant=method

[PPI::Token::Quote::Words]
PPI::Common=isa
new=method
add_content=method
content=method
class=method
set_class=method
set_content=method
length=method
is_a=method
significant=method

[PPI::Token::Quote::Regex]
PPI::Common=isa
new=method
add_content=method
content=method
class=method
set_class=method
set_content=method
length=method
is_a=method
significant=method

[PPI::Token::Regex::Match]
PPI::Common=isa
new=method
add_content=method
content=method
class=method
set_class=method
set_content=method
length=method
is_a=method
significant=method

[PPI::Token::Regex::Replace]
PPI::Common=isa
new=method
add_content=method
content=method
class=method
set_class=method
set_content=method
length=method
is_a=method
significant=method

[PPI::Token::Regex::Transform]
PPI::Common=isa
new=method
add_content=method
content=method
class=method
set_class=method
set_content=method
length=method
is_a=method
significant=method

[PPI::Token::Regex::Pattern]
PPI::Common=isa
new=method
add_content=method
content=method
class=method
set_class=method
set_content=method
length=method
is_a=method
significant=method
