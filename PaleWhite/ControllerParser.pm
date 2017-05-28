#!/usr/bin/env perl
package PaleWhite::ControllerParser;
use parent 'Sugar::Lang::BaseSyntaxParser';
use strict;
use warnings;

use feature 'say';





##############################
##### variables and settings
##############################

our $var_native_code_block_regex = qr/\{\{.*?\}\}/s;
our $var_symbol_regex = qr/\{|\}|\[|\]|\(|\)|;|=|,/;
our $var_identifier_regex = qr/[a-zA-Z_][a-zA-Z0-9_]*+/;
our $var_integer_regex = qr/\d++/;
our $var_string_regex = qr/"([^\\"]|\\[\\"])*?"/s;
our $var_comment_regex = qr/\/\/[^\n]*+\n/s;
our $var_whitespace_regex = qr/\s++/s;
our $var_format_native_code_substitution = sub { $_[0] =~ s/\A\{\{\s*\n(.*?)\s*\}\}\Z/$1/sr };
our $var_escape_string_substitution = sub { $_[0] =~ s/\\([\\"])/$1/gsr };
our $var_format_string_substitution = sub { $_[0] =~ s/\A"(.*)"\Z/$1/sr };


our $tokens = [
	'native_code_block' => $var_native_code_block_regex,
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
	action_arguments => 'context_action_arguments',
	action_expression => 'context_action_expression',
	arguments_list => 'context_arguments_list',
	controller_block => 'context_controller_block',
	format_native_code => 'context_format_native_code',
	format_string => 'context_format_string',
	path_action_block => 'context_path_action_block',
	path_action_block_list => 'context_path_action_block_list',
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

			if ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'controller') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			$self->confess_at_current_offset('expected qr/[a-zA-Z_][a-zA-Z0-9_]*+/, \'{\'')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A$var_identifier_regex\Z/ and $self->{tokens}[$self->{tokens_index} + 1][1] eq '{';
			@tokens = (@tokens, $self->step_tokens(2));
			push @$context_list, $self->context_controller_block({ type => 'controller_definition', line_number => $tokens[0][2], identifier => $tokens[1][1], });
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

sub context_controller_block {
	my ($self, $context_object) = @_;

	while ($self->more_tokens) {
		my @tokens;

			if ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'path') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			$self->confess_at_current_offset('expected qr/"([^\\\\"]|\\\\[\\\\"])*?"/s')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A$var_string_regex\Z/;
			@tokens = (@tokens, $self->step_tokens(1));
			if ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '[') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			push @{$context_object->{paths}}, $self->context_path_action_block({ type => 'match_path', line_number => $tokens[0][2], path => $self->context_format_string($tokens[1][1]), arguments => $self->context_arguments_list([]), block => [], });
			}
			else {
			push @{$context_object->{paths}}, $self->context_path_action_block({ type => 'match_path', line_number => $tokens[0][2], path => $self->context_format_string($tokens[1][1]), arguments => [], block => [], });
			}
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'validator') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			$self->confess_at_current_offset('expected qr/[a-zA-Z_][a-zA-Z0-9_]*+/, qr/\\{\\{.*?\\}\\}/s')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A$var_identifier_regex\Z/ and $self->{tokens}[$self->{tokens_index} + 1][1] =~ /\A$var_native_code_block_regex\Z/;
			@tokens = (@tokens, $self->step_tokens(2));
			push @{$context_object->{validators}}, { type => 'validator', line_number => $tokens[0][2], identifier => $tokens[1][1], code => $self->context_format_native_code($tokens[2][1]), };
			}
			else {
			return $context_object;
			}
	}
	return $context_object;
}

sub context_arguments_list {
	my ($self, $context_list) = @_;

	while ($self->more_tokens) {
		my @tokens;

			if ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A$var_identifier_regex\Z/) {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			push @$context_list, $tokens[0][1];
			while ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq ',') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			$self->confess_at_current_offset('expected qr/[a-zA-Z_][a-zA-Z0-9_]*+/')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A$var_identifier_regex\Z/;
			@tokens = (@tokens, $self->step_tokens(1));
			push @$context_list, $tokens[2][1];
			}
			}
			$self->confess_at_current_offset('expected \']\'')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq ']';
			@tokens = (@tokens, $self->step_tokens(1));
			return $context_list;
	}
	return $context_list;
}

