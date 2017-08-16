#!/usr/bin/env perl
package PaleWhite::MVC::Parser;
use parent 'Sugar::Lang::BaseSyntaxParser';
use strict;
use warnings;

use feature 'say';





##############################
##### variables and settings
##############################

our $var_native_code_block_regex = qr/\{\{.*?\}\}/s;
our $var_symbol_regex = qr/\{|\}|\[|\]|\(|\)|;|:|=|,|\.|\?|!/;
our $var_model_identifier_regex = qr/model::[a-zA-Z_][a-zA-Z0-9_]*+(?:::[a-zA-Z_][a-zA-Z0-9_]*+)*/;
our $var_file_identifier_regex = qr/file::[a-zA-Z_][a-zA-Z0-9_]*+(?:::[a-zA-Z_][a-zA-Z0-9_]*+)*/;
our $var_keyword_regex = qr/\b(model|int|string|getter|setter|cast|to|from|static|function)\b/;
our $var_event_identifier_regex = qr/create|delete/;
our $var_identifier_regex = qr/[a-zA-Z_][a-zA-Z0-9_]*+/;
our $var_integer_regex = qr/-?\d++/;
our $var_string_regex = qr/"([^\\"]|\\[\\"])*?"/s;
our $var_comment_regex = qr/#[^\n]*+\n/s;
our $var_whitespace_regex = qr/\s++/s;
our $var_format_native_code_substitution = sub { $_[0] =~ s/\A\{\{\s*\n(.*?)\s*\}\}\Z/$1/sr };
our $var_format_model_identifier_substitution = sub { $_[0] =~ s/\Amodel:://sr };
our $var_format_file_identifier_substitution = sub { $_[0] =~ s/\Afile:://sr };
our $var_escape_string_substitution = sub { $_[0] =~ s/\\([\\"])/$1/gsr };
our $var_format_string_substitution = sub { $_[0] =~ s/\A"(.*)"\Z/$1/sr };
our $var_format_event_identifier_substitution = sub { $_[0] =~ s/\A/on_/sr };


our $tokens = [
	'native_code_block' => $var_native_code_block_regex,
	'symbol' => $var_symbol_regex,
	'model_identifier' => $var_model_identifier_regex,
	'file_identifier' => $var_file_identifier_regex,
	'keyword' => $var_keyword_regex,
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
	action_expression_list => 'context_action_expression_list',
	arguments_list => 'context_arguments_list',
	arguments_list_item => 'context_arguments_list_item',
	branch_action_expression => 'context_branch_action_expression',
	controller_block => 'context_controller_block',
	file_directory_block => 'context_file_directory_block',
	format_native_code => 'context_format_native_code',
	format_string => 'context_format_string',
	model_block => 'context_model_block',
	model_property_identifier => 'context_model_property_identifier',
	model_property_identifier_modifiers => 'context_model_property_identifier_modifiers',
	model_property_type_modifiers => 'context_model_property_type_modifiers',
	more_action_expression => 'context_more_action_expression',
	native_code_block => 'context_native_code_block',
	optional_arguments_list => 'context_optional_arguments_list',
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

			if ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'model') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			$self->confess_at_current_offset('expected qr/[a-zA-Z_][a-zA-Z0-9_]*+/, \'{\'')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A($var_identifier_regex)\Z/ and $self->{tokens}[$self->{tokens_index} + 1][1] eq '{';
			@tokens = (@tokens, $self->step_tokens(2));
			push @$context_list, $self->context_model_block({ type => 'model_definition', identifier => $tokens[1][1], });
			$self->confess_at_current_offset('expected \'}\'')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '}';
			@tokens = (@tokens, $self->step_tokens(1));
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'controller') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			$self->confess_at_current_offset('expected qr/[a-zA-Z_][a-zA-Z0-9_]*+/, \'{\'')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A($var_identifier_regex)\Z/ and $self->{tokens}[$self->{tokens_index} + 1][1] eq '{';
			@tokens = (@tokens, $self->step_tokens(2));
			push @$context_list, $self->context_controller_block({ type => 'controller_definition', line_number => $tokens[0][2], identifier => $tokens[1][1], });
			$self->confess_at_current_offset('expected \'}\'')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '}';
			@tokens = (@tokens, $self->step_tokens(1));
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'file_directory') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			$self->confess_at_current_offset('expected qr/[a-zA-Z_][a-zA-Z0-9_]*+/, qr/"([^\\\\"]|\\\\[\\\\"])*?"/s, \'{\'')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A($var_identifier_regex)\Z/ and $self->{tokens}[$self->{tokens_index} + 1][1] =~ /\A($var_string_regex)\Z/ and $self->{tokens}[$self->{tokens_index} + 2][1] eq '{';
			@tokens = (@tokens, $self->step_tokens(3));
			push @$context_list, $self->context_file_directory_block({ type => 'file_directory_definition', line_number => $tokens[0][2], identifier => $tokens[1][1], directory => $self->context_format_string($tokens[2][1]), });
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
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A($var_identifier_regex)\Z/ and $self->{tokens}[$self->{tokens_index} + 1][1] eq '(';
			@tokens = (@tokens, $self->step_tokens(2));
			$self->confess_at_current_offset('expected \')\', qr/\\{\\{.*?\\}\\}/s')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq ')' and $self->{tokens}[$self->{tokens_index} + 1][1] =~ /\A($var_native_code_block_regex)\Z/;
			@tokens = (@tokens, $self->step_tokens(2));
			push @{$context_object->{functions}}, { type => 'model_function', identifier => $tokens[1][1], code => $var_format_native_code_substitution->($tokens[4][1]), };
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'static' and $self->{tokens}[$self->{tokens_index} + 1][1] eq 'function') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(2));
			$self->confess_at_current_offset('expected qr/[a-zA-Z_][a-zA-Z0-9_]*+/, \'(\'')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A($var_identifier_regex)\Z/ and $self->{tokens}[$self->{tokens_index} + 1][1] eq '(';
			@tokens = (@tokens, $self->step_tokens(2));
			$self->confess_at_current_offset('expected \')\', qr/\\{\\{.*?\\}\\}/s')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq ')' and $self->{tokens}[$self->{tokens_index} + 1][1] =~ /\A($var_native_code_block_regex)\Z/;
			@tokens = (@tokens, $self->step_tokens(2));
			push @{$context_object->{functions}}, { type => 'model_static_function', identifier => $tokens[2][1], code => $var_format_native_code_substitution->($tokens[5][1]), };
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'on' and $self->{tokens}[$self->{tokens_index} + 1][1] =~ /\A($var_event_identifier_regex)\Z/) {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(2));
			$self->confess_at_current_offset('expected qr/\\{\\{.*?\\}\\}/s')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A($var_native_code_block_regex)\Z/;
			@tokens = (@tokens, $self->step_tokens(1));
			push @{$context_object->{functions}}, { type => 'on_event_function', identifier => $var_format_event_identifier_substitution->($tokens[1][1]), code => $var_format_native_code_substitution->($tokens[2][1]), };
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A($var_model_identifier_regex)\Z/) {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			push @{$context_object->{properties}}, $self->context_model_property_identifier({ type => 'model_pointer_property', property_type => $var_format_model_identifier_substitution->($tokens[0][1]), modifiers => { default => '0', }, modifiers => $self->context_model_property_type_modifiers({}), });
			$self->confess_at_current_offset('expected \';\'')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq ';';
			@tokens = (@tokens, $self->step_tokens(1));
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A($var_file_identifier_regex)\Z/) {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			push @{$context_object->{properties}}, $self->context_model_property_identifier({ type => 'file_pointer_property', property_type => $var_format_file_identifier_substitution->($tokens[0][1]), modifiers => { default => '""', }, modifiers => $self->context_model_property_type_modifiers({}), });
			$self->confess_at_current_offset('expected \';\'')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq ';';
			@tokens = (@tokens, $self->step_tokens(1));
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A($var_identifier_regex)\Z/) {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			push @{$context_object->{properties}}, $self->context_model_property_identifier({ type => 'model_property', property_type => $tokens[0][1], modifiers => $self->context_model_property_type_modifiers({}), });
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

sub context_model_property_type_modifiers {
	my ($self, $context_object) = @_;

	while ($self->more_tokens) {
	my @tokens;

			if ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '[' and $self->{tokens}[$self->{tokens_index} + 1][1] =~ /\A($var_integer_regex)\Z/ and $self->{tokens}[$self->{tokens_index} + 2][1] eq ']') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(3));
			$context_object->{property_size} = $tokens[1][1];
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '[' and $self->{tokens}[$self->{tokens_index} + 1][1] eq ']') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(2));
			$context_object->{array_property} = 'enabled';
			}
			else {
			return $context_object;
			}
	}
	return $context_object;
}

