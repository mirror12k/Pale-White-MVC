#!/usr/bin/env perl
package PaleWhite::Glass::PHPCompiler;
use strict;
use warnings;

use feature 'say';

use Data::Dumper;

use HTML::Entities;



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
	die "invalid template: $template->{type}:$template->{identifier}"
			unless $template->{type} eq 'glass_helper' and $template->{identifier} eq 'template';

	my $identifier = $template->{argument};
	my @code;

	my $parent = $template->{parent_template} // 'PaleWhite/Glass/Template';
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
		@tags = grep {
			$_->{type} eq 'html_tag'
			or ($_->{type} eq 'glass_helper' and $_->{identifier} ne 'block')
		} @{$template->{block}};
	}
	return @code unless @tags;

	push @code, "\$text = parent::render(\$args);\n";
	push @code, "\n";
	push @code, $self->compile_block(\@tags);
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
			$blocks{$item->{argument}} = $item;
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
	my $prev;
	foreach my $item (@$block) {
		if ($item->{type} eq 'glass_helper' and $item->{identifier} eq 'elseif') {
			die "elseif block without previous if"
				unless defined $prev and $prev->{type} eq 'glass_helper'
					and ($prev->{identifier} eq 'elseif' or $prev->{identifier} eq 'if');

			pop @code; # remove closing bracket to format better
		}
		if ($item->{type} eq 'glass_helper' and $item->{identifier} eq 'else') {
			die "else block without previous if"
				unless defined $prev and $prev->{type} eq 'glass_helper'
					and ($prev->{identifier} eq 'elseif' or $prev->{identifier} eq 'if');

			pop @code; # remove closing bracket to format better
		}
		push @code, $self->compile_item($item);
		$prev = $item;
	}

	return @code
}

