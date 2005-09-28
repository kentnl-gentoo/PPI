package PPI;

# See POD at end for documentation

use 5.005;
use strict;

# Set the version for CPAN
use vars qw{$VERSION $XS_COMPATIBLE @XS_EXCLUDE};
BEGIN {
	$VERSION       = '1.101';
	$XS_COMPATIBLE = '0.845';
	@XS_EXCLUDE    = ();
}

# Load everything
use PPI::Element              ();
use PPI::Token                ();
use PPI::Statement            ();
use PPI::Structure            ();
use PPI::Document             ();
use PPI::Document::Normalized ();
use PPI::Normal               ();
use PPI::Tokenizer            ();
use PPI::Lexer                ();

# If it is installed, load in PPI::XS
unless ( $PPI::XS_DISABLE ) {
	eval { require PPI::XS };
	die if $@ && $@ !~ /^Can't locate .*? at /; # Only ignore if not installed
}

1;

__END__

=pod

=head1 NAME

PPI - Parse, Analyze and Manipulate Perl (without perl)

=head1 SYNOPSIS

  use PPI;
  
  # Create a new empty document
  my $Document = PPI::Document->new;
  
  # Create a document from source
  $Document = PPI::Document->new('print "Hello World!\n"');
  
  # Load a Document from a file
  $Document = PPI::Document->load('Module.pm');
  
  # Does it contain any POD?
  if ( $Document->find_any('PPI::Token::Pod') ) {
      print "Module contains POD\n";
  }
  
  # Get the name of the main package
  $pkg = $Document->find_first('PPI::Statement::Package')->namespace;
  
  # Remove all that nasty documentation
  $Document->prune('PPI::Token::Pod');
  $Document->prune('PPI::Token::Comment');
  
  # Save the file
  $Document->save('Module.pm.stripped');

=head1 DESCRIPTION

=head2 About this Document

This is the PPI manual. It describes its reason for existing, its general
structure, its use, an overview of the API, and provides a few
implementation samples.

=head2 Background

The ability to read, and manipulate Perl (the language) programmatically
other than with perl (the application) was one that caused difficulty
for a long time.

The cause of this problem was Perl's complex and dynamic grammar.
Although there are typically not a huge diversity in the grammar of most
Perl code, certain issues cause large problems when it comes to parsing.

Indeed, quite early in Perl's history Tom Christenson introduced the Perl
community to the quote I<"Nothing but perl can parse Perl">, or as it is
more often stated now:

B<"Only perl can parse Perl">

One example of the sorts of things the prevent Perl being easily parsed are
function signatures, as demonstrated by the following.

  @result = (dothis $foo, $bar);
  
  # Which of the following is it equivalent to?
  @result = (dothis($foo), $bar);
  @result = dothis($foo, $bar);

The first line above can be interpreted in two different ways, depending
on whether the C<&dothis> function is expecting one argument, or two,
or several.

A "code parser" (something that parses for the purpose of execution) such
as perl needs information that is not found in the immediate vicinity of
the statement being parsed.

The information might not just be elsewhere in the file, it might not even be
in the same file at all. It might also not be able to determine this
information without the prior execution of a C<BEGIN {}> block, or the
loading and execution of one or more external modules.

B<When parsing Perl as code, you must also execute it>

Even perl itself never really fully understands the structure of the source
code after and indeed B<as> it processes it, and in that sense doesn't
"parse" Perl source into anything remotely like a structured document.
This makes it of no real use for any task that needs to treat the source
code as a document, and do so reliably and robustly.

For more information on why it is impossible to parse perl, see Randal
Schwartz's seminal response to the question of "Why can't you parse Perl".

L<http://www.perlmonks.org/index.pl?node_id=44722>

The purpose of PPI is B<not> to parse Perl I<Code>, but to parse Perl
I<Documents>. By treating the problem this way, we are able to parse a
single file containing Perl source code "isolated" from any other
resources, such as libraries upon which the code may depend, and
without needing to run an instance of perl alongside or inside the parser.

Historically, using an embedded perl parser was one of the potential
solutions for C<Parse::Perl> that was investigated from time to time
and has generally failed or suffered from sufficiently bad corner cases
that these efforts were abandoned).