sub context_path_action_block {
	my ($self, $context_object) = @_;

	while ($self->more_tokens) {
		my @tokens;

			$self->confess_at_current_offset('expected \'{\'')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '{';
			@tokens = (@tokens, $self->step_tokens(1));
			$context_object = $self->context_path_action_block_list($context_object);
			$self->confess_at_current_offset('expected \'}\'')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '}';
			@tokens = (@tokens, $self->step_tokens(1));
			return $context_object;
	}
	return $context_object;
}

sub context_path_action_block_list {
	my ($self, $context_object) = @_;

	while ($self->more_tokens) {
		my @tokens;

			if ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'render') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			$self->confess_at_current_offset('expected qr/[a-zA-Z_][a-zA-Z0-9_]*+/')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A$var_identifier_regex\Z/;
			@tokens = (@tokens, $self->step_tokens(1));
			push @{$context_object->{block}}, { type => 'render_template', line_number => $tokens[0][2], identifier => $tokens[1][1], arguments => $self->context_action_arguments({}), };
			$self->confess_at_current_offset('expected \';\'')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq ';';
			@tokens = (@tokens, $self->step_tokens(1));
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'validate') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			$self->confess_at_current_offset('expected qr/[a-zA-Z_][a-zA-Z0-9_]*+/, \'as\', qr/[a-zA-Z_][a-zA-Z0-9_]*+/')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A$var_identifier_regex\Z/ and $self->{tokens}[$self->{tokens_index} + 1][1] eq 'as' and $self->{tokens}[$self->{tokens_index} + 2][1] =~ /\A$var_identifier_regex\Z/;
			@tokens = (@tokens, $self->step_tokens(3));
			push @{$context_object->{block}}, { type => 'validate_variable', line_number => $tokens[0][2], identifier => $tokens[1][1], validator_identifier => $tokens[3][1], };
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

sub context_action_arguments {
	my ($self, $context_object) = @_;

	while ($self->more_tokens) {
		my @tokens;

			if ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A$var_identifier_regex\Z/) {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			$self->confess_at_current_offset('expected \'=\'')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '=';
			@tokens = (@tokens, $self->step_tokens(1));
			$context_object->{$tokens[0][1]} = $self->context_action_expression;
			while ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq ',') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			$self->confess_at_current_offset('expected qr/[a-zA-Z_][a-zA-Z0-9_]*+/, \'=\'')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A$var_identifier_regex\Z/ and $self->{tokens}[$self->{tokens_index} + 1][1] eq '=';
			@tokens = (@tokens, $self->step_tokens(2));
			$context_object->{$tokens[3][1]} = $self->context_action_expression;
			}
			}
			return $context_object;
	}
	return $context_object;
}

sub context_action_expression {
	my ($self, $context_object) = @_;

	while ($self->more_tokens) {
		my @tokens;

			if ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A$var_identifier_regex\Z/) {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			$context_object = { type => 'variable_expression', line_number => $tokens[0][2], identifier => $tokens[0][1], };
			return $context_object;
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A$var_string_regex\Z/) {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			$context_object = { type => 'string_expression', line_number => $tokens[0][2], string => $self->context_format_string($tokens[0][1]), };
			return $context_object;
			}
			else {
			$self->confess_at_current_offset('expression expected');
			}
	}
	return $context_object;
}

sub context_format_string {
	my ($self, $context_value) = @_;

	while ($self->more_tokens) {
		my @tokens;

			$context_value = $var_escape_string_substitution->($var_format_string_substitution->($context_value));
			return $context_value;
	}
	return $context_value;
}

sub context_format_native_code {
	my ($self, $context_value) = @_;

	while ($self->more_tokens) {
		my @tokens;

			$context_value = $var_format_native_code_substitution->($context_value);
			return $context_value;
	}
	return $context_value;
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