sub compile_item {
	my ($self, $item) = @_;

	if ($item->{type} eq 'html_tag') {
		return $self->compile_html_tag($item)
	} elsif ($item->{type} eq 'glass_helper' and $item->{identifier} eq 'block') {
		return $self->flush_accumulator, "\$text .= \$this->render_block('$item->{argument}', \$args);\n"

	} elsif ($item->{type} eq 'glass_helper' and $item->{identifier} eq 'template_call') {
		my $arguments = $self->compile_arguments($item->{arguments});
		return $self->flush_accumulator, "\$text .= \$this->render_template('$item->{template}', $arguments);\n"

	} elsif ($item->{type} eq 'glass_helper' and $item->{identifier} eq '_csrf_token_input') {
		# equivalent to 'input name="_csrf_token", type="hidden", value={_csrf_token}'
		return $self->compile_html_tag({
			identifier => 'input',
			attributes => {
				name => { type => 'string_expression', string => "_csrf_token", },
				type => { type => 'string_expression', string => "hidden", },
				value => { type => 'variable_expression', identifier => "_csrf_token", },
			},
		})

	} elsif ($item->{type} eq 'glass_helper' and $item->{identifier} eq '_csrf_token_meta') {
		# equivalent to 'input name="_csrf_token", type="hidden", value={_csrf_token}'
		return $self->compile_html_tag({
			identifier => 'meta',
			id => '_csrf_token',
			attributes => {
				name => { type => 'string_expression', string => "_csrf_token", },
				content => { type => 'variable_expression', identifier => "_csrf_token", },
			},
		})

	} elsif ($item->{type} eq 'glass_helper' and $item->{identifier} eq 'foreach') {
		my @code;
		push @code, $self->flush_accumulator;
		push @code, "foreach (" . $self->compile_value_expression($item->{expression}) . " as " . (
					exists $item->{key_identifier}
						? "\$$item->{key_identifier} => \$$item->{value_identifier}"
						: "\$$item->{value_identifier}"
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

	} elsif ($item->{type} eq 'glass_helper' and $item->{identifier} eq 'if') {
		my @code;
		push @code, $self->flush_accumulator;
		push @code, "if (" . $self->compile_value_expression($item->{expression}) . ") {\n";
		my $prev_scope = $self->{local_variable_scope};
		$self->{local_variable_scope} = { %$prev_scope };
		push @code, map "\t$_", $self->compile_block($item->{block});
		push @code, map "\t$_", $self->flush_accumulator;
		$self->{local_variable_scope} = $prev_scope;
		push @code, "}\n";
		return @code

	} elsif ($item->{type} eq 'glass_helper' and $item->{identifier} eq 'elseif') {
		my @code;
		push @code, $self->flush_accumulator;
		push @code, "} elseif (" . $self->compile_value_expression($item->{expression}) . ") {\n";
		my $prev_scope = $self->{local_variable_scope};
		$self->{local_variable_scope} = { %$prev_scope };
		push @code, map "\t$_", $self->compile_block($item->{block});
		push @code, map "\t$_", $self->flush_accumulator;
		$self->{local_variable_scope} = $prev_scope;
		push @code, "}\n";
		return @code

	} elsif ($item->{type} eq 'glass_helper' and $item->{identifier} eq 'else') {
		my @code;
		push @code, $self->flush_accumulator;
		push @code, "} else {\n";
		my $prev_scope = $self->{local_variable_scope};
		$self->{local_variable_scope} = { %$prev_scope };
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
			if (
					(
						($identifier eq 'a' and $key eq 'href')
						or ($identifier eq 'link' and $key eq 'href')
						or ($identifier eq 'script' and $key eq 'src')
						or ($identifier eq 'form' and $key eq 'action')
					) and ($tag->{attributes}{$key}{type} eq 'string_expression' or
						$tag->{attributes}{$key}{type} eq 'interpolation_expression')) {
				my $expression = $tag->{attributes}{$key};
				$expression = $expression->{expressions}[0] if $expression->{type} eq 'interpolation_expression';

				if ($expression->{string} =~ /\A\//) {
					push @code, $self->compile_argument_expression({ type => 'variable_expression', identifier => '_site_base' });
				}
			}
			push @code, $self->compile_argument_expression($tag->{attributes}{$key}, 'html_attribute');
			$self->{text_accumulator} .= "\"";
		}
	}
	$self->{text_accumulator} .= ">";
	# push @fields, map "$_=" . $self->compile_html_attribute($tag->{attributes}{$_}), keys %{$tag->{attributes}}
	# 	if exists $tag->{attributes};

	# my $start_tag = '<' . join (' ', @fields) . '>';
	# $self->{text_accumulator} .= $start_tag;

	push @code, $self->compile_argument_expression($tag->{text_expression}, 'text') if exists $tag->{text_expression};

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

sub compile_arguments {
	my ($self, $arguments) = @_;
	my @args;
	foreach my $key (sort keys %$arguments) {
		push @args, "'$key' => " . $self->compile_value_expression($arguments->{$key});
	}
	return "array(" . join(', ', @args) . ")"
}

sub compile_argument_expression {
	my ($self, $expression, $context) = @_;
	$context //= 'none';

	if ($expression->{type} eq 'integer_expression') {
		$self->{text_accumulator} .= "$expression->{value}";
		return

	} elsif ($expression->{type} eq 'string_expression') {
		if ($context eq 'html_attribute' or $context eq 'text') {
			$self->{text_accumulator} .= encode_entities($expression->{string}, '<>&"\'');
		} else {
			$self->{text_accumulator} .= $expression->{string};
		}
		return
		
	} elsif ($expression->{type} eq 'variable_expression'
			or $expression->{type} eq 'access_expression'
			or $expression->{type} eq 'length_expression'
			or $expression->{type} eq 'method_call_expression') {
		if ($context eq 'html_attribute' or $context eq 'text') {
			return $self->flush_accumulator, "\$text .= htmlspecialchars(" . $self->compile_value_expression($expression) . ");\n";
		} else {
			return $self->flush_accumulator, "\$text .= " . $self->compile_value_expression($expression) . ";\n";
		}

	} elsif ($expression->{type} eq 'less_than_expression'
			or $expression->{type} eq 'greather_than_expression'
			or $expression->{type} eq 'less_than_or_equal_expression'
			or $expression->{type} eq 'greather_than_or_equal_expression'
			or $expression->{type} eq 'equals_expression'
			or $expression->{type} eq 'array_expression'
			or $expression->{type} eq 'object_expression') {
		die "error on line $expression->{line_number}: cannot use $expression->{type} directly in html";

	} elsif ($expression->{type} eq 'interpolation_expression') {
		return map $self->compile_argument_expression($_, $context), @{$expression->{expressions}}
		# $self->{text_accumulator} .= "' . \$args[\"$expression->{identifier}\"] . '";
		# return $self->flush_accumulator, "\$text .= " . $self->compile_value_expression($expression) . ";\n";

	} else {
		die "unknown expression: $expression->{type}";
	}
}

sub compile_value_expression_list {
	my ($self, $expression_list) = @_;
	return join ', ', map $self->compile_value_expression($_), @$expression_list
}

sub compile_value_expression {
	my ($self, $expression) = @_;

	if ($expression->{type} eq 'integer_expression') {
		return "$expression->{value}"

	} elsif ($expression->{type} eq 'string_expression') {
		return "\"$expression->{string}\""

	} elsif ($expression->{type} eq 'interpolation_expression') {
		return join ' . ', map $self->compile_value_expression($_), @{$expression->{expressions}}
		
	} elsif ($expression->{type} eq 'variable_expression') {
		# $self->{text_accumulator} .= "' . \$args[\"$expression->{identifier}\"] . '";
		if ($expression->{identifier} eq '_site_base') {
			return "\$this->get_site_base()";
		} elsif ($expression->{identifier} eq '_csrf_token') {
			return "\$this->get_csrf_token()";
		} elsif (exists $self->{local_variable_scope}{$expression->{identifier}}) {
			return "\$$expression->{identifier}";
		} else {
			return "\$args[\"$expression->{identifier}\"]";
		}

	} elsif ($expression->{type} eq 'access_expression') {
		my $sub_expression = $self->compile_value_expression($expression->{expression});
		# $self->{text_accumulator} .= "' . \$args[\"$expression->{identifier}\"] . '";
		return "$sub_expression->$expression->{identifier}";

	} elsif ($expression->{type} eq 'method_call_expression') {
		my $sub_expression = $self->compile_value_expression($expression->{expression});
		my $arguments_list = $self->compile_value_expression_list($expression->{arguments_list});
		# $self->{text_accumulator} .= "' . \$args[\"$expression->{identifier}\"] . '";
		return "$sub_expression->$expression->{identifier}($arguments_list)";

	} elsif ($expression->{type} eq 'array_expression') {
		my $expression_list = $self->compile_value_expression_list($expression->{expression_list});
		# $self->{text_accumulator} .= "' . \$args[\"$expression->{identifier}\"] . '";
		return "array($expression_list)";

	} elsif ($expression->{type} eq 'object_expression') {
		my $object = $self->compile_arguments($expression->{object_fields});
		# $self->{text_accumulator} .= "' . \$args[\"$expression->{identifier}\"] . '";
		return "(object)$object";

	} elsif ($expression->{type} eq 'length_expression') {
		my $sub_expression = $self->compile_value_expression($expression->{expression});
		# $self->{text_accumulator} .= "' . \$args[\"$expression->{identifier}\"] . '";
		return "count($sub_expression)";

	} elsif ($expression->{type} eq 'less_than_expression') {
		my $left_expression = $self->compile_value_expression($expression->{left_expression});
		my $right_expression = $self->compile_value_expression($expression->{right_expression});
		return "( $left_expression < $right_expression )";

	} elsif ($expression->{type} eq 'greather_than_expression') {
		my $left_expression = $self->compile_value_expression($expression->{left_expression});
		my $right_expression = $self->compile_value_expression($expression->{right_expression});
		return "( $left_expression > $right_expression )";

	} elsif ($expression->{type} eq 'less_than_or_equal_expression') {
		my $left_expression = $self->compile_value_expression($expression->{left_expression});
		my $right_expression = $self->compile_value_expression($expression->{right_expression});
		return "( $left_expression <= $right_expression )";

	} elsif ($expression->{type} eq 'greather_than_or_equal_expression') {
		my $left_expression = $self->compile_value_expression($expression->{left_expression});
		my $right_expression = $self->compile_value_expression($expression->{right_expression});
		return "( $left_expression >= $right_expression )";

	} elsif ($expression->{type} eq 'equals_expression') {
		my $left_expression = $self->compile_value_expression($expression->{left_expression});
		my $right_expression = $self->compile_value_expression($expression->{right_expression});
		return "( $left_expression === $right_expression )";

	} else {
		die "unknown expression: $expression->{type}";
	}
}

sub compile_file {
	my ($file) = @_;
	use Sugar::IO::File;
	use PaleWhite::Glass::Parser;

	my $parser = PaleWhite::Glass::Parser->new;
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