=head2 What Does PPI Stand For?

C<PPI> is an acronym for the longer original module name
C<Parse::Perl::Isolated>. And in the spirit or the silly acronym games
played by certain unnamed Open Source projects you may have I<heard> of,
it's also a reverse acronym for "I Parse Perl".

Of course, I could just be lying and have just made that second bit up
10 minutes before the release of PPI 1.000. Besides, B<all> the cool
Perl packages have TLAs (Three Letter Acronyms). It's a rule or something.

The name was shortened to prevent the author (and you the users) from
contracting RSI by having to type crazy things like
C<Parse::Perl::Isolated::Token::QuoteLike::Backtick> 100 times a day.

In acknowledgment that someone may some day come up with a valid solution
for the grammar problem it was decided at the commencement of the project
to leave the C<Parse::Perl> namespace free for any such effort.

Since that time I've been able to prove to my own satisfaction that it
B<is> truly impossible to accurately parse Perl as both code and document
at once.

With this in mind C<Parse::Perl> has now been co-opted as the title for
the SourceForge project that publishes PPI and a large collection of other
applications and modules related to the (document) parsing of Perl source
code.

You can find this project at L<http://sf.net/projects/parseperl>.

=head2 Why Parse Perl?

Once you can accept that we will never be able to parse Perl well enough
to meet the standards of things that treat Perl as code, it is worth
re-examining C<why> we want to "parse" Perl at all.

What are the things that people might want a "Perl parser" for.

=over 4

=item Documentation

Analyzing the contents of a Perl document to automatically generate
documentation, in parallel to, or as a replacement for, POD documentation.

=item Structural and Quality Analysis

Determine quality or other metrics across a body of code, and identify
situations relating to particular phrases, techniques or locations.

Index functions, variables and packages within Perl code, and doing search
and graph (in the node/edge sense) analysis of large code bases.

=item Refactoring

Make structural, syntax, or other changes to code in an automated manner,
either independently or in assistance to an editor. This sort of task list
includes backporting, forward porting, partial evaluation, "improving" code,
or whatever. All the sort of things you'd want from a L<Perl::Editor>.

=item Layout

Change the layout of code without changing its meaning. This includes
techniques such as tidying (like L<perltidy>), obfuscation, compressiong and
"squishing", or to implement formatting preferences or policies.

=item Presentation

This includes methods of improving the presentation of code, without changing
the content of the code. Modify, improve, syntax colour etc the presentation
of a Perl document. Generating "IntelliText"-like functions.

=back

If we treat this as a baseline for the sort of things we are going to have
to build on top of Perl, then it becomes possible to identify a standard
for how good a Perl parser needs to be.

=head2 How good is Good Enough(TM)

PPI seeks to be good enough to achieve all of the above tasks, or to provide
a sufficiently good API on which to allow others to implement modules in
these and related areas.

However, there are going to be limits to this process. Because PPI cannot
adapt to changing grammars, any code written using source filters should not
be assumed to be parsable.

At one extreme, this includes anything munged by L<Acme::Bleach>, as well
as (arguably) more common cases like L<Switch>. We do not pretend to be
able to always parse code using these modules, although as long as it still
follows a format that looks like Perl syntax, it may be possible to extend
the lexer to handle them.

The ability to extend PPI to handle lexical additions to the language is on
the drawing board to be done some time post-1.0

The goal for success was originally to be able to successfully parse 99% of
all Perl documents contained in CPAN. This means the entire file in each
case.

PPI has succeeded in this goal far beyond the expectations of even the
author. At time of writing there are only 28 non-Acme Perl files in CPAN
that PPI is incapable of parsing. Most of these are so badly broken they
do not compile as Perl code either.

So unless you are actively going out of your way to break PPI, you should
expect that it will handle your code.

=head1 IMPLEMENTATION

=head2 General Layout

PPI is built upon two primary "parsing" components, L<PPI::Tokenizer>
and L<PPI::Lexer>, and a large tree of about 50 classes which implement
the various the I<Perl Document Object Model> (PDOM).

