#!/usr/bin/env perl
package PaleWhite::MVC::Parser;
use parent 'Sugar::Lang::BaseSyntaxParser';
use strict;
use warnings;

use feature 'say';





##############################
##### variables and settings
##############################

our $var_symbol_regex = qr/\{|\}|\[|\]|\(|\)|;|:|=>|<|>|<=|>=|==|!=|=|,|\.|\?|!|\@|\//;
our $var_model_identifier_regex = qr/model::[a-zA-Z_][a-zA-Z0-9_]*+(?:::[a-zA-Z_][a-zA-Z0-9_]*+)*/;
our $var_controller_identifier_regex = qr/controller::[a-zA-Z_][a-zA-Z0-9_]*+(?:::[a-zA-Z_][a-zA-Z0-9_]*+)*/;
our $var_file_identifier_regex = qr/file::[a-zA-Z_][a-zA-Z0-9_]*+(?:::[a-zA-Z_][a-zA-Z0-9_]*+)*/;
our $var_native_identifier_regex = qr/native::[a-zA-Z_][a-zA-Z0-9_]*+(?:::[a-zA-Z_][a-zA-Z0-9_]*+)*/;
our $var_class_identifier_regex = qr/[a-zA-Z_][a-zA-Z0-9_]*+(?:::[a-zA-Z_][a-zA-Z0-9_]*+)*/;
our $var_identifier_regex = qr/[a-zA-Z_][a-zA-Z0-9_]*+/;
our $var_integer_regex = qr/-?\d++/;
our $var_string_regex = qr/"([^\\"]|\\[\\"])*?"/s;
our $var_string_interpolation_start_regex = qr/"([^\\"]|\\[\\"])*?\{\{/s;
our $var_string_interpolation_middle_regex = qr/\}\}([^\\"]|\\[\\"])*?\{\{/s;
our $var_string_interpolation_end_regex = qr/\}\}([^\\"]|\\[\\"])*?"/s;
our $var_comment_regex = qr/#[^\n]*+\n/s;
our $var_whitespace_regex = qr/\s++/s;
our $var_event_identifier_regex = qr/create|delete/;
our $var_format_model_identifier_substitution = sub { $_[0] =~ s/\Amodel:://sr };
our $var_format_controller_identifier_substitution = sub { $_[0] =~ s/\Acontroller:://sr };
our $var_format_file_identifier_substitution = sub { $_[0] =~ s/\Afile:://sr };
our $var_format_native_identifier_substitution = sub { $_[0] =~ s/\Anative:://sr };
our $var_escape_string_substitution = sub { $_[0] =~ s/\\([\\"])/$1/gsr };
our $var_format_string_substitution = sub { $_[0] =~ s/\A"(.*)"\Z/$1/sr };
our $var_format_string_interpolation_start_substitution = sub { $_[0] =~ s/\A"(.*)\{\{\Z/$1/sr };
our $var_format_string_interpolation_middle_substitution = sub { $_[0] =~ s/\A\}\}(.*)\{\{\Z/$1/sr };
our $var_format_string_interpolation_end_substitution = sub { $_[0] =~ s/\A\}\}(.*)"\Z/$1/sr };
our $var_format_event_identifier_substitution = sub { $_[0] =~ s/\A/on_/sr };


our $tokens = [
	'model_identifier' => $var_model_identifier_regex,
	'controller_identifier' => $var_controller_identifier_regex,
	'file_identifier' => $var_file_identifier_regex,
	'native_identifier' => $var_native_identifier_regex,
	'class_identifier' => $var_class_identifier_regex,
	'identifier' => $var_identifier_regex,
	'integer' => $var_integer_regex,
	'string_interpolation_start' => $var_string_interpolation_start_regex,
	'string_interpolation_middle' => $var_string_interpolation_middle_regex,
	'string_interpolation_end' => $var_string_interpolation_end_regex,
	'string' => $var_string_regex,
	'symbol' => $var_symbol_regex,
	'comment' => $var_comment_regex,
	'whitespace' => $var_whitespace_regex,
];

our $ignored_tokens = [
	'whitespace',
	'comment',
];

our $contexts = {
	action_arguments => 'context_action_arguments',
	action_array_expression_list => 'context_action_array_expression_list',
	action_expression => 'context_action_expression',
	action_expression_list => 'context_action_expression_list',
	arguments_list_item => 'context_arguments_list_item',
	bracket_arguments_list => 'context_bracket_arguments_list',
	branch_action_expression => 'context_branch_action_expression',
	controller_block => 'context_controller_block',
	file_directory_block => 'context_file_directory_block',
	format_string => 'context_format_string',
	format_string_interpolation_end => 'context_format_string_interpolation_end',
	format_string_interpolation_middle => 'context_format_string_interpolation_middle',
	format_string_interpolation_start => 'context_format_string_interpolation_start',
	interpolated_string_path => 'context_interpolated_string_path',
	interpolated_string_path_expression => 'context_interpolated_string_path_expression',
	model_block => 'context_model_block',
	model_property_identifier => 'context_model_property_identifier',
	model_property_identifier_modifiers => 'context_model_property_identifier_modifiers',
	model_property_type_modifiers => 'context_model_property_type_modifiers',
	more_action_expression => 'context_more_action_expression',
	object_constructor_dynamic_expression => 'context_object_constructor_dynamic_expression',
	object_constructor_expression => 'context_object_constructor_expression',
	optional_arguments_list => 'context_optional_arguments_list',
	parentheses_arguments_list => 'context_parentheses_arguments_list',
	path_action_block => 'context_path_action_block',
	path_action_block_list => 'context_path_action_block_list',
	plugin_block => 'context_plugin_block',
	root => 'context_root',
	string_interpolation_expression_list => 'context_string_interpolation_expression_list',
	view_controller_block => 'context_view_controller_block',
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
			push @$context_list, $self->context_model_block({ type => 'model_definition', identifier => $tokens[1][1], functions => [], properties => [], virtual_properties => [], });
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
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'view_controller') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			$self->confess_at_current_offset('expected qr/[a-zA-Z_][a-zA-Z0-9_]*+/, \'{\'')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A($var_identifier_regex)\Z/ and $self->{tokens}[$self->{tokens_index} + 1][1] eq '{';
			@tokens = (@tokens, $self->step_tokens(2));
			push @$context_list, $self->context_view_controller_block({ type => 'view_controller_definition', line_number => $tokens[0][2], identifier => $tokens[1][1], });
			$self->confess_at_current_offset('expected \'}\'')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '}';
			@tokens = (@tokens, $self->step_tokens(1));
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'plugin') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			$self->confess_at_current_offset('expected qr/[a-zA-Z_][a-zA-Z0-9_]*+/, \'{\'')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A($var_identifier_regex)\Z/ and $self->{tokens}[$self->{tokens_index} + 1][1] eq '{';
			@tokens = (@tokens, $self->step_tokens(2));
			push @$context_list, $self->context_plugin_block({ type => 'plugin_definition', line_number => $tokens[0][2], identifier => $tokens[1][1], });
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
			push @$context_list, $self->context_file_directory_block({ type => 'file_directory_definition', line_number => $tokens[0][2], identifier => $tokens[1][1], directory => $self->context_format_string($tokens[2][1]), properties => {}, });
			$self->confess_at_current_offset('expected \'}\'')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '}';
			@tokens = (@tokens, $self->step_tokens(1));
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'native_library') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			$self->confess_at_current_offset('expected qr/[a-zA-Z_][a-zA-Z0-9_]*+(?:::[a-zA-Z_][a-zA-Z0-9_]*+)*/, \'=>\', qr/"([^\\\\"]|\\\\[\\\\"])*?"/s, \';\'')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A($var_class_identifier_regex)\Z/ and $self->{tokens}[$self->{tokens_index} + 1][1] eq '=>' and $self->{tokens}[$self->{tokens_index} + 2][1] =~ /\A($var_string_regex)\Z/ and $self->{tokens}[$self->{tokens_index} + 3][1] eq ';';
			@tokens = (@tokens, $self->step_tokens(4));
			push @$context_list, { type => 'native_library_declaration', line_number => $tokens[0][2], identifier => $tokens[1][1], include_file => $self->context_format_string($tokens[3][1]), };
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

			if ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'get' and $self->{tokens}[$self->{tokens_index} + 1][1] eq ':') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(2));
			$self->confess_at_current_offset('expected qr/[a-zA-Z_][a-zA-Z0-9_]*+/')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A($var_identifier_regex)\Z/;
			@tokens = (@tokens, $self->step_tokens(1));
			push @{$context_object->{virtual_properties}}, $self->context_path_action_block({ type => 'virtual_property', line_number => $tokens[0][2], identifier => $tokens[2][1], block => [], });
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'function') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			$self->confess_at_current_offset('expected qr/[a-zA-Z_][a-zA-Z0-9_]*+/')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A($var_identifier_regex)\Z/;
			@tokens = (@tokens, $self->step_tokens(1));
			push @{$context_object->{functions}}, $self->context_path_action_block({ type => 'model_function', line_number => $tokens[0][2], identifier => $tokens[1][1], arguments => $self->context_optional_arguments_list([]), block => [], });
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'static' and $self->{tokens}[$self->{tokens_index} + 1][1] eq 'function') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(2));
			$self->confess_at_current_offset('expected qr/[a-zA-Z_][a-zA-Z0-9_]*+/')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A($var_identifier_regex)\Z/;
			@tokens = (@tokens, $self->step_tokens(1));
			push @{$context_object->{functions}}, $self->context_path_action_block({ type => 'model_static_function', line_number => $tokens[0][2], identifier => $tokens[2][1], arguments => $self->context_optional_arguments_list([]), block => [], });
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'on' and $self->{tokens}[$self->{tokens_index} + 1][1] =~ /\A($var_event_identifier_regex)\Z/) {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(2));
			push @{$context_object->{functions}}, $self->context_path_action_block({ type => 'on_event_function', line_number => $tokens[0][2], identifier => $var_format_event_identifier_substitution->($tokens[1][1]), arguments => $self->context_optional_arguments_list([]), block => [], });
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A($var_model_identifier_regex)\Z/) {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			push @{$context_object->{properties}}, $self->context_model_property_identifier({ type => 'model_pointer_property', line_number => $tokens[0][2], property_type => $var_format_model_identifier_substitution->($tokens[0][1]), modifiers => { default => '0', }, modifiers => $self->context_model_property_type_modifiers({}), });
			$self->confess_at_current_offset('expected \';\'')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq ';';
			@tokens = (@tokens, $self->step_tokens(1));
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A($var_file_identifier_regex)\Z/) {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			push @{$context_object->{properties}}, $self->context_model_property_identifier({ type => 'file_pointer_property', line_number => $tokens[0][2], property_type => $var_format_file_identifier_substitution->($tokens[0][1]), modifiers => { default => '""', }, modifiers => $self->context_model_property_type_modifiers({}), });
			$self->confess_at_current_offset('expected \';\'')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq ';';
			@tokens = (@tokens, $self->step_tokens(1));
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A($var_identifier_regex)\Z/) {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			push @{$context_object->{properties}}, $self->context_model_property_identifier({ type => 'model_property', line_number => $tokens[0][2], property_type => $tokens[0][1], modifiers => $self->context_model_property_type_modifiers({}), });
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
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '{' and $self->{tokens}[$self->{tokens_index} + 1][1] eq 'int' and $self->{tokens}[$self->{tokens_index} + 2][1] eq '}') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(3));
			$context_object->{map_property} = { type => 'model_key_property', line_number => $tokens[0][2], property_type => 'int', identifier => 'map_key', modifiers => {}, };
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '{' and $self->{tokens}[$self->{tokens_index} + 1][1] eq 'string' and $self->{tokens}[$self->{tokens_index} + 2][1] eq '[' and $self->{tokens}[$self->{tokens_index} + 3][1] =~ /\A($var_integer_regex)\Z/ and $self->{tokens}[$self->{tokens_index} + 4][1] eq ']' and $self->{tokens}[$self->{tokens_index} + 5][1] eq '}') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(6));
			$context_object->{map_property} = { type => 'model_key_property', line_number => $tokens[0][2], property_type => 'string', identifier => 'map_key', modifiers => { property_size => $tokens[3][1], }, };
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
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'owned') {
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
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'path') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			push @{$context_object->{paths}}, $self->context_path_action_block({ type => 'match_path', line_number => $tokens[0][2], path => $self->context_interpolated_string_path([]), arguments => $self->context_optional_arguments_list([]), block => [], });
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
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'ajax') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			push @{$context_object->{ajax_paths}}, $self->context_path_action_block({ type => 'match_path', line_number => $tokens[0][2], path => $self->context_interpolated_string_path([]), arguments => $self->context_optional_arguments_list([]), block => [], });
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'api' and $self->{tokens}[$self->{tokens_index} + 1][1] eq 'global') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(2));
			push @{$context_object->{global_api_paths}}, $self->context_path_action_block({ type => 'global_path', line_number => $tokens[0][2], arguments => $self->context_optional_arguments_list([]), block => [], });
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'api' and $self->{tokens}[$self->{tokens_index} + 1][1] eq 'default') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(2));
			$context_object->{default_api_path} = $self->context_path_action_block({ type => 'default_path', line_number => $tokens[0][2], arguments => [], block => [], });
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'api' and $self->{tokens}[$self->{tokens_index} + 1][1] eq 'error') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(2));
			$context_object->{error_api_path} = $self->context_path_action_block({ type => 'error_path', line_number => $tokens[0][2], arguments => [], block => [], });
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'api' and $self->{tokens}[$self->{tokens_index} + 1][1] =~ /\A($var_string_regex)\Z/) {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(2));
			push @{$context_object->{api_paths}}, $self->context_path_action_block({ type => 'match_path', line_number => $tokens[0][2], path => $self->context_format_string($tokens[1][1]), arguments => $self->context_optional_arguments_list([]), block => [], });
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'api') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			push @{$context_object->{api_paths}}, $self->context_path_action_block({ type => 'match_path', line_number => $tokens[0][2], path => $self->context_interpolated_string_path([]), arguments => $self->context_optional_arguments_list([]), block => [], });
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'event') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			$self->confess_at_current_offset('expected qr/[a-zA-Z_][a-zA-Z0-9_]*+/')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A($var_identifier_regex)\Z/;
			@tokens = (@tokens, $self->step_tokens(1));
			push @{$context_object->{controller_events}}, $self->context_path_action_block({ type => 'event_block', line_number => $tokens[0][2], identifier => $tokens[1][1], arguments => $self->context_optional_arguments_list([]), block => [], });
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'action') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			$self->confess_at_current_offset('expected qr/[a-zA-Z_][a-zA-Z0-9_]*+/')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A($var_identifier_regex)\Z/;
			@tokens = (@tokens, $self->step_tokens(1));
			push @{$context_object->{actions}}, $self->context_path_action_block({ type => 'action_block', line_number => $tokens[0][2], identifier => $tokens[1][1], arguments => $self->context_optional_arguments_list([]), block => [], });
			}
			else {
			return $context_object;
			}
	}
	return $context_object;
}