sub context_model_property_identifier {
	my ($self, $context_object) = @_;
	my @tokens;

			$self->confess_at_current_offset('expected qr/[a-zA-Z_][a-zA-Z0-9_]*+/')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A($var_identifier_regex)\Z/;
			@tokens = (@tokens, $self->step_tokens(1));
			$context_object->{identifier} = $tokens[0][1];
			$context_object->{modifiers} = $self->context_model_property_identifier_modifiers($context_object->{modifiers});
			return $context_object;
}

sub context_model_property_identifier_modifiers {
	my ($self, $context_object) = @_;

	while ($self->more_tokens) {
	my @tokens;

			if ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'unique_key') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			$context_object->{$tokens[0][1]} = 'enabled';
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'unique') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			$context_object->{$tokens[0][1]} = 'enabled';
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'auto_increment') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			$context_object->{$tokens[0][1]} = 'enabled';
			}
			else {
			return $context_object;
			}
	}
	return $context_object;
}

sub context_controller_block {
	my ($self, $context_object) = @_;

	while ($self->more_tokens) {
	my @tokens;

			if ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'path' and $self->{tokens}[$self->{tokens_index} + 1][1] eq 'global') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(2));
			push @{$context_object->{global_paths}}, $self->context_path_action_block({ type => 'global_path', line_number => $tokens[0][2], arguments => $self->context_optional_arguments_list([]), block => [], });
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'path' and $self->{tokens}[$self->{tokens_index} + 1][1] eq 'default') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(2));
			$context_object->{default_path} = $self->context_path_action_block({ type => 'default_path', line_number => $tokens[0][2], arguments => [], block => [], });
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'path' and $self->{tokens}[$self->{tokens_index} + 1][1] eq 'error') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(2));
			$context_object->{error_path} = $self->context_path_action_block({ type => 'error_path', line_number => $tokens[0][2], arguments => [], block => [], });
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'path' and $self->{tokens}[$self->{tokens_index} + 1][1] =~ /\A($var_string_regex)\Z/) {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(2));
			push @{$context_object->{paths}}, $self->context_path_action_block({ type => 'match_path', line_number => $tokens[0][2], path => $self->context_format_string($tokens[1][1]), arguments => $self->context_optional_arguments_list([]), block => [], });
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'ajax' and $self->{tokens}[$self->{tokens_index} + 1][1] eq 'global') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(2));
			push @{$context_object->{global_ajax_paths}}, $self->context_path_action_block({ type => 'global_path', line_number => $tokens[0][2], arguments => $self->context_optional_arguments_list([]), block => [], });
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'ajax' and $self->{tokens}[$self->{tokens_index} + 1][1] eq 'default') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(2));
			$context_object->{default_ajax_path} = $self->context_path_action_block({ type => 'default_path', line_number => $tokens[0][2], arguments => [], block => [], });
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'ajax' and $self->{tokens}[$self->{tokens_index} + 1][1] eq 'error') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(2));
			$context_object->{error_ajax_path} = $self->context_path_action_block({ type => 'error_path', line_number => $tokens[0][2], arguments => [], block => [], });
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'ajax' and $self->{tokens}[$self->{tokens_index} + 1][1] =~ /\A($var_string_regex)\Z/) {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(2));
			push @{$context_object->{ajax_paths}}, $self->context_path_action_block({ type => 'match_path', line_number => $tokens[0][2], path => $self->context_format_string($tokens[1][1]), arguments => $self->context_optional_arguments_list([]), block => [], });
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'action') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			$self->confess_at_current_offset('expected qr/[a-zA-Z_][a-zA-Z0-9_]*+/')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A($var_identifier_regex)\Z/;
			@tokens = (@tokens, $self->step_tokens(1));
			push @{$context_object->{actions}}, { type => 'action', line_number => $tokens[0][2], identifier => $tokens[1][1], arguments => $self->context_optional_arguments_list([]), code => $self->context_native_code_block($tokens[2][1]), };
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'validator') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			$self->confess_at_current_offset('expected qr/[a-zA-Z_][a-zA-Z0-9_]*+/')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A($var_identifier_regex)\Z/;
			@tokens = (@tokens, $self->step_tokens(1));
			push @{$context_object->{validators}}, { type => 'validator', line_number => $tokens[0][2], identifier => $tokens[1][1], code => $self->context_native_code_block($tokens[2][1]), };
			}
			else {
			return $context_object;
			}
	}
	return $context_object;
}