The PDOM is conceptually similar in style and intent to the regular DOM or
other code ASTs, but contains many differences to handle perl-specific cases,
and to assist in treating the code as a document.

On top of the Tokenizer, Lexer and the classes of the PDOM, sit a number
of classes intended to make life a little easier when dealing with PDOM
trees.

Both the major parsing components were hand-coded from scratch with only
plain Perl code and a few small utility modules. There are no grammar or
patterns mini-languages, no YACC or LEX style tools and only a small number
of regular expressions.

This is primarily because of the sheer volume of accumulated cruft that
exists in Perl. Not even perl itself is capable of parsing Perl documents
(remember, it just parses and executes it as code).

As a result, PPI needed to be cruftier than perl itself. Feel free to
shudder at this point, and hope you never have to understand the Tokenizer
codebase. Speaking of which...

=head2 The Tokenizer

The Tokenizer takes source code and converts it into a series of tokens. It
does this using a slow but thorough character by character manual process,
rather than using a pattern system or complex regexs.

Or at least it does so conceptually. If you were to actually trace the code
you would find it's not truly character by character due to a number if
support regexps scattered throughout the code. This lets the Tokenizer
skip ahead" when it can find shortcuts, so it tends to jump around a line
a bit wildly at times.

Practically, the number of times the Tokenizer will B<actually> move the
character cursor itself is only about 5% - 10% higher than the number of
tokens contained in the file.

In 2001 when PPI was started, this structure made PPI quote slow, and not
really suitable for interactive tasks. This situation has improved greatly
with multi-gigahertz processors, but can still be painful when working with
very large files.

The target speed rate for PPI is about 5000 lines per gigacycle. It is
currently believed to be at about 1500, and main avenue for making it to
the target speed has now become L<PPI::XS>, a drop-in XS accelerator for
PPI.

Since L<PPI::XS> has only just gotten off the ground and is currently only
at proof-of-concept stage, this may take a little while. Anyone interested
in helping out with L<PPI::XS> is B<highly> encouraged to contact the
author.

=head2 The Lexer

The Lexer takes a token stream, and converts it to a lexical tree. Because
we are parsing Perl B<documents> this includes whitespace, comments, and
all number of weird things that have no relevance when code is actually
executed.

An instantiated L<PPI::Lexer> consumes L<PPI::Tokenizer> objects and
produces L<PPI::Document> objects. However you should probably never be
working with the Lexer directly. You should just be able to create
L<PPI::Document> objects and work with them directly.

=head2 Round Trip Safe

When PPI parser a file it builds B<everything> into the model, including
whitespace. This is needed in order to make the Document fully "Round Trip"
safe.

The general concept behind a "Round Trip" parser is that it knows what it
is parsing is somewhat uncertain, and so B<expects> to get things wrong
from time to time. In the cases where it parsers code wrongly the tree
will serialize back out to the same string of code that was read in,
repairing the parser's mistake is it heads back out to the file.

The end result is that if you parse in a file and serialize it back out
without changing the tree, you are guarenteed to get the same file you
started with. PPI does this correctly and reliably for 100% of all known
cases.

B<What goes in, will come out. Every time.>

The one minor exception at this time is that if the newlines for your file
are wrong, PPI may perform a localisation of them for you. Better control
of the newline type is a road map item for version 1.100.

=head1 THE PERL DOCUMENT OBJECT MODEL

The PDOM is a structured collection of data classes that together provide
a correct and scalable model for documents that follow the standard Perl
syntax.

=head2 The PDOM Class Tree