sub context_view_controller_block {
	my ($self, $context_object) = @_;

	while ($self->more_tokens) {
	my @tokens;

			if ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'args') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			$context_object->{args_block} = $self->context_path_action_block({ type => 'args_block', line_number => $tokens[0][2], arguments => $self->context_optional_arguments_list([]), block => [], });
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'action') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			$self->confess_at_current_offset('expected qr/[a-zA-Z_][a-zA-Z0-9_]*+/')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A($var_identifier_regex)\Z/;
			@tokens = (@tokens, $self->step_tokens(1));
			push @{$context_object->{actions}}, $self->context_path_action_block({ type => 'action_block', line_number => $tokens[0][2], identifier => $tokens[1][1], arguments => $self->context_optional_arguments_list([]), block => [], });
			}
			else {
			return $context_object;
			}
	}
	return $context_object;
}

sub context_plugin_block {
	my ($self, $context_object) = @_;

	while ($self->more_tokens) {
	my @tokens;

			if ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'hook' and $self->{tokens}[$self->{tokens_index} + 1][1] eq 'event') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(2));
			$self->confess_at_current_offset('expected qr/[a-zA-Z_][a-zA-Z0-9_]*+(?:::[a-zA-Z_][a-zA-Z0-9_]*+)*/, \':\', qr/[a-zA-Z_][a-zA-Z0-9_]*+/')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A($var_class_identifier_regex)\Z/ and $self->{tokens}[$self->{tokens_index} + 1][1] eq ':' and $self->{tokens}[$self->{tokens_index} + 2][1] =~ /\A($var_identifier_regex)\Z/;
			@tokens = (@tokens, $self->step_tokens(3));
			push @{$context_object->{event_hooks}}, $self->context_path_action_block({ type => 'event_hook', line_number => $tokens[0][2], controller_class => $tokens[2][1], identifier => $tokens[4][1], arguments => $self->context_optional_arguments_list([]), block => [], });
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'hook' and $self->{tokens}[$self->{tokens_index} + 1][1] eq 'action') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(2));
			$self->confess_at_current_offset('expected qr/[a-zA-Z_][a-zA-Z0-9_]*+(?:::[a-zA-Z_][a-zA-Z0-9_]*+)*/, \':\', qr/[a-zA-Z_][a-zA-Z0-9_]*+/')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A($var_class_identifier_regex)\Z/ and $self->{tokens}[$self->{tokens_index} + 1][1] eq ':' and $self->{tokens}[$self->{tokens_index} + 2][1] =~ /\A($var_identifier_regex)\Z/;
			@tokens = (@tokens, $self->step_tokens(3));
			push @{$context_object->{action_hooks}}, $self->context_path_action_block({ type => 'action_hook', line_number => $tokens[0][2], controller_class => $tokens[2][1], identifier => $tokens[4][1], arguments => $self->context_optional_arguments_list([]), block => [], });
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'hook' and $self->{tokens}[$self->{tokens_index} + 1][1] eq 'controller' and $self->{tokens}[$self->{tokens_index} + 2][1] eq 'route') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(3));
			$self->confess_at_current_offset('expected qr/[a-zA-Z_][a-zA-Z0-9_]*+(?:::[a-zA-Z_][a-zA-Z0-9_]*+)*/')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A($var_class_identifier_regex)\Z/;
			@tokens = (@tokens, $self->step_tokens(1));
			push @{$context_object->{controller_route_hooks}}, $self->context_path_action_block({ type => 'controller_route_hook', line_number => $tokens[0][2], controller_class => $tokens[3][1], block => [], });
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'hook' and $self->{tokens}[$self->{tokens_index} + 1][1] eq 'controller' and $self->{tokens}[$self->{tokens_index} + 2][1] eq 'ajax') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(3));
			$self->confess_at_current_offset('expected qr/[a-zA-Z_][a-zA-Z0-9_]*+(?:::[a-zA-Z_][a-zA-Z0-9_]*+)*/')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A($var_class_identifier_regex)\Z/;
			@tokens = (@tokens, $self->step_tokens(1));
			push @{$context_object->{controller_ajax_hooks}}, $self->context_path_action_block({ type => 'controller_ajax_hook', line_number => $tokens[0][2], controller_class => $tokens[3][1], block => [], });
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'hook' and $self->{tokens}[$self->{tokens_index} + 1][1] eq 'controller' and $self->{tokens}[$self->{tokens_index} + 2][1] eq 'api') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(3));
			$self->confess_at_current_offset('expected qr/[a-zA-Z_][a-zA-Z0-9_]*+(?:::[a-zA-Z_][a-zA-Z0-9_]*+)*/')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A($var_class_identifier_regex)\Z/;
			@tokens = (@tokens, $self->step_tokens(1));
			push @{$context_object->{controller_api_hooks}}, $self->context_path_action_block({ type => 'controller_api_hook', line_number => $tokens[0][2], controller_class => $tokens[3][1], block => [], });
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'action') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			$self->confess_at_current_offset('expected qr/[a-zA-Z_][a-zA-Z0-9_]*+/')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A($var_identifier_regex)\Z/;
			@tokens = (@tokens, $self->step_tokens(1));
			push @{$context_object->{actions}}, $self->context_path_action_block({ type => 'action_block', line_number => $tokens[0][2], identifier => $tokens[1][1], arguments => $self->context_optional_arguments_list([]), block => [], });
			}
			else {
			return $context_object;
			}
	}
	return $context_object;
}

