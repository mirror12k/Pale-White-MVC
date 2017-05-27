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

	my $code = "<?php\n\n";
	$code .= join '', $self->compile_template($_) foreach @{$tree->{block}};

	return $code
}

sub compile_template {
	my ($self, $template) = @_;
	die "invalid template: $template->{type}" unless $template->{type} eq 'glass_helper' and $template->{identifier} eq 'template';

	my $identifier = $template->{identifier_argument};
	my @code;

	push @code, $self->compile_template_render($template);
	push @code, $self->compile_template_render_block($template);
	
	@code = map "\t$_", @code;
	@code = ("class $identifier extends \\PaleWhite\\Glass\\Template {\n", @code, "}\n");

	return @code
}

sub compile_template_render {
	my ($self, $template) = @_;
	my @code;

	push @code, "\$text = parent::render(\$args);\n";

	if (exists $template->{block}) {
		push @code, "\n";
		foreach my $item (grep $_->{type} eq 'html_tag', @{$template->{block}}) {
			push @code, $self->compile_item($item);
		}
		# say "debug: $self->{text_accumulator}";
		push @code, $self->flush_accumulator;
		push @code, "\n";
	}

	push @code, "return \$text;\n";

	@code = map "\t$_", @code;
	@code = ("public function render (array \$args) {\n", @code, "}\n", "\n");

	return @code
}

sub compile_template_render_block {
	my ($self, $template) = @_;
	my @code;

	my %blocks;
	if (exists $template->{block}) {
		foreach my $item (grep { $_->{type} eq 'glass_helper' and $_->{identifier} eq 'block' } @{$template->{block}}) {
			$blocks{$item->{identifier_argument}} = $item;
		}
	}

	return @code unless keys %blocks;

	push @code, "\$text = parent::render_block(\$block, \$args);\n";
	push @code, "\n";

	foreach my $block (sort keys %blocks) {
		my @block_code = $self->compile_block($blocks{$block}{block});
		push @block_code, $self->flush_accumulator;

		push @code, "if (\$block === '$block') {\n";
		push @code, map "\t$_", @block_code;
		push @code, "}\n";
	}

	push @code, "\n";
	push @code, "return \$text;\n";

	@code = map "\t$_", @code;
	@code = ("public function render_block (string \$block, array \$args) {\n", @code, "}\n", "\n");

	return @code
}

sub compile_block {
	my ($self, $block) = @_;

	my @code;
	foreach my $item (@$block) {
		push @code, $self->compile_item($item);
	}

	return @code
}

sub compile_item {
	my ($self, $item) = @_;

	if ($item->{type} eq 'html_tag') {
		return $self->compile_html_tag($item)
	} elsif ($item->{type} eq 'glass_helper' and $item->{identifier} eq 'block') {
		return $self->flush_accumulator, "\$text .= \$this->render_block('$item->{identifier_argument}', \$args);\n"
	} elsif ($item->{type} eq 'expression_node') {
		return $self->compile_argument_expression($item->{expression}), map $self->compile_argument_expression($_), @{$item->{text}}
	} else {
		die "invalid item: $item->{type}";
	}
}

sub compile_html_tag {
	my ($self, $tag) = @_;
	my @code;

	my $identifier = $tag->{identifier} // 'div';

	$self->{text_accumulator} .= "<$identifier";
	$self->{text_accumulator} .= " id=\"$tag->{id}\"" if exists $tag->{id};
	$self->{text_accumulator} .= ' class="' . join (' ', @{$tag->{class}}) . '"' if exists $tag->{class};

	if (exists $tag->{attributes}) {
		foreach my $key (sort keys %{$tag->{attributes}}) {
			$self->{text_accumulator} .= " $key=\"";
			push @code, $self->compile_argument_expression($tag->{attributes}{$key});
			$self->{text_accumulator} .= "\"";

		}
	}
	$self->{text_accumulator} .= ">";
	# push @fields, map "$_=" . $self->compile_html_attribute($tag->{attributes}{$_}), keys %{$tag->{attributes}} if exists $tag->{attributes};

	# my $start_tag = '<' . join (' ', @fields) . '>';
	# $self->{text_accumulator} .= $start_tag;

	push @code, map $self->compile_argument_expression($_), @{$tag->{text}} if exists $tag->{text};

	push @code, $self->compile_block($tag->{block}) if exists $tag->{block};

	# my $end_tag = "</$identifier>";
	$self->{text_accumulator} .= "</$identifier>";

	return @code
}

# sub compile_html_attribute {
# 	my ($self, $expression) = @_;

# 	if ($expression->{type} eq 'string_expression') {
# 		return "\"$expression->{string}\""
# 	} elsif ($expression->{type} eq 'variable_expression') {
# 		return "\"' . \$args[\"$expression->{identifier}\"] . '\""
# 	} else {
# 		die "unknown html attribute expression: $expression->{type}";
# 	}
# }

sub compile_argument_expression {
	my ($self, $expression) = @_;

	if ($expression->{type} eq 'string_expression') {
		$self->{text_accumulator} .= $expression->{string};
		return
		
	} elsif ($expression->{type} eq 'variable_expression') {
		# $self->{text_accumulator} .= "' . \$args[\"$expression->{identifier}\"] . '";
		return $self->flush_accumulator, "\$text .= \$args[\"$expression->{identifier}\"];\n";

	} else {
		die "unknown expression: $expression->{type}";
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
