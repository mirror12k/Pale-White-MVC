#!/usr/bin/env perl
package PaleWhite::Glass::PHPCompiler;
use strict;
use warnings;

use feature 'say';

use Data::Dumper;



sub new {
	my ($class, %args) = @_;
	my $self = bless {}, $class;

	$self->{text_accumulator} = '';
	$self->{local_variable_scope} = {};
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

sub map_class_name {
	my ($self, $classname) = @_;

	return "/$classname" =~ s/\//\\/gr;
}

sub compile_template {
	my ($self, $template) = @_;
	die "invalid template: $template->{type}" unless $template->{type} eq 'glass_helper' and $template->{identifier} eq 'template';

	my $identifier = $template->{arguments}[0];
	my @code;

	my $parent = $template->{arguments}[2] // 'PaleWhite/Glass/Template';
	$parent = $self->map_class_name($parent);

	push @code, $self->compile_template_render($template);
	push @code, $self->compile_template_render_block($template);
	
	@code = map "\t$_", @code;
	@code = ("class $identifier extends $parent {\n", @code, "}\n", "\n");

	return @code
}

sub compile_template_render {
	my ($self, $template) = @_;
	my @code;

	my @tags;
	if (exists $template->{block}) {
		@tags = grep $_->{type} eq 'html_tag', @{$template->{block}};
	}
	return @code unless @tags;

	push @code, "\$text = parent::render(\$args);\n";
	push @code, "\n";
	foreach my $item (@tags) {
		push @code, $self->compile_item($item);
	}
	# say "debug: $self->{text_accumulator}";
	push @code, $self->flush_accumulator;
	push @code, "\n";

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
			$blocks{$item->{arguments}[0]} = $item;
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
	@code = ("public function render_block (\$block, array \$args) {\n", @code, "}\n", "\n");

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
		return $self->flush_accumulator, "\$text .= \$this->render_block('$item->{arguments}[0]', \$args);\n"
	} elsif ($item->{type} eq 'glass_helper' and $item->{identifier} eq 'foreach') {
		my @code;
		push @code, $self->flush_accumulator;
		push @code, "foreach (" . $self->compile_value_expression($item->{expression}) . " as " . (
						exists $item->{key_identifier} ? "\$$item->{key_identifier} => \$$item->{value_identifier}" : "\$$item->{value_identifier}"
					) . ") {\n";
		my $prev_scope = $self->{local_variable_scope};
		$self->{local_variable_scope} = { %$prev_scope };
		$self->{local_variable_scope}{$item->{value_identifier}} = 1;
		$self->{local_variable_scope}{$item->{key_identifier}} = 1 if exists $item->{key_identifier};
		push @code, map "\t$_", $self->compile_block($item->{block});
		push @code, map "\t$_", $self->flush_accumulator;
		$self->{local_variable_scope} = $prev_scope;
		push @code, "}\n";
		return @code

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
			if ((
					($identifier eq 'a' and $key eq 'href')
					or ($identifier eq 'link' and $key eq 'href')
				) and ($tag->{attributes}{$key}{type} eq 'string_expression' or $tag->{attributes}{$key}{type} eq 'interpolation_expression')) {
				my $expression = $tag->{attributes}{$key};
				$expression = $expression->{expressions}[0] if $expression->{type} eq 'interpolation_expression';

				if ($expression->{string} =~ /\A\//) {
					push @code, $self->compile_argument_expression({ type => 'variable_expression', identifier => '_site_base' });
				}
			}
			push @code, $self->compile_argument_expression($tag->{attributes}{$key});
			$self->{text_accumulator} .= "\"";

		}
	}
	$self->{text_accumulator} .= ">";
	# push @fields, map "$_=" . $self->compile_html_attribute($tag->{attributes}{$_}), keys %{$tag->{attributes}} if exists $tag->{attributes};

	# my $start_tag = '<' . join (' ', @fields) . '>';
	# $self->{text_accumulator} .= $start_tag;

	push @code, $self->compile_argument_expression($tag->{text_expression}) if exists $tag->{text_expression};

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
		# return $self->flush_accumulator, "\$text .= \$args[\"$expression->{identifier}\"];\n";
		return $self->flush_accumulator, "\$text .= " . $self->compile_value_expression($expression) . ";\n";

	} elsif ($expression->{type} eq 'access_expression') {
		# $self->{text_accumulator} .= "' . \$args[\"$expression->{identifier}\"] . '";
		return $self->flush_accumulator, "\$text .= " . $self->compile_value_expression($expression) . ";\n";

	} elsif ($expression->{type} eq 'interpolation_expression') {
		return map $self->compile_argument_expression($_), @{$expression->{expressions}}
		# $self->{text_accumulator} .= "' . \$args[\"$expression->{identifier}\"] . '";
		# return $self->flush_accumulator, "\$text .= " . $self->compile_value_expression($expression) . ";\n";

	} else {
		die "unknown expression: $expression->{type}";
	}
}

sub compile_value_expression {
	my ($self, $expression) = @_;

	if ($expression->{type} eq 'string_expression') {
		return "\"$expression->{string}\""
		
	} elsif ($expression->{type} eq 'variable_expression') {
		# $self->{text_accumulator} .= "' . \$args[\"$expression->{identifier}\"] . '";
		if ($expression->{identifier} eq '_site_base') {
			return "\$this->get_site_base()";
		} elsif (exists $self->{local_variable_scope}{$expression->{identifier}}) {
			return "\$$expression->{identifier}";
		} else {
			return "\$args[\"$expression->{identifier}\"]";
		}

	} elsif ($expression->{type} eq 'access_expression') {
		my $sub_expression = $self->compile_value_expression($expression->{expression});
		# $self->{text_accumulator} .= "' . \$args[\"$expression->{identifier}\"] . '";
		return "$sub_expression->$expression->{identifier}";

	} else {
		die "unknown expression: $expression->{type}";
	}
}

sub compile_file {
	my ($file) = @_;
	use Sugar::IO::File;
	use PaleWhite::GlassParser;

	my $parser = PaleWhite::GlassParser->new;
	$parser->{filepath} = Sugar::IO::File->new($file);
	my $tree = $parser->parse;
	# say Dumper $tree;

	my $compiler = __PACKAGE__->new;
	my $text = $compiler->compile($tree);
	return $text;
}





sub main {
	foreach my $file (@_) {
		say compile_file($file);
	}
}

caller or main(@ARGV);