sub context_interpolated_string_path {
	my ($self, $context_list) = @_;
	my @tokens;

			$self->confess_at_current_offset('expected qr/"([^\\\\"]|\\\\[\\\\"])*?\\{\\{/s')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A($var_string_interpolation_start_regex)\Z/;
			@tokens = (@tokens, $self->step_tokens(1));
			push @$context_list, { type => 'string_token', value => $self->context_format_string_interpolation_start($tokens[0][1]), };
			push @$context_list, $self->context_interpolated_string_path_expression;
			while ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A($var_string_interpolation_middle_regex)\Z/) {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			push @$context_list, { type => 'string_token', value => $self->context_format_string_interpolation_middle($tokens[1][1]), };
			push @$context_list, $self->context_interpolated_string_path_expression;
			}
			$self->confess_at_current_offset('expected qr/\\}\\}([^\\\\"]|\\\\[\\\\"])*?"/s')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A($var_string_interpolation_end_regex)\Z/;
			@tokens = (@tokens, $self->step_tokens(1));
			push @$context_list, { type => 'string_token', value => $self->context_format_string_interpolation_end($tokens[1][1]), };
			return $context_list;
}

sub context_interpolated_string_path_expression {
	my ($self, $context_object) = @_;
	my @tokens;

			if ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A($var_identifier_regex)\Z/ and $self->{tokens}[$self->{tokens_index} + 1][1] eq '=' and $self->{tokens}[$self->{tokens_index} + 2][1] eq '[' and $self->{tokens}[$self->{tokens_index} + 3][1] eq ']') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(4));
			$context_object = { type => 'match_list_identifier', regex => '.+', seperator => '/', identifier => $tokens[0][1], };
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A($var_identifier_regex)\Z/ and $self->{tokens}[$self->{tokens_index} + 1][1] eq '=' and $self->{tokens}[$self->{tokens_index} + 2][1] eq '.' and $self->{tokens}[$self->{tokens_index} + 3][1] eq '.' and $self->{tokens}[$self->{tokens_index} + 4][1] eq '.') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(5));
			$context_object = { type => 'match_identifier', regex => '.*', identifier => $tokens[0][1], };
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A($var_identifier_regex)\Z/) {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			$context_object = { type => 'match_identifier', regex => '[^/]+', identifier => $tokens[0][1], };
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '.' and $self->{tokens}[$self->{tokens_index} + 1][1] eq '.' and $self->{tokens}[$self->{tokens_index} + 2][1] eq '.') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(3));
			$context_object = { type => 'match_any', regex => '.*', };
			}
			else {
			$self->confess_at_current_offset('expected path expression');
			}
			return $context_object;
}