sub context_native_code_block {
	my ($self, $context_value) = @_;
	my @tokens;

			$self->confess_at_current_offset('expected qr/\\{\\{.*?\\}\\}/s')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A($var_native_code_block_regex)\Z/;
			@tokens = (@tokens, $self->step_tokens(1));
			$context_value = $self->context_format_native_code($tokens[0][1]);
			return $context_value;
}

sub context_optional_arguments_list {
	my ($self, $context_list) = @_;
	my @tokens;

			if ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '[') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			$context_list = $self->context_arguments_list($context_list);
			}
			return $context_list;
}

sub context_arguments_list {
	my ($self, $context_list) = @_;

	while ($self->more_tokens) {
	my @tokens;

			if ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq ']') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			return $context_list;
			}
			else {
			$context_list = $self->context_arguments_list_item($context_list);
			while ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq ',') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			$context_list = $self->context_arguments_list_item($context_list);
			}
			$self->confess_at_current_offset('expected \']\'')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq ']';
			@tokens = (@tokens, $self->step_tokens(1));
			return $context_list;
			}
	}
	return $context_list;
}

sub context_arguments_list_item {
	my ($self, $context_list) = @_;
	my @tokens;

			if ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A($var_identifier_regex)\Z/) {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			if ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '[' and $self->{tokens}[$self->{tokens_index} + 1][1] =~ /\A($var_integer_regex)\Z/ and $self->{tokens}[$self->{tokens_index} + 2][1] eq ']' and $self->{tokens}[$self->{tokens_index} + 3][1] =~ /\A($var_identifier_regex)\Z/) {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(4));
			push @$context_list, { type => 'argument_specifier', line_number => $tokens[0][2], identifier => $tokens[4][1], };
			push @$context_list, { type => 'validate_variable', line_number => $tokens[0][2], validator_identifier => $tokens[0][1], validator_min_size => $tokens[2][1], validator_max_size => $tokens[2][1], identifier => $tokens[4][1], };
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '[' and $self->{tokens}[$self->{tokens_index} + 1][1] =~ /\A($var_integer_regex)\Z/ and $self->{tokens}[$self->{tokens_index} + 2][1] eq ':' and $self->{tokens}[$self->{tokens_index} + 3][1] eq ']' and $self->{tokens}[$self->{tokens_index} + 4][1] =~ /\A($var_identifier_regex)\Z/) {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(5));
			push @$context_list, { type => 'argument_specifier', line_number => $tokens[0][2], identifier => $tokens[5][1], };
			push @$context_list, { type => 'validate_variable', line_number => $tokens[0][2], validator_identifier => $tokens[0][1], validator_min_size => $tokens[2][1], identifier => $tokens[5][1], };
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '[' and $self->{tokens}[$self->{tokens_index} + 1][1] eq ':' and $self->{tokens}[$self->{tokens_index} + 2][1] =~ /\A($var_integer_regex)\Z/ and $self->{tokens}[$self->{tokens_index} + 3][1] eq ']' and $self->{tokens}[$self->{tokens_index} + 4][1] =~ /\A($var_identifier_regex)\Z/) {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(5));
			push @$context_list, { type => 'argument_specifier', line_number => $tokens[0][2], identifier => $tokens[5][1], };
			push @$context_list, { type => 'validate_variable', line_number => $tokens[0][2], validator_identifier => $tokens[0][1], validator_max_size => $tokens[3][1], identifier => $tokens[5][1], };
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '[' and $self->{tokens}[$self->{tokens_index} + 1][1] =~ /\A($var_integer_regex)\Z/ and $self->{tokens}[$self->{tokens_index} + 2][1] eq ':' and $self->{tokens}[$self->{tokens_index} + 3][1] =~ /\A($var_integer_regex)\Z/ and $self->{tokens}[$self->{tokens_index} + 4][1] eq ']' and $self->{tokens}[$self->{tokens_index} + 5][1] =~ /\A($var_identifier_regex)\Z/) {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(6));
			push @$context_list, { type => 'argument_specifier', line_number => $tokens[0][2], identifier => $tokens[6][1], };
			push @$context_list, { type => 'validate_variable', line_number => $tokens[0][2], validator_identifier => $tokens[0][1], validator_min_size => $tokens[2][1], validator_max_size => $tokens[4][1], identifier => $tokens[6][1], };
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A($var_identifier_regex)\Z/) {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			push @$context_list, { type => 'argument_specifier', line_number => $tokens[0][2], identifier => $tokens[1][1], };
			push @$context_list, { type => 'validate_variable', line_number => $tokens[0][2], validator_identifier => $tokens[0][1], identifier => $tokens[1][1], };
			}
			else {
			push @$context_list, { type => 'argument_specifier', line_number => $tokens[0][2], identifier => $tokens[0][1], };
			}
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A($var_model_identifier_regex)\Z/ and $self->{tokens}[$self->{tokens_index} + 1][1] =~ /\A($var_identifier_regex)\Z/) {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(2));
			push @$context_list, { type => 'argument_specifier', line_number => $tokens[0][2], identifier => $tokens[1][1], };
			push @$context_list, { type => 'validate_variable', line_number => $tokens[0][2], validator_identifier => $tokens[0][1], identifier => $tokens[1][1], };
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '!' and $self->{tokens}[$self->{tokens_index} + 1][1] =~ /\A($var_identifier_regex)\Z/) {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(2));
			push @$context_list, { type => 'argument_specifier', line_number => $tokens[0][2], identifier => $tokens[1][1], };
			push @$context_list, { type => 'validate_variable', line_number => $tokens[0][2], validator_identifier => $tokens[1][1], identifier => $tokens[1][1], };
			}
			else {
			$self->confess_at_current_offset('expected argument list');
			}
			return $context_list;
}

