package PPI::Statement::Include;

# Commands that call in other files ( or 'uncall' them :/ )
# use, no and require.
### Should require should be a function, not a special statement?

use strict;
use UNIVERSAL 'isa';
use base 'PPI::Statement';

use vars qw{$VERSION};
BEGIN {
	$VERSION = '0.828';
}

sub type {
	my $self = shift;
	my $keyword = $self->schild(0) or return undef;
	isa($keyword, 'PPI::Token::Word') and $keyword->content;
}

sub module {
	my $self = shift;
	my $module = $self->schild(1) or return undef;
	isa($module, 'PPI::Token::Word') and $module->content;
}

sub pragma {
	my $self = shift;
	my $module = $self->module or return '';
	$module =~ /^[a-z]/ ? $module : '';
}

sub version {
	my $self = shift;
	my $module = $self->module or return '';
	$module =~ /^\d/ ? $module : '';
}

1;