sub context_optional_arguments_list {
	my ($self, $context_list) = @_;
	my @tokens;

			if ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '[') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			$context_list = $self->context_bracket_arguments_list($context_list);
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '(') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			$context_list = $self->context_parentheses_arguments_list($context_list);
			}
			return $context_list;
}

sub context_bracket_arguments_list {
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

sub context_parentheses_arguments_list {
	my ($self, $context_list) = @_;

	while ($self->more_tokens) {
	my @tokens;

			if ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq ')') {
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
			$self->confess_at_current_offset('expected \')\'')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq ')';
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
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '?' and $self->{tokens}[$self->{tokens_index} + 1][1] =~ /\A($var_identifier_regex)\Z/) {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(2));
			push @$context_list, { type => 'optional_argument_specifier', line_number => $tokens[0][2], identifier => $tokens[2][1], };
			push @$context_list, { type => 'optional_validate_variable', line_number => $tokens[0][2], validator_identifier => $tokens[0][1], identifier => $tokens[2][1], };
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

			if ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'log') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			push @{$context_object->{block}}, { type => 'log_message', line_number => $tokens[0][2], expression => $self->context_action_expression, };
			$self->confess_at_current_offset('expected \';\'')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq ';';
			@tokens = (@tokens, $self->step_tokens(1));
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'log_exception') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			push @{$context_object->{block}}, { type => 'log_exception', line_number => $tokens[0][2], expression => $self->context_action_expression, };
			$self->confess_at_current_offset('expected \';\'')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq ';';
			@tokens = (@tokens, $self->step_tokens(1));
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'render') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			$self->confess_at_current_offset('expected qr/[a-zA-Z_][a-zA-Z0-9_]*+(?:::[a-zA-Z_][a-zA-Z0-9_]*+)*/')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A($var_class_identifier_regex)\Z/;
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
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'set_localization') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			push @{$context_object->{block}}, { type => 'set_localization', line_number => $tokens[0][2], expression => $self->context_action_expression, };
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
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'schedule_event') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			$self->confess_at_current_offset('expected qr/[a-zA-Z_][a-zA-Z0-9_]*+/, \'.\', qr/[a-zA-Z_][a-zA-Z0-9_]*+/')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A($var_identifier_regex)\Z/ and $self->{tokens}[$self->{tokens_index} + 1][1] eq '.' and $self->{tokens}[$self->{tokens_index} + 2][1] =~ /\A($var_identifier_regex)\Z/;
			@tokens = (@tokens, $self->step_tokens(3));
			push @{$context_object->{block}}, { type => 'schedule_event', line_number => $tokens[0][2], controller_identifier => $tokens[1][1], event_identifier => $tokens[3][1], arguments => $self->context_action_arguments({}), };
			$self->confess_at_current_offset('expected \';\'')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq ';';
			@tokens = (@tokens, $self->step_tokens(1));
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'route') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			$self->confess_at_current_offset('expected qr/[a-zA-Z_][a-zA-Z0-9_]*+(?:::[a-zA-Z_][a-zA-Z0-9_]*+)*/')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A($var_class_identifier_regex)\Z/;
			@tokens = (@tokens, $self->step_tokens(1));
			push @{$context_object->{block}}, { type => 'route_controller', line_number => $tokens[0][2], identifier => $tokens[1][1], arguments => $self->context_action_arguments({}), };
			$self->confess_at_current_offset('expected \';\'')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq ';';
			@tokens = (@tokens, $self->step_tokens(1));
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'return' and $self->{tokens}[$self->{tokens_index} + 1][1] eq ';') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(2));
			push @{$context_object->{block}}, { type => 'return_statement', line_number => $tokens[0][2], };
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'return') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			push @{$context_object->{block}}, { type => 'return_value_statement', line_number => $tokens[0][2], expression => $self->context_action_expression, };
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
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A($var_identifier_regex)\Z/ and $self->{tokens}[$self->{tokens_index} + 1][1] eq '.' and $self->{tokens}[$self->{tokens_index} + 2][1] =~ /\A($var_identifier_regex)\Z/ and $self->{tokens}[$self->{tokens_index} + 3][1] eq '=') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(4));
			push @{$context_object->{block}}, { type => 'assign_member_variable', line_number => $tokens[0][2], variable_identifier => $tokens[0][1], identifier => $tokens[2][1], expression => $self->context_action_expression, };
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
			else {
			return $context_object;
			}
	}
	return $context_object;
}

