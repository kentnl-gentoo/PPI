package PPI::Manual;

=pod

=head1 NAME PPI Manual

=head1 DESCRIPTION

=head2 About this Document

This is the PPI ( Parse::Perl::Isolated ) user manual. It describes PPI,
it's structure, it's use, an overview of it's API, and provides
implementation samples.

=head2 Background

The ability to read, and understand perl ( programmatically ) outside of
the perl executable is one that has caused difficulty for a very long time.

The root cause of this problem is perl's dynamic grammer. Although there
are typically not huge differences in the grammer, some things cause
large problems.

An example of these are function signatures, as demonstrated by the following.

  @result = (&dothis $foo, $bar);

  # Which of the following is it equivalent to?
  @result = (&dothis($foo), $bar);
  @result = &dothis($foo, $bar);

This code can be interpreted in two different ways, depending on whether the
C<&dothis> function is expecting one argument, or two, or several.

To restate thie, a parser would need context information that could not be
found in the immediate vicinity. In fact, this information might not even
be in the same file. It might also not be able to determine this without
the prior execution of a BEGIN {} block. In other words, to parse perl, you
must also execute it, or if not it, everything that it depends on for it's
grammer.

This, while possibly feasable in some circumstances, is not a valid solution
( at least, so far as this module is concerned ). Imagine trying to parse some
code that had a dependency on the C<Win32::*> modules from a Unix machine, or
trying to parse some code with a dependency on another module that had not
even been written yet...

=head2 Why "Isolated"?

In aknowledgement that someone may some day come up with a valid solution for
this problem, this module leaves the C<Parse::Perl> namespace free. The
namespace of Parse::Perl::Isolated ( shortened to PPI ), has been chosen
because our purpose here is only to "parse" perl code that is isolated from
other resources. That is, we assume that there is no possiblity of accessing
other code on which we have a dependency, or of running an instance of perl
alongside the parser ( a possible solution for Parse::Perl that is
investigated from time to time ).

=head2 Goals of PPI

Once we have recognised that an attempt to parse perl well enough to execute
it either impossible or beyond an immediate solution, it is important we
establish just what uses we want to put a Parse::Perl type module to.

=over

=item Presentation / Colouring etc

Modify, improve, syntax colour etc the presentation of code.

=item Documentation

Analyze the contents of code to automatically generate documentation,
parrellel to, or as a replacement for, POD documentation.

=item Structural Analysis

Determine quality or other metrics across a body of code, and identify
situations relating to particular phrases, techniques or locations.

=item Refactoring

Make structural, syntax, or other changes to code in an automated manner,
independantly, or in assistance to an editor.

=item Layout

This includes techniques such as tidying ( ala perltidy ), obfuscation, or
to implement formatting preferences or policies.

=back

As long as the above tasks can be achieved, without damaging code, then
PPI can be considered to be a success.

=head2 Good Enough(TM)

With the above tasks in mind, PPI seeks to be good enough to achieve the
above tasks within a single framework, and provide a sufficient good API
to allow others to implement code in these and related areas.

However, some limits are applied. Because PPI cannot adapt to changing
grammers, any code written using code filters should not assume to be
parsable. This includes anything munged by Acme::Bleach, as well as
( arguably ) more common cases like Switch.pm and Exception.pm. We do
not assume to be able to parse code using these modules, although someone
may be able to extend PPI to handle them.

Our goals for success are to be able to successfully parse 99% of all
perl source files contained in CPAN. This means the entire file in each
case. In pratical tests, we actually do much better. Aside from very
intentionally nasty things, the only code which we currently fail to parse
is the "selfgol" obscured code entry. We are in fact able to parse most
obscured code, but selfgol uses the sub definition C<sub'new>, an
apparently special case which is equivalent to C<sub ::new> and not
C<sub::new>.

=head1 IMPLEMENTATION

=head2 General Layout

PPI has two major parsing componants, L<PPI::Tokenizer> and L<PPI::Lexer>,
upon which everything else is based.

=head2 The Tokenizer

The Tokenizer takes source code and converts it into a series of tokens. It
does this using a slow but thorough character by character manual process,
rather than using complex regexs. Currently, this implementation means that
PPI is not of use for highly interactive tasks, such as an editor which
checks and formats code on the fly.

How slow? As an example, tokenizing CPAN.pm, a 7112 line, 40,000 token file
takes about 5 seconds on my little Duron 800 test server. So you should
expect the tokenizer to work at a rate of about 1700 lines of code per
gigacycle. The code is currently being optomised, and there is plenty of
scope remaining for speed improvements, but it is fairly slow work. The
target rate is about 5000 lines per gigacycle.

=head2 The Lexer

The Lexer is currently structurally complete, but lacks a fair percentage
of it's logic code, especially relating to code blocks.

At the top level of all lex trees is the L<PPI::Document>. This will contain
non-significant tokens ( whitespace, comments, pod etc ), as well as
statements and structure. A L<PPI::Structure> is any series of tokens
terminated by matching braces ( with a few exceptions ). This includes
things like code blocks, conditionals, function argument braces, anonymous
array square brackets et al. A L<PPI::Statement> is any series of tokens
that is included in a single contigious statement.

The following example shows how Statements and Structures nest.

  PPI::Statement      "Hello World!"
  PPI::Structure      ( "Hello World!" )
  PPI::Statement      print( "Hello World!" );
  PPI::Document       #!/usr/bin/perl
                      print( "Hello World!" );

As you can see, a statement can have as little as one token. The actual nested
structure for some code would look something like this.

  #!/usr/bin/perl

  print( "Hello World!" );

  exit();

  PPI::Document
    PPI::Token::Comment               "#!/usr/bin/perl\n"
    PPI::Token::Whitespace                  "\n"
    PPI::Statement
      PPI::Token::Bareword            'print'
        PPI::Structure                '(' ... ')'
          PPI::Token::Whitespace            ' '
          PPI::Statement
            PPI::Token::Quote::Double '"Hello World!"'
          PPI::Token::Whitespace            ' '
      PPI::Token::Structure           ';'
    PPI::Token::Whitespace                  "\n"
    PPI::Token::Whitespace                  "\n"
    PPI::Statement
      PPI::Token::Bareword            'exit'
      PPI::Structure                  '(' ... ')'
      PPI::Token::Structure           ';'
    PPI::Token::Whitespace                  "\n"


As you can see, the tree can get fairly deep at time, especially when every
isolated token in a bracket becomes it's own statement. This is needed to
allow anything inside the tree the ability to grow. It also makes the
search and analysis algorithms simpler.







=cut

1;