sub context_path_action_block {
	my ($self, $context_object) = @_;
	my @tokens;

			$self->confess_at_current_offset('expected \'{\'')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '{';
			@tokens = (@tokens, $self->step_tokens(1));
			$context_object = $self->context_path_action_block_list($context_object);
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
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A($var_identifier_regex)\Z/;
			@tokens = (@tokens, $self->step_tokens(1));
			push @{$context_object->{block}}, { type => 'render_template', line_number => $tokens[0][2], identifier => $tokens[1][1], arguments => $self->context_action_arguments({}), };
			$self->confess_at_current_offset('expected \';\'')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq ';';
			@tokens = (@tokens, $self->step_tokens(1));
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'render_file') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			push @{$context_object->{block}}, { type => 'render_file', line_number => $tokens[0][2], expression => $self->context_action_expression, };
			$self->confess_at_current_offset('expected \';\'')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq ';';
			@tokens = (@tokens, $self->step_tokens(1));
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'render_json') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			push @{$context_object->{block}}, { type => 'render_json', line_number => $tokens[0][2], arguments => $self->context_action_arguments({}), };
			$self->confess_at_current_offset('expected \';\'')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq ';';
			@tokens = (@tokens, $self->step_tokens(1));
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'status') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			push @{$context_object->{block}}, { type => 'assign_status', line_number => $tokens[0][2], expression => $self->context_action_expression, };
			$self->confess_at_current_offset('expected \';\'')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq ';';
			@tokens = (@tokens, $self->step_tokens(1));
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'redirect') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			push @{$context_object->{block}}, { type => 'assign_redirect', line_number => $tokens[0][2], expression => $self->context_action_expression, };
			$self->confess_at_current_offset('expected \';\'')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq ';';
			@tokens = (@tokens, $self->step_tokens(1));
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'header') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			$self->confess_at_current_offset('expected qr/"([^\\\\"]|\\\\[\\\\"])*?"/s, \'=\'')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A($var_string_regex)\Z/ and $self->{tokens}[$self->{tokens_index} + 1][1] eq '=';
			@tokens = (@tokens, $self->step_tokens(2));
			push @{$context_object->{block}}, { type => 'assign_header', line_number => $tokens[0][2], header_string => $self->context_format_string($tokens[1][1]), expression => $self->context_action_expression, };
			$self->confess_at_current_offset('expected \';\'')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq ';';
			@tokens = (@tokens, $self->step_tokens(1));
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'action') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			$self->confess_at_current_offset('expected qr/[a-zA-Z_][a-zA-Z0-9_]*+/')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A($var_identifier_regex)\Z/;
			@tokens = (@tokens, $self->step_tokens(1));
			push @{$context_object->{block}}, { type => 'controller_action', line_number => $tokens[0][2], identifier => $tokens[1][1], arguments => $self->context_action_arguments({}), };
			$self->confess_at_current_offset('expected \';\'')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq ';';
			@tokens = (@tokens, $self->step_tokens(1));
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'route') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			$self->confess_at_current_offset('expected qr/[a-zA-Z_][a-zA-Z0-9_]*+/')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A($var_identifier_regex)\Z/;
			@tokens = (@tokens, $self->step_tokens(1));
			push @{$context_object->{block}}, { type => 'route_controller', line_number => $tokens[0][2], identifier => $tokens[1][1], arguments => $self->context_action_arguments({}), };
			$self->confess_at_current_offset('expected \';\'')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq ';';
			@tokens = (@tokens, $self->step_tokens(1));
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'validate') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			$self->confess_at_current_offset('expected qr/[a-zA-Z_][a-zA-Z0-9_]*+/, \'as\'')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A($var_identifier_regex)\Z/ and $self->{tokens}[$self->{tokens_index} + 1][1] eq 'as';
			@tokens = (@tokens, $self->step_tokens(2));
			if ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A($var_model_identifier_regex)\Z/) {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			push @{$context_object->{block}}, { type => 'validate_variable', line_number => $tokens[0][2], identifier => $tokens[1][1], validator_identifier => $tokens[3][1], };
			}
			else {
			$self->confess_at_current_offset('expected qr/[a-zA-Z_][a-zA-Z0-9_]*+/')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A($var_identifier_regex)\Z/;
			@tokens = (@tokens, $self->step_tokens(1));
			if ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '[' and $self->{tokens}[$self->{tokens_index} + 1][1] =~ /\A($var_integer_regex)\Z/ and $self->{tokens}[$self->{tokens_index} + 2][1] eq ']') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(3));
			push @{$context_object->{block}}, { type => 'validate_variable', line_number => $tokens[0][2], identifier => $tokens[1][1], validator_identifier => $tokens[3][1], validator_min_size => $tokens[5][1], validator_max_size => $tokens[5][1], };
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '[' and $self->{tokens}[$self->{tokens_index} + 1][1] =~ /\A($var_integer_regex)\Z/ and $self->{tokens}[$self->{tokens_index} + 2][1] eq ':' and $self->{tokens}[$self->{tokens_index} + 3][1] eq ']') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(4));
			push @{$context_object->{block}}, { type => 'validate_variable', line_number => $tokens[0][2], identifier => $tokens[1][1], validator_identifier => $tokens[3][1], validator_min_size => $tokens[5][1], };
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '[' and $self->{tokens}[$self->{tokens_index} + 1][1] eq ':' and $self->{tokens}[$self->{tokens_index} + 2][1] =~ /\A($var_integer_regex)\Z/ and $self->{tokens}[$self->{tokens_index} + 3][1] eq ']') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(4));
			push @{$context_object->{block}}, { type => 'validate_variable', line_number => $tokens[0][2], identifier => $tokens[1][1], validator_identifier => $tokens[3][1], validator_max_size => $tokens[6][1], };
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '[' and $self->{tokens}[$self->{tokens_index} + 1][1] =~ /\A($var_integer_regex)\Z/ and $self->{tokens}[$self->{tokens_index} + 2][1] eq ':' and $self->{tokens}[$self->{tokens_index} + 3][1] =~ /\A($var_integer_regex)\Z/ and $self->{tokens}[$self->{tokens_index} + 4][1] eq ']') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(5));
			push @{$context_object->{block}}, { type => 'validate_variable', line_number => $tokens[0][2], identifier => $tokens[1][1], validator_identifier => $tokens[3][1], validator_min_size => $tokens[5][1], validator_max_size => $tokens[7][1], };
			}
			else {
			push @{$context_object->{block}}, { type => 'validate_variable', line_number => $tokens[0][2], identifier => $tokens[1][1], validator_identifier => $tokens[3][1], };
			}
			}
			$self->confess_at_current_offset('expected \';\'')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq ';';
			@tokens = (@tokens, $self->step_tokens(1));
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'if') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			push @{$context_object->{block}}, $self->context_path_action_block({ type => 'if_statement', line_number => $tokens[0][2], expression => $self->context_branch_action_expression, block => [], });
			if ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'else') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			push @{$context_object->{block}}, $self->context_path_action_block({ type => 'else_statement', line_number => $tokens[0][2], block => [], });
			}
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'session' and $self->{tokens}[$self->{tokens_index} + 1][1] eq '.' and $self->{tokens}[$self->{tokens_index} + 2][1] =~ /\A($var_identifier_regex)\Z/ and $self->{tokens}[$self->{tokens_index} + 3][1] eq '=') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(4));
			push @{$context_object->{block}}, { type => 'assign_session_variable', line_number => $tokens[0][2], identifier => $tokens[2][1], expression => $self->context_action_expression, };
			$self->confess_at_current_offset('expected \';\'')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq ';';
			@tokens = (@tokens, $self->step_tokens(1));
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A($var_identifier_regex)\Z/ and $self->{tokens}[$self->{tokens_index} + 1][1] eq '=') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(2));
			push @{$context_object->{block}}, { type => 'assign_variable', line_number => $tokens[0][2], identifier => $tokens[0][1], expression => $self->context_action_expression, };
			$self->confess_at_current_offset('expected \';\'')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq ';';
			@tokens = (@tokens, $self->step_tokens(1));
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '}') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			return $context_object;
			}
			else {
			push @{$context_object->{block}}, { type => 'expression_statement', expression => $self->context_action_expression, };
			$self->confess_at_current_offset('expected \';\'')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq ';';
			@tokens = (@tokens, $self->step_tokens(1));
			}
	}
	return $context_object;
}