sub context_object_constructor_expression {
	my ($self, $context_object) = @_;

	while ($self->more_tokens) {
	my @tokens;

			if ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A($var_identifier_regex)\Z/ and $self->{tokens}[$self->{tokens_index} + 1][1] eq '=') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(2));
			push @{$context_object->{values}}, { type => 'identifier_object_key', identifier => $tokens[0][1], expression => $self->context_action_expression, };
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A($var_string_regex)\Z/ and $self->{tokens}[$self->{tokens_index} + 1][1] eq '=') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(2));
			push @{$context_object->{values}}, { type => 'string_object_key', value => $self->context_format_string($tokens[0][1]), expression => $self->context_action_expression, };
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '{') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			push @{$context_object->{values}}, $self->context_object_constructor_dynamic_expression({ type => 'expression_object_key', key_expression => $self->context_action_expression, });
			}
			else {
			return $context_object;
			}
			if ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq ',') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			}
			else {
			return $context_object;
			}
	}
	return $context_object;
}

sub context_object_constructor_dynamic_expression {
	my ($self, $context_object) = @_;
	my @tokens;

			$self->confess_at_current_offset('expected \'}\', \'=\'')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '}' and $self->{tokens}[$self->{tokens_index} + 1][1] eq '=';
			@tokens = (@tokens, $self->step_tokens(2));
			$context_object->{value_expresssion} = $self->context_action_expression;
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

sub context_action_array_expression_list {
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
			push @$context_list, $self->context_action_expression;
			if ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq ',') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			}
			else {
			return $context_list;
			}
			}
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

			if ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'model' and $self->{tokens}[$self->{tokens_index} + 1][1] eq '?' and $self->{tokens}[$self->{tokens_index} + 2][1] =~ /\A($var_class_identifier_regex)\Z/) {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(3));
			$context_object = { type => 'load_optional_model_expression', line_number => $tokens[0][2], identifier => $tokens[2][1], arguments => $self->context_action_arguments({}), };
			return $context_object;
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'model' and $self->{tokens}[$self->{tokens_index} + 1][1] =~ /\A($var_class_identifier_regex)\Z/) {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(2));
			$context_object = { type => 'load_model_expression', line_number => $tokens[0][2], identifier => $tokens[1][1], arguments => $self->context_action_arguments({}), };
			return $context_object;
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'file' and $self->{tokens}[$self->{tokens_index} + 1][1] =~ /\A($var_class_identifier_regex)\Z/) {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(2));
			$context_object = { type => 'load_file_expression', line_number => $tokens[0][2], identifier => $tokens[1][1], arguments => $self->context_action_arguments({}), };
			return $context_object;
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'list' and $self->{tokens}[$self->{tokens_index} + 1][1] =~ /\A($var_class_identifier_regex)\Z/) {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(2));
			$context_object = { type => 'load_model_list_expression', line_number => $tokens[0][2], identifier => $tokens[1][1], arguments => $self->context_action_arguments({}), };
			return $context_object;
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'create' and $self->{tokens}[$self->{tokens_index} + 1][1] eq '?' and $self->{tokens}[$self->{tokens_index} + 2][1] =~ /\A($var_class_identifier_regex)\Z/) {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(3));
			$context_object = { type => 'create_optional_model_expression', line_number => $tokens[0][2], identifier => $tokens[2][1], arguments => $self->context_action_arguments({}), };
			return $context_object;
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'create' and $self->{tokens}[$self->{tokens_index} + 1][1] =~ /\A($var_class_identifier_regex)\Z/) {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(2));
			$context_object = { type => 'create_model_expression', line_number => $tokens[0][2], identifier => $tokens[1][1], arguments => $self->context_action_arguments({}), };
			return $context_object;
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'render' and $self->{tokens}[$self->{tokens_index} + 1][1] =~ /\A($var_class_identifier_regex)\Z/) {
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
			return $context_object;
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'render_json') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			push @{$context_object->{block}}, { type => 'render_json_expression', line_number => $tokens[0][2], arguments => $self->context_action_arguments({}), };
			return $context_object;
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'shell_execute') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			$context_object = { type => 'shell_execute_expression', line_number => $tokens[0][2], arguments_list => $self->context_action_expression_list([]), };
			return $context_object;
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'action' and $self->{tokens}[$self->{tokens_index} + 1][1] eq 'plugins' and $self->{tokens}[$self->{tokens_index} + 2][1] eq '.' and $self->{tokens}[$self->{tokens_index} + 3][1] =~ /\A($var_identifier_regex)\Z/ and $self->{tokens}[$self->{tokens_index} + 4][1] eq '.' and $self->{tokens}[$self->{tokens_index} + 5][1] =~ /\A($var_identifier_regex)\Z/) {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(6));
			$context_object = { type => 'plugin_action_expression', line_number => $tokens[0][2], plugin_identifier => $tokens[3][1], action_identifier => $tokens[5][1], arguments => $self->context_action_arguments({}), };
			return $context_object;
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'action' and $self->{tokens}[$self->{tokens_index} + 1][1] =~ /\A($var_controller_identifier_regex)\Z/ and $self->{tokens}[$self->{tokens_index} + 2][1] eq '.' and $self->{tokens}[$self->{tokens_index} + 3][1] =~ /\A($var_identifier_regex)\Z/) {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(4));
			$context_object = { type => 'controller_action_expression', line_number => $tokens[0][2], controller_identifier => $var_format_controller_identifier_substitution->($tokens[1][1]), action_identifier => $tokens[3][1], arguments => $self->context_action_arguments({}), };
			return $context_object;
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'action' and $self->{tokens}[$self->{tokens_index} + 1][1] =~ /\A($var_identifier_regex)\Z/) {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(2));
			$context_object = { type => 'local_controller_action_expression', line_number => $tokens[0][2], action_identifier => $tokens[1][1], arguments => $self->context_action_arguments({}), };
			return $context_object;
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'session' and $self->{tokens}[$self->{tokens_index} + 1][1] eq '.' and $self->{tokens}[$self->{tokens_index} + 2][1] =~ /\A($var_identifier_regex)\Z/) {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(3));
			$context_object = $self->context_more_action_expression({ type => 'session_variable_expression', line_number => $tokens[0][2], identifier => $tokens[2][1], });
			return $context_object;
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'len' and $self->{tokens}[$self->{tokens_index} + 1][1] eq '(') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(2));
			$context_object = { type => 'length_expression', line_number => $tokens[0][2], expression => $self->context_action_expression, };
			$self->confess_at_current_offset('expected \')\'')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq ')';
			@tokens = (@tokens, $self->step_tokens(1));
			$context_object = $self->context_more_action_expression($context_object);
			return $context_object;
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A($var_model_identifier_regex)\Z/) {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			$context_object = $self->context_more_action_expression({ type => 'model_class_expression', line_number => $tokens[0][2], identifier => $var_format_model_identifier_substitution->($tokens[0][1]), });
			return $context_object;
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A($var_native_identifier_regex)\Z/) {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			$context_object = $self->context_more_action_expression({ type => 'native_library_expression', line_number => $tokens[0][2], identifier => $var_format_native_identifier_substitution->($tokens[0][1]), });
			return $context_object;
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A($var_identifier_regex)\Z/) {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			$context_object = $self->context_more_action_expression({ type => 'variable_expression', line_number => $tokens[0][2], identifier => $tokens[0][1], });
			return $context_object;
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A($var_string_interpolation_start_regex)\Z/) {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			$context_object = $self->context_string_interpolation_expression_list({ type => 'string_interpolation_expression', line_number => $tokens[0][2], start_text => $tokens[0][1], expression_list => [], });
			return $context_object;
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A($var_string_regex)\Z/) {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			$context_object = { type => 'string_expression', line_number => $tokens[0][2], value => $self->context_format_string($tokens[0][1]), };
			return $context_object;
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '@' and $self->{tokens}[$self->{tokens_index} + 1][1] =~ /\A($var_identifier_regex)\Z/ and $self->{tokens}[$self->{tokens_index} + 2][1] eq '/' and $self->{tokens}[$self->{tokens_index} + 3][1] =~ /\A($var_identifier_regex)\Z/) {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(4));
			$context_object = { type => 'localized_string_expression', line_number => $tokens[0][2], identifier => $tokens[3][1], namespace_identifier => $tokens[1][1], };
			return $context_object;
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A($var_integer_regex)\Z/) {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			$context_object = { type => 'integer_expression', line_number => $tokens[0][2], value => $tokens[0][1], };
			return $context_object;
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '!') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			$context_object = { type => 'not_expression', line_number => $tokens[0][2], expression => $self->context_action_expression, };
			return $context_object;
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '{') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			$context_object = $self->context_object_constructor_expression({ type => 'object_expression', line_number => $tokens[0][2], });
			$self->confess_at_current_offset('expected \'}\'')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '}';
			@tokens = (@tokens, $self->step_tokens(1));
			return $context_object;
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '[') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			$context_object = { type => 'array_expression', line_number => $tokens[0][2], value => $self->context_action_array_expression_list([]), };
			return $context_object;
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '(') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			$context_object = { type => 'parentheses_expression', line_number => $tokens[0][2], value => $self->context_action_expression, };
			$self->confess_at_current_offset('expected \')\'')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq ')';
			@tokens = (@tokens, $self->step_tokens(1));
			return $context_object;
			}
			else {
			$self->confess_at_current_offset('expression expected');
			}
	}
	return $context_object;
}

