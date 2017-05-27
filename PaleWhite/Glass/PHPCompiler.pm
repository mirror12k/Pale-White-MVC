#!/usr/bin/env perl
package PaleWhite::Glass::PHPCompiler;
use strict;
use warnings;

use feature 'say';

use Data::Dumper;

use PaleWhite::GlassParser;



sub new {
	my ($class, %args) = @_;
	my $self = bless {}, $class;

	$self->{text_accumulator} = '';
	return $self
}



sub flush_accumulator {
	my ($self) = @_;

	my @code;
	if (length $self->{text_accumulator} > 0) {
		my $text = $self->{text_accumulator} =~ s/([\\'])/\\$1/gr;
		push @code, "\$text .= '$text';\n";
		$self->{text_accumulator} = '';
	}

	return @code
}

sub compile {
	my ($self, $tree) = @_;

	my $code = "\n";
	$code .= join '', $self->compile_template($_) foreach @{$tree->{block}};

	return $code
}

sub compile_template {
	my ($self, $template) = @_;
	die "invalid template: $template->{type}" unless $template->{type} eq 'glass_helper' and $template->{identifier} eq 'template';

	my $identifier = $template->{identifier_argument};
	my @code;

	push @code, "\$text = '';\n";

	if (exists $template->{block}) {
		foreach my $item (@{$template->{block}}) {
			push @code, $self->compile_html_tag($item);
		}
		# say "debug: $self->{text_accumulator}";
		push @code, $self->flush_accumulator;
	}

	push @code, "return \$text;\n";

	@code = map "\t$_", @code;
	@code = ("public function render (array \$args) {\n", @code, "}\n");
	
	@code = map "\t$_", @code;
	@code = ("class $identifier extends \\Glass\\Template {\n", @code, "}\n");

	return @code
}

sub compile_html_tag {
	my ($self, $tag) = @_;
	my @code;

	my $identifier = $tag->{identifier} // 'div';

	my @fields;
	push @fields, $identifier;
	push @fields, "id=\"$tag->{id}\"" if exists $tag->{id};
	push @fields, 'class="' . join (' ', @{$tag->{class}}) . '"' if exists $tag->{class};
	push @fields, map "$_=" . $self->compile_html_attribute($tag->{attributes}{$_}), keys %{$tag->{attributes}} if exists $tag->{attributes};

	my $start_tag = '<' . join (' ', @fields) . '>';
	$self->{text_accumulator} .= $start_tag;

	if (exists $tag->{block}) {
		foreach my $item (@{$tag->{block}}) {
			push @code, $self->compile_html_tag($item);
		}
	}

	my $end_tag = "</$identifier>";
	$self->{text_accumulator} .= $end_tag;

	return @code
}

sub compile_html_attribute {
	my ($self, $expression) = @_;

	if ($expression->{type} eq 'string_expression') {
		return "\"$expression->{string}\""
	} else {
		die "unknown html attribute expression: $expression->{type}";
	}
}





sub main {
	use Data::Dumper;
	use Sugar::IO::File;

	my $parser = PaleWhite::GlassParser->new;
	foreach my $file (@_) {
		$parser->{filepath} = Sugar::IO::File->new($file);
		my $tree = $parser->parse;
		# say Dumper $tree;

		my $compiler = __PACKAGE__->new;
		my $text = $compiler->compile($tree);
		say $text;
	}
}

caller or main(@ARGV);