sub context_action_arguments {
	my ($self, $context_object) = @_;

	while ($self->more_tokens) {
	my @tokens;

			if ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A($var_identifier_regex)\Z/ and $self->{tokens}[$self->{tokens_index} + 1][1] eq '=') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(2));
			$context_object->{$tokens[0][1]} = $self->context_action_expression;
			if ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq ',') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			}
			else {
			return $context_object;
			}
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A($var_string_regex)\Z/ and $self->{tokens}[$self->{tokens_index} + 1][1] eq '=') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(2));
			$context_object->{$self->context_format_string($tokens[0][1])} = $self->context_action_expression;
			if ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq ',') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			}
			else {
			return $context_object;
			}
			}
			else {
			return $context_object;
			}
	}
	return $context_object;
}

sub context_action_expression_list {
	my ($self, $context_list) = @_;
	my @tokens;

			push @$context_list, $self->context_action_expression;
			while ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq ',') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			push @$context_list, $self->context_action_expression;
			}
			return $context_list;
}

sub context_branch_action_expression {
	my ($self, $context_value) = @_;
	my @tokens;

			$self->confess_at_current_offset('expected \'(\'')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '(';
			@tokens = (@tokens, $self->step_tokens(1));
			$context_value = $self->context_action_expression;
			$self->confess_at_current_offset('expected \')\'')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq ')';
			@tokens = (@tokens, $self->step_tokens(1));
			return $context_value;
}