sub context_string_interpolation_expression_list {
	my ($self, $context_object) = @_;
	my @tokens;

			push @{$context_object->{expression_list}}, { type => 'string_expression', value => $self->context_format_string_interpolation_start($context_object->{start_text}), };
			push @{$context_object->{expression_list}}, $self->context_action_expression;
			while ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A($var_string_interpolation_middle_regex)\Z/) {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			push @{$context_object->{expression_list}}, { type => 'string_expression', value => $self->context_format_string_interpolation_middle($tokens[0][1]), };
			push @{$context_object->{expression_list}}, $self->context_action_expression;
			}
			$self->confess_at_current_offset('expected qr/\\}\\}([^\\\\"]|\\\\[\\\\"])*?"/s')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A($var_string_interpolation_end_regex)\Z/;
			@tokens = (@tokens, $self->step_tokens(1));
			push @{$context_object->{expression_list}}, { type => 'string_expression', value => $self->context_format_string_interpolation_end($tokens[0][1]), };
			return $context_object;
}

sub context_format_string_interpolation_start {
	my ($self, $context_value) = @_;
	my @tokens;

			$context_value = $var_escape_string_substitution->($var_format_string_interpolation_start_substitution->($context_value));
			return $context_value;
}

sub context_format_string_interpolation_middle {
	my ($self, $context_value) = @_;
	my @tokens;

			$context_value = $var_escape_string_substitution->($var_format_string_interpolation_middle_substitution->($context_value));
			return $context_value;
}

