#!/usr/bin/env perl
package PaleWhite::GlassParser;
use parent 'Sugar::Lang::BaseSyntaxParser';
use strict;
use warnings;

use feature 'say';





##############################
##### variables and settings
##############################

our $var_identifier_regex = qr/[a-zA-Z_][a-zA-Z0-9_]*+/;
our $var_symbol_regex = qr/!|\.|\#/;
our $var_indent_regex = qr/\t++/;
our $var_whitespace_regex = qr/[\t \r]++/;
our $var_newline_regex = qr/\s*\n/s;


our $tokens = [
	'identifier' => $var_identifier_regex,
	'symbol' => $var_symbol_regex,
	'indent' => $var_indent_regex,
	'whitespace' => $var_whitespace_regex,
	'newline' => $var_newline_regex,
];

our $ignored_tokens = [
	'whitespace',
];

our $contexts = {
	glass_block => 'context_glass_block',
	glass_item => 'context_glass_item',
	root => 'context_root',
	root_glass_block => 'context_root_glass_block',
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


sub context_root {
	my ($self) = @_;
	my $context_object = {};

	while ($self->more_tokens) {
		my @tokens;

			$context_object = $self->context_root_glass_block({ type => 'root', block => [], indent => '', });
			return $context_object;
	}
	return $context_object;
}

sub context_root_glass_block {
	my ($self, $context_object) = @_;

	while ($self->more_tokens) {
		my @tokens;

			while ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A$var_newline_regex\Z/) {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			}
			if ($self->more_tokens and $self->match_indent($self->{tokens_index} + 0, $context_object)) {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			push @{$context_object->{block}}, $self->context_glass_block($self->context_glass_item($tokens[0][1]));
			}
			else {
			push @{$context_object->{block}}, $self->context_glass_block($self->context_glass_item(''));
			}
	}
	return $context_object;
}

sub context_glass_block {
	my ($self, $context_object) = @_;

	while ($self->more_tokens) {
		my @tokens;

			while ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A$var_newline_regex\Z/) {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			}
			if ($self->more_tokens and $self->match_indent($self->{tokens_index} + 0, $context_object)) {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			push @{$context_object->{block}}, $self->context_glass_block($self->context_glass_item($tokens[0][1]));
			}
			else {
			return $context_object;
			}
	}
	return $context_object;
}

sub context_glass_item {
	my ($self, $context_object) = @_;

	while ($self->more_tokens) {
		my @tokens;

			if ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A$var_identifier_regex\Z/) {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			$context_object = { type => 'html_tag', line_number => $tokens[0][2], identifier => $tokens[0][1], indent => $context_object, };
			return $context_object;
			}
			else {
			$self->confess_at_current_offset('glass item expected');
			}
	}
	return $context_object;
}


##############################
##### native perl functions
##############################

sub match_indent {
	my ($self, $offset, $item) = @_;
	return ($self->{tokens}[$offset][1] =~ /\A\t++\Z/
		and length $self->{tokens}[$offset][1] > length $item->{indent})
}

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