sub context_action_expression {
	my ($self, $context_object) = @_;

	while ($self->more_tokens) {
	my @tokens;

			if ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'model' and $self->{tokens}[$self->{tokens_index} + 1][1] eq '?' and $self->{tokens}[$self->{tokens_index} + 2][1] =~ /\A($var_identifier_regex)\Z/) {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(3));
			$context_object = { type => 'load_optional_model_expression', line_number => $tokens[0][2], identifier => $tokens[2][1], arguments => $self->context_action_arguments({}), };
			return $context_object;
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'model' and $self->{tokens}[$self->{tokens_index} + 1][1] =~ /\A($var_identifier_regex)\Z/) {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(2));
			$context_object = { type => 'load_model_expression', line_number => $tokens[0][2], identifier => $tokens[1][1], arguments => $self->context_action_arguments({}), };
			return $context_object;
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'file' and $self->{tokens}[$self->{tokens_index} + 1][1] =~ /\A($var_identifier_regex)\Z/) {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(2));
			$context_object = { type => 'load_file_expression', line_number => $tokens[0][2], identifier => $tokens[1][1], arguments => $self->context_action_arguments({}), };
			return $context_object;
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'list' and $self->{tokens}[$self->{tokens_index} + 1][1] =~ /\A($var_identifier_regex)\Z/) {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(2));
			$context_object = { type => 'load_model_list_expression', line_number => $tokens[0][2], identifier => $tokens[1][1], arguments => $self->context_action_arguments({}), };
			return $context_object;
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'create' and $self->{tokens}[$self->{tokens_index} + 1][1] eq '?' and $self->{tokens}[$self->{tokens_index} + 2][1] =~ /\A($var_identifier_regex)\Z/) {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(3));
			$context_object = { type => 'create_optional_model_expression', line_number => $tokens[0][2], identifier => $tokens[2][1], arguments => $self->context_action_arguments({}), };
			return $context_object;
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'create' and $self->{tokens}[$self->{tokens_index} + 1][1] =~ /\A($var_identifier_regex)\Z/) {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(2));
			$context_object = { type => 'create_model_expression', line_number => $tokens[0][2], identifier => $tokens[1][1], arguments => $self->context_action_arguments({}), };
			return $context_object;
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'render' and $self->{tokens}[$self->{tokens_index} + 1][1] =~ /\A($var_identifier_regex)\Z/) {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(2));
			$context_object = { type => 'render_template_expression', line_number => $tokens[0][2], identifier => $tokens[1][1], arguments => $self->context_action_arguments({}), };
			return $context_object;
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'render_file') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			$context_object = { type => 'render_file_expression', line_number => $tokens[0][2], expression => $self->context_action_expression, };
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'action' and $self->{tokens}[$self->{tokens_index} + 1][1] =~ /\A($var_identifier_regex)\Z/) {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(2));
			$context_object = { type => 'controller_action_expression', line_number => $tokens[0][2], identifier => $tokens[1][1], arguments => $self->context_action_arguments({}), };
			return $context_object;
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'session' and $self->{tokens}[$self->{tokens_index} + 1][1] eq '.' and $self->{tokens}[$self->{tokens_index} + 2][1] =~ /\A($var_identifier_regex)\Z/) {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(3));
			$context_object = { type => 'session_variable_expression', line_number => $tokens[0][2], identifier => $tokens[2][1], };
			return $context_object;
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A($var_identifier_regex)\Z/) {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			$context_object = $self->context_more_action_expression({ type => 'variable_expression', line_number => $tokens[0][2], identifier => $tokens[0][1], });
			return $context_object;
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A($var_string_regex)\Z/) {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			$context_object = { type => 'string_expression', line_number => $tokens[0][2], value => $self->context_format_string($tokens[0][1]), };
			return $context_object;
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A($var_integer_regex)\Z/) {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			$context_object = { type => 'integer_expression', line_number => $tokens[0][2], value => $tokens[0][1], };
			return $context_object;
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '[') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			$context_object = { type => 'object_expression', line_number => $tokens[0][2], value => $self->context_action_arguments({}), };
			$self->confess_at_current_offset('expected \']\'')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq ']';
			@tokens = (@tokens, $self->step_tokens(1));
			return $context_object;
			}
			else {
			$self->confess_at_current_offset('expression expected');
			}
	}
	return $context_object;
}