The following lists all of the 62 current PDOM classes, listing with indentation
based on inheritance.

   PPI::Element
      PPI::Node
         PPI::Document
            PPI::Document::Fragment
         PPI::Statement
            PPI::Statement::Scheduled
            PPI::Statement::Package
            PPI::Statement::Include
            PPI::Statement::Sub
            PPI::Statement::Compound
            PPI::Statement::Break
            PPI::Statement::Data
            PPI::Statement::End
            PPI::Statement::Expression
               PPI::Statement::Variable
            PPI::Statement::Null
            PPI::Statement::UnmatchedBrace
            PPI::Statement::Unknown
         PPI::Structure
            PPI::Structure::Block
            PPI::Structure::Subscript
            PPI::Structure::Constructor
            PPI::Structure::Condition
            PPI::Structure::List
            PPI::Structure::ForLoop
            PPI::Structure::Unknown
      PPI::Token
         PPI::Token::Whitespace
         PPI::Token::Comment
         PPI::Token::Pod
         PPI::Token::Number
         PPI::Token::Word
         PPI::Token::DashedWord
         PPI::Token::Symbol
            PPI::Token::Magic
         PPI::Token::ArrayIndex
         PPI::Token::Operator
         PPI::Token::Quote
            PPI::Token::Quote::Single
            PPI::Token::Quote::Double
            PPI::Token::Quote::Literal
            PPI::Token::Quote::Interpolate
         PPI::Token::QuoteLike
            PPI::Token::QuoteLike::Backtick
            PPI::Token::QuoteLike::Command
            PPI::Token::QuoteLike::Regexp
            PPI::Token::QuoteLike::Words
            PPI::Token::QuoteLike::Readline
         PPI::Token::Regexp
            PPI::Token::Regexp::Match
            PPI::Token::Regexp::Substitute
            PPI::Token::Regexp::Transliterate
         PPI::Token::HereDoc
         PPI::Token::Cast
         PPI::Token::Structure
         PPI::Token::Label
         PPI::Token::Separator
         PPI::Token::Data
         PPI::Token::End
         PPI::Token::Prototype
         PPI::Token::Attribute
         PPI::Token::Unknown

To summarize the above layout, all PDOM objects inherit from the
L<PPI::Element> class.

Under this are L<PPI::Token>, strings of content with a known type,
and L<PPI::Node>, syntactically significant containers that hold other
Elements.

The three most important of these are the L<PPI::Document>, the
L<PPI::Statement> and the L<PPI::Structure> classes.

=head2 The Document, Statement and Structure

At the top of all complete PDOM trees is a L<PPI::Document> object. It
represents a complete file of Perl source code as you might find it on
disk.

Each Document will contain a number of B<Statements>, B<Structures> and
B<Tokens>.

A L<PPI::Statement> is any series of Tokens and Structures that are treated
as a single contiguous statement by perl itself. You should note that a
Statement is as close as PPI can get to "parsing" the code in the sense that
perl-itself parses Perl code when it is building the op-tree. Because of the
assumed isolation, PPI cannot accurately determine precedence of operators
or which tokens are implicit arguments to a sub call.

So rather than lead you on with a bad guess, PPI does not attempt to
determine precedence or sub paramaters at all.

At a fundamental level, it only knows that this series of elements represents
a single Statement as perl sees it, and does so with reasonable certainty.

However for specific Statement types the PDOM is able to derive additional
useful information about their meaning. For the best and most heavily used
example, see L<PPI::Statement::Include>.

A L<PPI::Structure> is any series of tokens contained within matching braces.
This includes code blocks, conditions, function argument braces, anonymous
array constructors, lists, scoping braces and all other syntactic structures
represented by a matching pair of braces, including C<E<lt>READLINEE<gt>>
braces.

Each Structure contains none, one, or many Tokens and Structures (the rules
for which vary for the different Structure subclasses)

In the PDOM structure rules, a Statement can B<never> directly contain another
child Statement, a Structure can B<never> directly contain another child
Structure, and a Document can B<never> contain another Document anywhere in
the tree.

Aside from these three rules, the PDOM tree is extremely flexible.

=head2 The PDOM at Work

To demonstrate the PDOM in use lets start with an example showing how the
PDOM tree might look for the following chunk of simple Perl code.

  #!/usr/bin/perl

  print( "Hello World!" );

  exit();

Translated into a PDOM tree it would have the following structure.

  PPI::Document
    PPI::Token::Comment                '#!/usr/bin/perl\n'
    PPI::Token::Whitespace             '\n'
    PPI::Statement
      PPI::Token::Bareword             'print'
      PPI::Structure::List             ( ... )
        PPI::Token::Whitespace         ' '
        PPI::Statement::Expression
          PPI::Token::Quote::Double    '"Hello World!"'
        PPI::Token::Whitespace         ' '
      PPI::Token::Structure            ';'
    PPI::Token::Whitespace             '\n'
    PPI::Token::Whitespace             '\n'
    PPI::Statement
      PPI::Token::Bareword             'exit'
      PPI::Structure::List             ( ... )
      PPI::Token::Structure            ';'
    PPI::Token::Whitespace             '\n'

