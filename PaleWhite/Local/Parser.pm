#!/usr/bin/env perl
package PaleWhite::Local::Parser;
use parent 'Sugar::Lang::BaseSyntaxParser';
use strict;
use warnings;

use feature 'say';





##############################
##### variables and settings
##############################

our $var_symbol_regex = qr/\{|\}|\[|\]|\(|\)|;|:|=>|->|<|>|<=|>=|==|=|,|\.|\*|\?|!|\-|\+/;
our $var_identifier_regex = qr/[a-zA-Z_][a-zA-Z0-9_]*+/;
our $var_integer_regex = qr/-?\d++/;
our $var_string_regex = qr/"([^\\"]|\\[\\"])*?"/s;
our $var_comment_regex = qr/#[^\n]*+\n/s;
our $var_whitespace_regex = qr/\s++/s;
our $var_escape_string_substitution = sub { $_[0] =~ s/\\([\\"])/$1/gsr };
our $var_format_string_substitution = sub { $_[0] =~ s/\A"(.*)"\Z/$1/sr };


our $tokens = [
	'symbol' => $var_symbol_regex,
	'identifier' => $var_identifier_regex,
	'integer' => $var_integer_regex,
	'string' => $var_string_regex,
	'comment' => $var_comment_regex,
	'whitespace' => $var_whitespace_regex,
];

our $ignored_tokens = [
	'whitespace',
	'comment',
];

our $contexts = {
	format_string => 'context_format_string',
	localization_block => 'context_localization_block',
	root => 'context_root',
};



##############################
##### api
##############################



sub new {
	my ($class, %opts) = @_;

	$opts{token_regexes} = $tokens;
	$opts{ignored_tokens} = $ignored_tokens;
	$opts{contexts} = $contexts;

	my $self = $class->SUPER::new(%opts);

	return $self
}

sub parse {
	my ($self, @args) = @_;
	return $self->SUPER::parse(@args)
}



##############################
##### sugar contexts functions
##############################


sub context_format_string {
	my ($self, $context_value) = @_;
	my @tokens;

			$context_value = $var_escape_string_substitution->($var_format_string_substitution->($context_value));
			return $context_value;
}

sub context_root {
	my ($self) = @_;
	my $context_list = [];

	while ($self->more_tokens) {
	my @tokens;

			if ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'localization' and $self->{tokens}[$self->{tokens_index} + 1][1] =~ /\A($var_identifier_regex)\Z/ and $self->{tokens}[$self->{tokens_index} + 2][1] eq ':' and $self->{tokens}[$self->{tokens_index} + 3][1] =~ /\A($var_identifier_regex)\Z/ and $self->{tokens}[$self->{tokens_index} + 4][1] eq '{') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(5));
			push @$context_list, $self->context_localization_block({ type => 'localization_definition', line_number => $tokens[0][2], identifier => $tokens[1][1], localization_identifier => $tokens[3][1], });
			$self->confess_at_current_offset('expected \'}\'')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '}';
			@tokens = (@tokens, $self->step_tokens(1));
			}
			else {
			$self->confess_at_current_offset('block statement expected');
			}
	}
	return $context_list;
}

sub context_localization_block {
	my ($self, $context_object) = @_;

	while ($self->more_tokens) {
	my @tokens;

			if ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A($var_identifier_regex)\Z/ and $self->{tokens}[$self->{tokens_index} + 1][1] eq '=' and $self->{tokens}[$self->{tokens_index} + 2][1] =~ /\A($var_string_regex)\Z/) {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(3));
			push @{$context_object->{fields}}, { type => 'string_field', line_number => $tokens[0][2], identifier => $tokens[0][1], value => $self->context_format_string($tokens[2][1]), };
			}
			else {
			return $context_object;
			}
	}
	return $context_object;
}


##############################
##### native perl functions
##############################

sub main {
	use Data::Dumper;
	use Sugar::IO::File;

	my $parser = __PACKAGE__->new;
	foreach my $file (@_) {
		$parser->{filepath} = Sugar::IO::File->new($file);
		my $tree = $parser->parse;
		say Dumper $tree;
	}
}

caller or main(@ARGV);