sub context_more_action_expression {
	my ($self, $context_object) = @_;

	while ($self->more_tokens) {
	my @tokens;

			if ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '.' and $self->{tokens}[$self->{tokens_index} + 1][1] =~ /\A($var_identifier_regex)\Z/ and $self->{tokens}[$self->{tokens_index} + 2][1] eq '(' and $self->{tokens}[$self->{tokens_index} + 3][1] eq ')') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(4));
			$context_object = { type => 'method_call_expression', line_number => $tokens[0][2], identifier => $tokens[1][1], expression => $context_object, arguments_list => [], };
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '.' and $self->{tokens}[$self->{tokens_index} + 1][1] =~ /\A($var_identifier_regex)\Z/ and $self->{tokens}[$self->{tokens_index} + 2][1] eq '(') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(3));
			$context_object = { type => 'method_call_expression', line_number => $tokens[0][2], identifier => $tokens[1][1], expression => $context_object, arguments_list => $self->context_action_expression_list([]), };
			$self->confess_at_current_offset('expected \')\'')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq ')';
			@tokens = (@tokens, $self->step_tokens(1));
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '.' and $self->{tokens}[$self->{tokens_index} + 1][1] =~ /\A($var_identifier_regex)\Z/) {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(2));
			$context_object = { type => 'access_expression', line_number => $tokens[0][2], identifier => $tokens[1][1], expression => $context_object, };
			}
			else {
			return $context_object;
			}
	}
	return $context_object;
}

sub context_file_directory_block {
	my ($self, $context_object) = @_;
	my @tokens;

			return $context_object;
}

sub context_format_string {
	my ($self, $context_value) = @_;
	my @tokens;

			$context_value = $var_escape_string_substitution->($var_format_string_substitution->($context_value));
			return $context_value;
}

sub context_format_native_code {
	my ($self, $context_value) = @_;
	my @tokens;

			$context_value = $var_format_native_code_substitution->($context_value);
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