Please note that in this this example, strings are only listed for the
B<actual> L<PPI::Token> that contains that string. Structures are listed
with the type of brace characters it represents noted.

The L<PPI::Dumper> module can be used to generate similar trees yourself.

We can make that PDOM dump a little easier to read if we strip out all the
whitespace. Here it is again, sans the distracting whitespace tokens.

  PPI::Document
    PPI::Token::Comment                '#!/usr/bin/perl\n'
    PPI::Statement
      PPI::Token::Bareword             'print'
      PPI::Structure::List             ( ... )
        PPI::Statement::Expression
          PPI::Token::Quote::Double    '"Hello World!"'
      PPI::Token::Structure            ';'
    PPI::Statement
      PPI::Token::Bareword             'exit'
      PPI::Structure::List             ( ... )
      PPI::Token::Structure            ';'

As you can see, the tree can get fairly deep at time, especially when every
isolated token in a bracket becomes its own statement. This is needed to
allow anything inside the tree the ability to grow. It also makes the
search and analysis algorithms much more flexible.

Because of the depth and complexity of PDOM trees, a vast number of very easy
to use methods have been added wherever possible to help people working with
PDOM trees do normal tasks relatively quickly and efficiently.

=head2 Overview of the Primary Classes

The main PPI classes, and links to their own documentation, are listed
here in alphabetical order.

=over 4

=item L<PPI::Document>

The Document object, the root of the PDOM.

=item L<PPI::Document::Fragment>

A cohesive fragment of a larger Document. Although not of any real current
use, it is planned for use in certain internal tree manipulation
algortihms.

For example, doing things like cut/copy/paste etc. Very similar to a
L<PPI::Document>, but has some additional methods and does not represent
a lexical scope boundary.

=item L<PPI::Dumper>

A simple class for dumping readable debugging version of PDOM structures,
such as in the demonstration above.

=item L<PPI::Element>

The Element class is the abstract base class for all objects within the PDOM

=item L<PPI::Find>

Implements an instantiable object form of a PDOM tree search.

=item L<PPI::Lexer>

The PPI Lexer. Converts Token streams into PDOM trees.

=item L<PPI::Node>

The Node object, the abstract base class for all PDOM objects that can
contain other Elements, such as the Document, Statement and Structure
objects.

=item L<PPI::Statement>

The base class for all Perl statements. Generic "evaluate for side-effects"
statements are of this actual type. Other more interesting statement types
belong to one of its children.

See it's own documentation for a longer description and list of all of the
different statement types and sub-classes.

=item L<PPI::Structure>

The abstract base class for all structures. A Structure is a language
construct consisting of matching braces containing a set of other elements.

See the L<PPI::Structure> documentation for a description and
list of all of the different structure types and sub-classes.

=item L<PPI::Token>

A token is the basic unit of content. At its most basic, a Token is just
a string tagged with metadata (its class, and some additional flags in
some cases).

=item L<PPI::Token::_QuoteEngine>

The L<PPI::Token::Quote> and L<PPI::Token::QuoteLike> classes provide
abstract base classes for the many and varied types of quote and
quote-like things in Perl. However, much of the actual quote login is
implemented in a separate quote engine, based at
L<PPI::Token::_QuoteEngine>.

Classes that inherit from L<PPI::Token::Quote>, L<PPI::Token::QuoteLike>
and L<PPI::Token::Regexp> are generally parsed only by the Quote Engine.

=item L<PPI::Tokenizer>

The PPI Tokenizer. One Tokenizer consumes a chunk of text and provides
access to a stream of L<PPI::Token> objects.

The Tokenizer is very very complicated, to the point where even the author
treads carefully when working with it.