sub context_format_string_interpolation_end {
	my ($self, $context_value) = @_;
	my @tokens;

			$context_value = $var_escape_string_substitution->($var_format_string_interpolation_end_substitution->($context_value));
			return $context_value;
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
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '<') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			$context_object = { type => 'less_than_expression', line_number => $tokens[0][2], left_expression => $context_object, right_expression => $self->context_action_expression, };
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '>') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			$context_object = { type => 'greather_than_expression', line_number => $tokens[0][2], left_expression => $context_object, right_expression => $self->context_action_expression, };
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '<=') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			$context_object = { type => 'less_than_or_equal_expression', line_number => $tokens[0][2], left_expression => $context_object, right_expression => $self->context_action_expression, };
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '>=') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			$context_object = { type => 'greather_than_or_equal_expression', line_number => $tokens[0][2], left_expression => $context_object, right_expression => $self->context_action_expression, };
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '==') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			$context_object = { type => 'equals_expression', line_number => $tokens[0][2], left_expression => $context_object, right_expression => $self->context_action_expression, };
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '!=') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			$context_object = { type => 'not_equals_expression', line_number => $tokens[0][2], left_expression => $context_object, right_expression => $self->context_action_expression, };
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '+') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			$context_object = { type => 'addition_expression', line_number => $tokens[0][2], left_expression => $context_object, right_expression => $self->context_action_expression, };
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '-') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			$context_object = { type => 'subtraction_expression', line_number => $tokens[0][2], left_expression => $context_object, right_expression => $self->context_action_expression, };
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '*') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			$context_object = { type => 'multiplication_expression', line_number => $tokens[0][2], left_expression => $context_object, right_expression => $self->context_action_expression, };
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '/') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			$context_object = { type => 'division_expression', line_number => $tokens[0][2], left_expression => $context_object, right_expression => $self->context_action_expression, };
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '%') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			$context_object = { type => 'modulo_expression', line_number => $tokens[0][2], left_expression => $context_object, right_expression => $self->context_action_expression, };
			}
			else {
			return $context_object;
			}
	}
	return $context_object;
}

sub context_file_directory_block {
	my ($self, $context_object) = @_;

	while ($self->more_tokens) {
	my @tokens;

			if ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'suffix_timestamp') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			$self->confess_at_current_offset('expected \';\'')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq ';';
			@tokens = (@tokens, $self->step_tokens(1));
			$context_object->{properties}{$tokens[0][1]} = '1';
			}
			else {
			return $context_object;
			}
	}
	return $context_object;
}

sub context_format_string {
	my ($self, $context_value) = @_;
	my @tokens;

			$context_value = $var_escape_string_substitution->($var_format_string_substitution->($context_value));
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


