#!/usr/bin/env perl
package PaleWhite::ModelParser;
use parent 'Sugar::Lang::BaseSyntaxParser';
use strict;
use warnings;

use feature 'say';





##############################
##### variables and settings
##############################

our $var_native_code_block_regex = qr/\{\{.*?\}\}/s;
our $var_symbol_regex = qr/\{|\}|\[|\]|\(|\)|;/;
our $var_keyword_regex = qr/\b(model|int|string|getter|setter|cast|to|from|static|function)\b/;
our $var_identifier_regex = qr/[a-zA-Z_][a-zA-Z0-9_]*+/;
our $var_integer_regex = qr/\d++/;
our $var_comment_regex = qr/\/\/[^\n]*+\n/s;
our $var_whitespace_regex = qr/\s++/s;
our $var_format_native_code_substitution = sub { $_[0] =~ s/\A\{(\{.*?\})\}\Z/$1/sr };


our $tokens = [
	'native_code_block' => $var_native_code_block_regex,
	'symbol' => $var_symbol_regex,
	'keyword' => $var_keyword_regex,
	'identifier' => $var_identifier_regex,
	'integer' => $var_integer_regex,
	'comment' => $var_comment_regex,
	'whitespace' => $var_whitespace_regex,
];

our $ignored_tokens = [
	'whitespace',
	'comment',
];

our $contexts = {
	model_block => 'context_model_block',
	model_property => 'context_model_property',
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


sub context_root {
	my ($self) = @_;
	my $context_list = [];

	while ($self->more_tokens) {
		my @tokens;

			if ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'model') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			$self->confess_at_current_offset('expected qr/[a-zA-Z_][a-zA-Z0-9_]*+/, \'{\'')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A$var_identifier_regex\Z/ and $self->{tokens}[$self->{tokens_index} + 1][1] eq '{';
			@tokens = (@tokens, $self->step_tokens(2));
			push @$context_list, $self->context_model_block({ type => 'model_definition', identifier => $tokens[1][1], });
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

sub context_model_block {
	my ($self, $context_object) = @_;

	while ($self->more_tokens) {
		my @tokens;

			if ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'function') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			$self->confess_at_current_offset('expected qr/[a-zA-Z_][a-zA-Z0-9_]*+/, \'(\'')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A$var_identifier_regex\Z/ and $self->{tokens}[$self->{tokens_index} + 1][1] eq '(';
			@tokens = (@tokens, $self->step_tokens(2));
			$self->confess_at_current_offset('expected \')\', qr/\\{\\{.*?\\}\\}/s')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq ')' and $self->{tokens}[$self->{tokens_index} + 1][1] =~ /\A$var_native_code_block_regex\Z/;
			@tokens = (@tokens, $self->step_tokens(2));
			push @{$context_object->{functions}}, { type => 'model_function', identifier => $tokens[1][1], code => $var_format_native_code_substitution->($tokens[4][1]), };
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'static' and $self->{tokens}[$self->{tokens_index} + 1][1] eq 'function') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(2));
			$self->confess_at_current_offset('expected qr/[a-zA-Z_][a-zA-Z0-9_]*+/, \'(\'')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A$var_identifier_regex\Z/ and $self->{tokens}[$self->{tokens_index} + 1][1] eq '(';
			@tokens = (@tokens, $self->step_tokens(2));
			$self->confess_at_current_offset('expected \')\', qr/\\{\\{.*?\\}\\}/s')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq ')' and $self->{tokens}[$self->{tokens_index} + 1][1] =~ /\A$var_native_code_block_regex\Z/;
			@tokens = (@tokens, $self->step_tokens(2));
			push @{$context_object->{functions}}, { type => 'model_static_function', identifier => $tokens[2][1], code => $var_format_native_code_substitution->($tokens[5][1]), };
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A$var_identifier_regex\Z/) {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			$self->confess_at_current_offset('expected qr/[a-zA-Z_][a-zA-Z0-9_]*+/')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A$var_identifier_regex\Z/;
			@tokens = (@tokens, $self->step_tokens(1));
			push @{$context_object->{properties}}, $self->context_model_property({ type => 'model_property', property_type => $tokens[0][1], identifier => $tokens[1][1], });
			$self->confess_at_current_offset('expected \';\'')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq ';';
			@tokens = (@tokens, $self->step_tokens(1));
			}
			else {
			return $context_object;
			}
	}
	return $context_object;
}

sub context_model_property {
	my ($self, $context_object) = @_;

	while ($self->more_tokens) {
		my @tokens;

			if ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'unique_key') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			$context_object->{modifiers}{$tokens[0][1]} = 'enabled';
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'auto_increment') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			$context_object->{modifiers}{$tokens[0][1]} = 'enabled';
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


