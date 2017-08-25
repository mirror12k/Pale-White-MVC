#!/usr/bin/env perl
package PaleWhite::Glass::Parser;
use parent 'Sugar::Lang::BaseSyntaxParser';
use strict;
use warnings;

use feature 'say';





##############################
##### variables and settings
##############################

our $var_identifier_regex = qr/[a-zA-Z_][a-zA-Z0-9_]*+/;
our $var_string_interpolation_start_regex = qr/"([^\\"]|\\[\\"])*?\{\{/s;
our $var_string_interpolation_middle_regex = qr/\}\}([^\\"]|\\[\\"])*?\{\{/s;
our $var_string_interpolation_end_regex = qr/\}\}([^\\"]|\\[\\"])*?"/s;
our $var_integer_regex = qr/-?\d++/;
our $var_string_regex = qr/"([^\\"]|\\[\\"])*?"/s;
our $var_symbol_regex = qr/!|\.|\#|=>|<|>|<=|>=|==|=|,|\{|\}|\(|\)|\[|\]|-|\@|\//;
our $var_indent_regex = qr/\t++/;
our $var_whitespace_regex = qr/[\t \r]++/;
our $var_newline_regex = qr/\s*(\#[^\n]*+\s*)*\n/s;
our $var_escape_string_substitution = sub { $_[0] =~ s/\\([\\"])/$1/gsr };
our $var_format_string_substitution = sub { $_[0] =~ s/\A"(.*)"\Z/$1/sr };
our $var_format_string_interpolation_start_substitution = sub { $_[0] =~ s/\A"(.*)\{\{\Z/$1/sr };
our $var_format_string_interpolation_middle_substitution = sub { $_[0] =~ s/\A\}\}(.*)\{\{\Z/$1/sr };
our $var_format_string_interpolation_end_substitution = sub { $_[0] =~ s/\A\}\}(.*)"\Z/$1/sr };


our $tokens = [
	'identifier' => $var_identifier_regex,
	'string_interpolation_start' => $var_string_interpolation_start_regex,
	'string_interpolation_middle' => $var_string_interpolation_middle_regex,
	'string_interpolation_end' => $var_string_interpolation_end_regex,
	'integer' => $var_integer_regex,
	'string' => $var_string_regex,
	'symbol' => $var_symbol_regex,
	'indent' => $var_indent_regex,
	'whitespace' => $var_whitespace_regex,
	'newline' => $var_newline_regex,
];

our $ignored_tokens = [
	'whitespace',
];

our $contexts = {
	format_string => 'context_format_string',
	format_string_interpolation_end => 'context_format_string_interpolation_end',
	format_string_interpolation_middle => 'context_format_string_interpolation_middle',
	format_string_interpolation_start => 'context_format_string_interpolation_start',
	glass_argument_expression => 'context_glass_argument_expression',
	glass_arguments => 'context_glass_arguments',
	glass_array_expression_list => 'context_glass_array_expression_list',
	glass_block => 'context_glass_block',
	glass_expression_list => 'context_glass_expression_list',
	glass_helper => 'context_glass_helper',
	glass_interpolation_expression => 'context_glass_interpolation_expression',
	glass_item => 'context_glass_item',
	glass_more_expression => 'context_glass_more_expression',
	glass_object_arguments => 'context_glass_object_arguments',
	glass_tag => 'context_glass_tag',
	glass_tag_attribute => 'context_glass_tag_attribute',
	glass_tag_text => 'context_glass_tag_text',
	parse_attribute_arguments => 'context_parse_attribute_arguments',
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
	my @tokens;

			$context_object = $self->context_root_glass_block({ type => 'root', block => [], indent => '', });
			return $context_object;
}

sub context_root_glass_block {
	my ($self, $context_object) = @_;

	while ($self->more_tokens) {
	my @tokens;

			while ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A($var_newline_regex)\Z/) {
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

			while ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A($var_newline_regex)\Z/) {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			}
			if ($self->more_tokens and $self->match_indent($self->{tokens_index} + 0, $context_object)) {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			push @{$context_object->{block}}, $self->context_glass_item($tokens[0][1]);
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

			if ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '!' and $self->{tokens}[$self->{tokens_index} + 1][1] eq 'foreach') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(2));
			$context_object = { type => 'glass_helper', line_number => $tokens[0][2], identifier => $tokens[1][1], expression => $self->context_glass_argument_expression, indent => $context_object, };
			if ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'as' and $self->{tokens}[$self->{tokens_index} + 1][1] =~ /\A($var_identifier_regex)\Z/ and $self->{tokens}[$self->{tokens_index} + 2][1] eq '=>' and $self->{tokens}[$self->{tokens_index} + 3][1] =~ /\A($var_identifier_regex)\Z/) {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(4));
			$context_object->{key_identifier} = $tokens[3][1];
			$context_object->{value_identifier} = $tokens[5][1];
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'as' and $self->{tokens}[$self->{tokens_index} + 1][1] =~ /\A($var_identifier_regex)\Z/) {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(2));
			$context_object->{value_identifier} = $tokens[3][1];
			}
			else {
			$context_object->{value_identifier} = '_';
			}
			$self->confess_at_current_offset('expected qr/\\s*(\\#[^\\n]*+\\s*)*\\n/s')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A($var_newline_regex)\Z/;
			@tokens = (@tokens, $self->step_tokens(1));
			$context_object = $self->context_glass_block($context_object);
			return $context_object;
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '!' and $self->{tokens}[$self->{tokens_index} + 1][1] eq 'if') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(2));
			$context_object = { type => 'glass_helper', line_number => $tokens[0][2], identifier => $tokens[1][1], expression => $self->context_glass_argument_expression, indent => $context_object, };
			$self->confess_at_current_offset('expected qr/\\s*(\\#[^\\n]*+\\s*)*\\n/s')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A($var_newline_regex)\Z/;
			@tokens = (@tokens, $self->step_tokens(1));
			$context_object = $self->context_glass_block($context_object);
			return $context_object;
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '!' and $self->{tokens}[$self->{tokens_index} + 1][1] eq 'elseif') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(2));
			$context_object = { type => 'glass_helper', line_number => $tokens[0][2], identifier => $tokens[1][1], expression => $self->context_glass_argument_expression, indent => $context_object, };
			$self->confess_at_current_offset('expected qr/\\s*(\\#[^\\n]*+\\s*)*\\n/s')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A($var_newline_regex)\Z/;
			@tokens = (@tokens, $self->step_tokens(1));
			$context_object = $self->context_glass_block($context_object);
			return $context_object;
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '!' and $self->{tokens}[$self->{tokens_index} + 1][1] eq 'else') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(2));
			$context_object = { type => 'glass_helper', line_number => $tokens[0][2], identifier => $tokens[1][1], indent => $context_object, };
			$self->confess_at_current_offset('expected qr/\\s*(\\#[^\\n]*+\\s*)*\\n/s')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A($var_newline_regex)\Z/;
			@tokens = (@tokens, $self->step_tokens(1));
			$context_object = $self->context_glass_block($context_object);
			return $context_object;
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '!' and $self->{tokens}[$self->{tokens_index} + 1][1] eq 'block') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(2));
			$self->confess_at_current_offset('expected qr/[a-zA-Z_][a-zA-Z0-9_]*+/')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A($var_identifier_regex)\Z/;
			@tokens = (@tokens, $self->step_tokens(1));
			$context_object = { type => 'glass_helper', line_number => $tokens[0][2], identifier => $tokens[1][1], argument => $tokens[2][1], indent => $context_object, };
			$self->confess_at_current_offset('expected qr/\\s*(\\#[^\\n]*+\\s*)*\\n/s')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A($var_newline_regex)\Z/;
			@tokens = (@tokens, $self->step_tokens(1));
			$context_object = $self->context_glass_block($context_object);
			return $context_object;
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '!' and $self->{tokens}[$self->{tokens_index} + 1][1] eq 'template') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(2));
			if ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A($var_identifier_regex)\Z/ and $self->{tokens}[$self->{tokens_index} + 1][1] eq 'extends' and $self->{tokens}[$self->{tokens_index} + 2][1] =~ /\A($var_identifier_regex)\Z/ and $self->{tokens}[$self->{tokens_index} + 3][1] =~ /\A($var_newline_regex)\Z/) {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(4));
			$context_object = { type => 'glass_helper', line_number => $tokens[0][2], identifier => $tokens[1][1], argument => $tokens[2][1], parent_template => $tokens[4][1], indent => $context_object, };
			$context_object = $self->context_glass_block($context_object);
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A($var_identifier_regex)\Z/ and $self->{tokens}[$self->{tokens_index} + 1][1] =~ /\A($var_newline_regex)\Z/) {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(2));
			$context_object = { type => 'glass_helper', line_number => $tokens[0][2], identifier => $tokens[1][1], argument => $tokens[2][1], indent => $context_object, };
			$context_object = $self->context_glass_block($context_object);
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A($var_identifier_regex)\Z/) {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			$context_object = { type => 'glass_helper', line_number => $tokens[0][2], identifier => 'template_call', template => $tokens[2][1], arguments => $self->context_glass_arguments({}), indent => $context_object, };
			$context_object = $self->context_glass_block($context_object);
			}
			else {
			$self->confess_at_current_offset('expected template call or definition');
			}
			return $context_object;
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '!' and $self->{tokens}[$self->{tokens_index} + 1][1] =~ /\A($var_identifier_regex)\Z/) {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(2));
			$context_object = $self->context_glass_helper({ type => 'glass_helper', line_number => $tokens[0][2], identifier => $tokens[1][1], indent => $context_object, });
			$self->confess_at_current_offset('expected qr/\\s*(\\#[^\\n]*+\\s*)*\\n/s')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A($var_newline_regex)\Z/;
			@tokens = (@tokens, $self->step_tokens(1));
			$context_object = $self->context_glass_block($context_object);
			return $context_object;
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A($var_identifier_regex)\Z/) {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			$context_object = $self->context_glass_tag_text($self->context_parse_attribute_arguments($self->context_glass_tag({ type => 'html_tag', line_number => $tokens[0][2], identifier => $tokens[0][1], indent => $context_object, })));
			$self->confess_at_current_offset('expected qr/\\s*(\\#[^\\n]*+\\s*)*\\n/s')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A($var_newline_regex)\Z/;
			@tokens = (@tokens, $self->step_tokens(1));
			$context_object = $self->context_glass_block($context_object);
			return $context_object;
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A($var_string_interpolation_start_regex)\Z/) {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			$context_object = { type => 'expression_node', line_number => $tokens[0][2], expression => $self->context_glass_interpolation_expression($tokens[0][1]), };
			$self->confess_at_current_offset('expected qr/\\s*(\\#[^\\n]*+\\s*)*\\n/s')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A($var_newline_regex)\Z/;
			@tokens = (@tokens, $self->step_tokens(1));
			return $context_object;
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A($var_string_regex)\Z/) {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			$context_object = { type => 'expression_node', line_number => $tokens[0][2], expression => { type => 'string_expression', string => $self->context_format_string($tokens[0][1]), }, };
			$self->confess_at_current_offset('expected qr/\\s*(\\#[^\\n]*+\\s*)*\\n/s')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A($var_newline_regex)\Z/;
			@tokens = (@tokens, $self->step_tokens(1));
			return $context_object;
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '{' and $self->{tokens}[$self->{tokens_index} + 1][1] eq '<') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(2));
			$context_object = { type => 'raw_html_expression_node', line_number => $tokens[0][2], expression => $self->context_glass_argument_expression, };
			$self->confess_at_current_offset('expected \'>\', \'}\'')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '>' and $self->{tokens}[$self->{tokens_index} + 1][1] eq '}';
			@tokens = (@tokens, $self->step_tokens(2));
			$self->confess_at_current_offset('expected qr/\\s*(\\#[^\\n]*+\\s*)*\\n/s')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A($var_newline_regex)\Z/;
			@tokens = (@tokens, $self->step_tokens(1));
			return $context_object;
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '{') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			$context_object = { type => 'expression_node', line_number => $tokens[0][2], expression => $self->context_glass_argument_expression, };
			$self->confess_at_current_offset('expected \'}\'')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '}';
			@tokens = (@tokens, $self->step_tokens(1));
			$self->confess_at_current_offset('expected qr/\\s*(\\#[^\\n]*+\\s*)*\\n/s')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A($var_newline_regex)\Z/;
			@tokens = (@tokens, $self->step_tokens(1));
			return $context_object;
			}
			else {
			$self->confess_at_current_offset('glass item expected');
			}
	}
	return $context_object;
}

sub context_glass_tag {
	my ($self, $context_object) = @_;

	while ($self->more_tokens) {
	my @tokens;

			if ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '.' and $self->{tokens}[$self->{tokens_index} + 1][1] =~ /\A($var_identifier_regex)\Z/) {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(2));
			push @{$context_object->{class}}, $self->extended_html_class($tokens[1][1]);
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '#' and $self->{tokens}[$self->{tokens_index} + 1][1] =~ /\A($var_identifier_regex)\Z/) {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(2));
			$context_object->{id} = $tokens[1][1];
			}
			else {
			return $context_object;
			}
	}
	return $context_object;
}

sub context_parse_attribute_arguments {
	my ($self, $context_object) = @_;

	while ($self->more_tokens) {
	my @tokens;

			if ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A($var_identifier_regex)\Z/ and $self->{tokens}[$self->{tokens_index} + 1][1] eq '=') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(2));
			$context_object->{attributes}{$tokens[0][1]} = $self->context_glass_tag_attribute;
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A("[a-zA-Z_][a-zA-Z0-9_\-]*+")\Z/ and $self->{tokens}[$self->{tokens_index} + 1][1] eq '=') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(2));
			$context_object->{attributes}{$self->context_format_string($tokens[0][1])} = $self->context_glass_tag_attribute;
			}
			else {
			return $context_object;
			}
	}
	return $context_object;
}

sub context_glass_tag_attribute {
	my ($self, $context_object) = @_;

	while ($self->more_tokens) {
	my @tokens;

			if ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A($var_string_regex)\Z/) {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			$context_object = { type => 'string_expression', string => $self->context_format_string($tokens[0][1]), };
			return $context_object;
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A($var_string_interpolation_start_regex)\Z/) {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			$context_object = $self->context_glass_interpolation_expression($tokens[0][1]);
			return $context_object;
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '{') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			$context_object = $self->context_glass_argument_expression;
			$self->confess_at_current_offset('expected \'}\'')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '}';
			@tokens = (@tokens, $self->step_tokens(1));
			return $context_object;
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '@' and $self->{tokens}[$self->{tokens_index} + 1][1] =~ /\A($var_identifier_regex)\Z/ and $self->{tokens}[$self->{tokens_index} + 2][1] eq '/' and $self->{tokens}[$self->{tokens_index} + 3][1] =~ /\A($var_identifier_regex)\Z/) {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(4));
			$context_object = { type => 'localized_string_expression', line_number => $tokens[0][2], identifier => $tokens[3][1], namespace_identifier => $tokens[1][1], };
			return $context_object;
			}
			else {
			$self->confess_at_current_offset('attribute expression expected');
			}
	}
	return $context_object;
}

sub context_glass_interpolation_expression {
	my ($self, $context_object) = @_;
	my @tokens;

			$context_object = { type => 'interpolation_expression', start_text => $context_object, };
			push @{$context_object->{expressions}}, { type => 'string_expression', string => $self->context_format_string_interpolation_start($context_object->{start_text}), };
			push @{$context_object->{expressions}}, $self->context_glass_argument_expression;
			while ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A($var_string_interpolation_middle_regex)\Z/) {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			push @{$context_object->{expressions}}, { type => 'string_expression', string => $self->context_format_string_interpolation_middle($tokens[0][1]), };
			push @{$context_object->{expressions}}, $self->context_glass_argument_expression;
			}
			$self->confess_at_current_offset('expected qr/\\}\\}([^\\\\"]|\\\\[\\\\"])*?"/s')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A($var_string_interpolation_end_regex)\Z/;
			@tokens = (@tokens, $self->step_tokens(1));
			push @{$context_object->{expressions}}, { type => 'string_expression', string => $self->context_format_string_interpolation_end($tokens[0][1]), };
			return $context_object;
}

sub context_glass_tag_text {
	my ($self, $context_object) = @_;

	while ($self->more_tokens) {
	my @tokens;

			if ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A($var_string_regex)\Z/) {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			$context_object->{text_expression} = { type => 'string_expression', string => $self->context_format_string($tokens[0][1]), };
			return $context_object;
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A($var_string_interpolation_start_regex)\Z/) {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			$context_object->{text_expression} = $self->context_glass_interpolation_expression($tokens[0][1]);
			return $context_object;
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '{') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			$context_object->{text_expression} = $self->context_glass_argument_expression;
			$self->confess_at_current_offset('expected \'}\'')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '}';
			@tokens = (@tokens, $self->step_tokens(1));
			return $context_object;
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '@' and $self->{tokens}[$self->{tokens_index} + 1][1] =~ /\A($var_identifier_regex)\Z/ and $self->{tokens}[$self->{tokens_index} + 2][1] eq '/' and $self->{tokens}[$self->{tokens_index} + 3][1] =~ /\A($var_identifier_regex)\Z/) {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(4));
			$context_object->{text_expression} = { type => 'localized_string_expression', line_number => $tokens[0][2], identifier => $tokens[3][1], namespace_identifier => $tokens[1][1], };
			return $context_object;
			}
			else {
			return $context_object;
			}
	}
	return $context_object;
}

sub context_glass_argument_expression {
	my ($self, $context_object) = @_;

	while ($self->more_tokens) {
	my @tokens;

			if ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A($var_integer_regex)\Z/) {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			$context_object = { type => 'integer_expression', line_number => $tokens[0][2], value => $tokens[0][1], };
			return $context_object;
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A($var_string_regex)\Z/) {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			$context_object = { type => 'string_expression', line_number => $tokens[0][2], string => $self->context_format_string($tokens[0][1]), };
			return $context_object;
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A($var_string_interpolation_start_regex)\Z/) {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			$context_object = $self->context_glass_interpolation_expression($tokens[0][1]);
			return $context_object;
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'len' and $self->{tokens}[$self->{tokens_index} + 1][1] eq '(') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(2));
			$context_object = { type => 'length_expression', line_number => $tokens[0][2], expression => $self->context_glass_argument_expression, };
			$self->confess_at_current_offset('expected \')\'')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq ')';
			@tokens = (@tokens, $self->step_tokens(1));
			$context_object = $self->context_glass_more_expression($context_object);
			return $context_object;
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A($var_identifier_regex)\Z/) {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			$context_object = $self->context_glass_more_expression({ type => 'variable_expression', line_number => $tokens[0][2], identifier => $tokens[0][1], });
			return $context_object;
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '[') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			$context_object = $self->context_glass_more_expression({ type => 'array_expression', line_number => $tokens[0][2], expression_list => $self->context_glass_array_expression_list([]), });
			return $context_object;
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '{') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			$context_object = $self->context_glass_more_expression({ type => 'object_expression', line_number => $tokens[0][2], object_fields => $self->context_glass_object_arguments({}), });
			return $context_object;
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '@' and $self->{tokens}[$self->{tokens_index} + 1][1] =~ /\A($var_identifier_regex)\Z/ and $self->{tokens}[$self->{tokens_index} + 2][1] eq '/' and $self->{tokens}[$self->{tokens_index} + 3][1] =~ /\A($var_identifier_regex)\Z/) {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(4));
			$context_object = { type => 'localized_string_expression', line_number => $tokens[0][2], identifier => $tokens[3][1], namespace_identifier => $tokens[1][1], };
			return $context_object;
			}
			else {
			$self->confess_at_current_offset('expression expected');
			}
	}
	return $context_object;
}

sub context_glass_arguments {
	my ($self, $context_object) = @_;

	while ($self->more_tokens) {
	my @tokens;

			if ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A($var_identifier_regex)\Z/ and $self->{tokens}[$self->{tokens_index} + 1][1] eq '=') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(2));
			$context_object->{$tokens[0][1]} = $self->context_glass_argument_expression;
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
			$context_object->{$self->context_format_string($tokens[0][1])} = $self->context_glass_argument_expression;
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

sub context_glass_object_arguments {
	my ($self, $context_object) = @_;

	while ($self->more_tokens) {
	my @tokens;

			if ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '}') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			return $context_object;
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A($var_newline_regex)\Z/) {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A($var_indent_regex)\Z/) {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A($var_identifier_regex)\Z/) {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			$self->confess_at_current_offset('expected \'=\'')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '=';
			@tokens = (@tokens, $self->step_tokens(1));
			$context_object->{$tokens[0][1]} = $self->context_glass_argument_expression;
			if ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq ',') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			}
			else {
			if ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A($var_newline_regex)\Z/) {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			}
			if ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A($var_indent_regex)\Z/) {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			}
			$self->confess_at_current_offset('expected \'}\'')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '}';
			@tokens = (@tokens, $self->step_tokens(1));
			return $context_object;
			}
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A($var_string_regex)\Z/) {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			$self->confess_at_current_offset('expected \'=\'')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '=';
			@tokens = (@tokens, $self->step_tokens(1));
			$context_object->{$self->context_format_string($tokens[0][1])} = $self->context_glass_argument_expression;
			if ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq ',') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			}
			else {
			if ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A($var_newline_regex)\Z/) {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			}
			if ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A($var_indent_regex)\Z/) {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			}
			$self->confess_at_current_offset('expected \'}\'')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '}';
			@tokens = (@tokens, $self->step_tokens(1));
			return $context_object;
			}
			}
			else {
			$self->confess_at_current_offset('expected object key-value pair');
			}
	}
	return $context_object;
}

sub context_glass_expression_list {
	my ($self, $context_list) = @_;
	my @tokens;

			push @$context_list, $self->context_glass_argument_expression;
			while ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq ',') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			push @$context_list, $self->context_glass_argument_expression;
			}
			return $context_list;
}

sub context_glass_array_expression_list {
	my ($self, $context_list) = @_;

	while ($self->more_tokens) {
	my @tokens;

			if ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq ']') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			return $context_list;
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A($var_newline_regex)\Z/) {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A($var_indent_regex)\Z/) {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			}
			else {
			push @$context_list, $self->context_glass_argument_expression;
			if ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq ',') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			}
			else {
			if ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A($var_newline_regex)\Z/) {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			}
			if ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A($var_indent_regex)\Z/) {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			}
			$self->confess_at_current_offset('expected \']\'')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq ']';
			@tokens = (@tokens, $self->step_tokens(1));
			return $context_list;
			}
			}
	}
	return $context_list;
}

sub context_glass_more_expression {
	my ($self, $context_object) = @_;

	while ($self->more_tokens) {
	my @tokens;

			if ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '.' and $self->{tokens}[$self->{tokens_index} + 1][1] =~ /\A($var_identifier_regex)\Z/ and $self->{tokens}[$self->{tokens_index} + 2][1] eq '(') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(3));
			$context_object = { type => 'method_call_expression', line_number => $tokens[0][2], identifier => $tokens[1][1], expression => $context_object, };
			if ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq ')') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			$context_object->{arguments_list} = [];
			}
			else {
			$context_object->{arguments_list} = $self->context_glass_expression_list([]);
			$self->confess_at_current_offset('expected \')\'')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq ')';
			@tokens = (@tokens, $self->step_tokens(1));
			}
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '.') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			$self->confess_at_current_offset('expected qr/[a-zA-Z_][a-zA-Z0-9_]*+/')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A($var_identifier_regex)\Z/;
			@tokens = (@tokens, $self->step_tokens(1));
			$context_object = { type => 'access_expression', line_number => $tokens[0][2], identifier => $tokens[1][1], expression => $context_object, };
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '<') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			$context_object = { type => 'less_than_expression', line_number => $tokens[0][2], identifier => $tokens[1][1], left_expression => $context_object, right_expression => $self->context_glass_argument_expression, };
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '>') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			$context_object = { type => 'greather_than_expression', line_number => $tokens[0][2], identifier => $tokens[1][1], left_expression => $context_object, right_expression => $self->context_glass_argument_expression, };
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '<=') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			$context_object = { type => 'less_than_or_equal_expression', line_number => $tokens[0][2], identifier => $tokens[1][1], left_expression => $context_object, right_expression => $self->context_glass_argument_expression, };
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '>=') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			$context_object = { type => 'greather_than_or_equal_expression', line_number => $tokens[0][2], identifier => $tokens[1][1], left_expression => $context_object, right_expression => $self->context_glass_argument_expression, };
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '==') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			$context_object = { type => 'equals_expression', line_number => $tokens[0][2], identifier => $tokens[1][1], left_expression => $context_object, right_expression => $self->context_glass_argument_expression, };
			}
			else {
			return $context_object;
			}
	}
	return $context_object;
}

sub context_glass_helper {
	my ($self, $context_object) = @_;
	my @tokens;

			while ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A($var_identifier_regex)\Z/) {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			push @{$context_object->{arguments}}, $tokens[0][1];
			}
			return $context_object;
}

sub context_format_string {
	my ($self, $context_value) = @_;
	my @tokens;

			$context_value = $var_escape_string_substitution->($var_format_string_substitution->($context_value));
			return $context_value;
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


##############################
##### native perl functions
##############################

sub match_indent {
	my ($self, $offset, $item) = @_;
	return ($self->{tokens}[$offset][1] =~ /\A\t++\Z/
		and length $self->{tokens}[$offset][1] > length $item->{indent})
}

sub extended_html_class {
	my ($self, $class) = @_;
	while ($self->more_tokens(1)
			and $self->{tokens}[$self->{tokens_index}][1] eq '-'
			and $self->{tokens}[$self->{tokens_index} + 1][1] =~ $var_identifier_regex) {
		my @tokens = $self->step_tokens(2);
		$class .= "-$tokens[1][1]";
	}
	return $class
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