Most of the complication is the result of optimizations which have tripled
the tokenization speed, at the expense of maintainability. We cope with the
spagetti by heavily commenting everything.

=item L<PPI::Transform>

The Perl Document Transformation API. Provides a standard interface and
abstract base class for objects and classes that manipulate Documents.

=back

=head1 INSTALLING

The core PPI distribution is pure Perl and has been kept as tight as
possible and with as few dependencies as possible.

It should download and install normally on any platform from within
the CPAN and CPANPLUS applications, or directly using the distribution
tarball. If installing by hand, you may need to install a few small
utility modules first. The exact ones will depend on your version of
perl.

There are no special install instructions for PPI, and the normal
C<Perl Makefile.PL>, C<make>, C<make test>, C<make install> instructions
apply.

=head1 EXTENDING

The PPI namespace itself is reserved for the sole use of the modules under
the umbrella of the C<Parse::Perl> SourceForge project.

L<http://sf.net/parseperl>

You are recommended to use the PPIx:: namespace for PPI-specific
modifications or prototypes thereof, or Perl:: for modules which provide
a general Perl language-related functions.

If what you wish to implement looks like it fits into PPIx:: namespace,
you should consider contacting the C<Parse::Perl> mailing list (detailed on
the SourceForge site) first, as what you want may already be in progress,
or you may wish to consider joining the team and doing it within the
C<Parse::Perl> project itself.

=head1 TO DO

- Many more analysis and utility methods for PDOM classes (post 1.000)

- Creation of a PPI::Tutorial document (post 1.000)

- We can _always_ write more and better unit tests

- Add better support for tabs (1.100)

- Add better handling of non-local newlines (due 1.100)

- Full understanding of scoping (due 1.100)

- Add many more key functions to PPI::XS (post 1.000)

=head1 SUPPORT

Bugs should be always be reported vi the following URI

L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=PPI>

When reporting bugs, you are B<highly> recommended to include test
cases if at all possible, as the odds are by the time you are
submitting a bug you understand what should actually happen better
than the authors.

Test fragments are fine, or in larger cases simply copy/paste one of
the other small test scripts and replace the contents with your own
tests.

For other issues or questions, contact the C<Parse::Perl> project mailing
list.

For commercial or media issues, contact the author.

=head1 AUTHOR

Adam Kennedy <cpan@ali.as>, L<http://ali.as/>

=head1 ACKNOWLEDGMENTS

A huge thank you to Phase N Australia (L<http://phase-n.com/>) for
permitting the original open sourcing and release of this distribution
from what was originally several thousand hours of commercial work.

Another big thank you to The Perl Foundation
(L<http://www.perlfoundation.org/>) for funding for the final big
refactoring and completion run.

Most of all, thanks to those brave soles willing to dive in and use,
test drive and provide feedback on PPI, in a few cases before it was
tamed and ready, and still did extremely distasteful things to you like
eating 50 meg of RAM a second.

I owe you all a beer. Corner me somewhere and collect at your convenience.
If I missed someone who wasn't in my email history, thank you too :)

  # In approximate order of appearance
  - Claes Jacobsson
  - Michael Schwern
  - Jeff T. Parsons
  - CPAN Author "CHOCOLATEBOY"
  - Robert Rotherberg
  - CPAN Author "PODMASTER"
  - Richard Soderberg
  - Nadim ibn Hamouda el Khemir
  - Graciliano M. P.
  - Leon Brocard
  - Jody Belka
  - Curtis Ovid
  - Yuval Kogman
  - Michael Schilli
  - Slaven Rezic
  - Lars Thegler
  - Tony Stubblebine
  - Tatsuhiko Miyagawa
  - CPAN Author "CHROMATIC"
  - Matisse Enzer
  - Roy Fulbright
  - Dan Brook
  - Johnny Lee
  - Johan Lindstrom

And to single one person out, thank you to Randal Schwartz who (mostly)
patiently spent a great number of hours in IRC over a critical 6 month
period "aggresively explaining" why Perl is impossibly unparsable and
shoving evil and ugly corner cases in my face.

=head1 COPYRIGHT

Copyright (c) 2001 - 2005 Adam Kennedy. All rights reserved.

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut
