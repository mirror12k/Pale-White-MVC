#!/usr/bin/env perl
package PaleWhite::JS::Compiler;
use strict;
use warnings;

use feature 'say';

use Data::Dumper;
use Sugar::IO::File;



sub new {
	my ($class, %args) = @_;
	my $self = bless {}, $class;

	return $self
}

sub compile_file {
	my ($self, $filepath) = @_;

	my $file = Sugar::IO::File->new($filepath);

	my @text = $file->readlines;
	my $code = join "", $self->compile_js(@text);

	return $code
}

sub compile_js {
	my ($self, @text) = @_;

	my @code;

	while (@text) {
		my $line = shift @text;
		if ($line =~ /\A\s*(.*?)\s*=>\s*on\s+(\w+)\s*\Z/s) {
			# event hook on selector
			my ($selector, $event) = ($1, $2);
			my @block = $self->read_js_block(\@text);
			push @code, "pale_white.register_hook('$selector', '$event', function (event) {\n";
			push @code, @block;
			push @code, "});\n\n";

		} elsif ($line =~ /\A\s*on\s+load\s*\Z/s) {
			# event hook on selector
			my ($selector, $event) = ($1, $2);
			my @block = $self->read_js_block(\@text);
			push @code, "window.addEventListener('load', function (event) {\n";
			push @code, @block;
			push @code, "});\n\n";

		} elsif ($line =~ /\A\s*function\s+([a-zA-Z_][a-zA-Z_0-9]*+)\s*\((.*?)\)\s*\Z/s) {
			# event hook on selector
			my ($selector, $event) = ($1, $2);
			my @block = $self->read_js_block(\@text);
			push @code, "function $1 ($2) {\n";
			push @code, @block;
			push @code, "};\n\n";

		} elsif ($line =~ /\A\s*\Z/s) {
			# empty line

		} else {
			die "unimplemented javascript block command: '$line'";
		}
	}

	return @code
}

sub read_js_block {
	my ($self, $text, $indent) = @_;
	$indent //= "\t";

	my @block;
	while (@$text and $text->[0] =~ /\A$indent|\A\s*\Z/s) {
		push @block, map "$_\n", shift @$text;
	}

	# pop any empty lines from the end
	pop @block while @block and $block[-1] =~ /\A\s*\Z/s;

	return @block
}

sub main {
	foreach my $file (@_) {
		say PaleWhite::JS::Compiler->new->compile_file($file);
	}
}

caller or main(@ARGV);

1;
