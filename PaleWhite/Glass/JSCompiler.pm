#!/usr/bin/env perl
package PaleWhite::Glass::JSCompiler;
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



sub format_classname {
	my ($self, $classname) = @_;
	return $classname =~ s/::/\./gr
}

sub flush_accumulator {
	my ($self) = @_;

	my @code;
	if (length $self->{text_accumulator} > 0) {
		my $text = $self->{text_accumulator} =~ s/([\\'])/\\$1/gr;
		push @code, "text += '$text';\n";
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

	$self->{current_template} = $template;

	die "invalid template: $template->{type}:$template->{identifier}"
			unless $template->{type} eq 'glass_helper' and $template->{identifier} eq 'template';

	my @code;

	my $class_name = $self->format_classname($template->{argument});
	my $parent = $self->format_classname($template->{parent_template} // 'PaleWhite::Glass::Template');

	# my $view_controller = $template->{view_controller};
	# $view_controller = $self->format_classname($view_controller) if defined $view_controller;
	# if (defined $view_controller) {
	# 	push @code, "private \$view_controller;\n";
	# }
	# push @code, "private \$closured_args;\n\n";

	push @code, $self->compile_template_render($template);
	push @code, $self->compile_template_render_block($template);
	
	# @code = map "\t$_", @code;
	@code = (
		"function $class_name() {}\n",
		"$class_name.prototype = Object.create($parent.prototype);\n",
		@code,
		"\n"
	);

	return @code
}

sub compile_template_render {
	my ($self, $template) = @_;
	my @code;

	my @tags;
	if (exists $template->{block}) {
		@tags = grep {
			$_->{type} ne 'glass_helper' or
			($_->{type} eq 'glass_helper' and $_->{identifier} ne 'block')
		} @{$template->{block}};
	}
	return @code unless @tags or defined $template->{view_controller};

	# push @code, "global \$runtime;\n\n";
	# if (defined $template->{view_controller}) {
	# 	my $view_controller = $self->format_classname($template->{view_controller});
	# 	push @code, "this.view_controller = \$runtime->get_view_controller('$view_controller');\n";
	# 	push @code, "\$args = (array)this.view_controller->load_args(\$args);\n";
	# }
	# push @code, "this.closured_args = \$args;\n\n";

	my $class_name = $self->format_classname($template->{argument});
	my $parent = $self->format_classname($template->{parent_template} // 'PaleWhite::Glass::Template');

	push @code, "var text = $parent.prototype.render.call(this, args);\n";

	push @code, $self->compile_block(\@tags);
	# say "debug: $self->{text_accumulator}";
	push @code, $self->flush_accumulator;
	push @code, "\n";

	push @code, "return text;\n";

	@code = map "\t$_", @code;
	@code = ("$class_name.prototype.render = function (args) {\n", @code, "};\n", "\n");

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

	# push @code, "global \$runtime;\n";
	# push @code, "\$args = this.closured_args;\n\n";

	my $class_name = $self->format_classname($template->{argument});
	my $parent = $self->format_classname($template->{parent_template} // 'PaleWhite::Glass::Template');

	push @code, "var text = $parent.prototype.render_block.call(this, block, args);\n";

	foreach my $block (sort keys %blocks) {
		my @block_code = $self->compile_block($blocks{$block}{block});
		push @block_code, $self->flush_accumulator;

		push @code, "if (block === '$block') {\n";
		push @code, map "\t$_", @block_code;
		push @code, "}\n";
	}

	push @code, "\n";
	push @code, "return text;\n";

	@code = map "\t$_", @code;
	@code = ("$class_name.prototype.render_block = function (block, args) {\n", @code, "};\n", "\n");

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
	# warn "debug here compile_block: ", $self->{text_accumulator};

	return @code
}

sub compile_item {
	my ($self, $item) = @_;

	if ($item->{type} eq 'html_tag') {
		return $self->compile_html_tag($item)
	} elsif ($item->{type} eq 'glass_helper' and $item->{identifier} eq 'block') {
		return $self->flush_accumulator, "text += this.render_block('$item->{argument}', args);\n"

	} elsif ($item->{type} eq 'glass_helper' and $item->{identifier} eq 'render') {
		my $arguments = $self->compile_arguments($item->{arguments});
		return $self->flush_accumulator, "text += PaleWhite.get_template('$item->{template}').render($arguments);\n"

	} elsif ($item->{type} eq 'glass_helper' and $item->{identifier} eq '_csrf_token_input') {
		# equivalent to 'input name="_csrf_token", type="hidden", value={_csrf_token}'
		return $self->compile_html_tag({
			identifier => 'input',
			attributes => {
				name => { type => 'string_expression', string => "_csrf_token", },
				type => { type => 'string_expression', string => "hidden", },
				value => { type => '_csrf_token_expression' },
			},
		})

	} elsif ($item->{type} eq 'glass_helper' and $item->{identifier} eq '_csrf_token_meta') {
		# equivalent to 'input name="_csrf_token", type="hidden", value={_csrf_token}'
		return $self->compile_html_tag({
			identifier => 'meta',
			id => '_csrf_token',
			attributes => {
				name => { type => 'string_expression', string => "_csrf_token", },
				content => { type => '_csrf_token_expression' },
			},
		}),
		$self->compile_html_tag({
			identifier => 'meta',
			id => '_site_base',
			attributes => {
				name => { type => 'string_expression', string => "_site_base", },
				content => { type => '_site_base_expression' },
			},
		}),

	} elsif ($item->{type} eq 'glass_helper' and $item->{identifier} eq 'doctype') {
		return $self->compile_argument_expression({
			type => 'string_expression', string => '<!doctype html>',
		}, 'html')

	} elsif ($item->{type} eq 'glass_helper' and $item->{identifier} eq 'foreach') {
		my @code;
		push @code, $self->flush_accumulator;

		if (exists $item->{key_identifier}) {
			push @code, "for (var _pair of PaleWhite.object_pairs(" .
					$self->compile_value_expression($item->{expression}) . ")) {\n";
			push @code, "\tvar $item->{key_identifier} = _pair[0];\n";
			push @code, "\tvar $item->{value_identifier} = _pair[1];\n";

		} else {
			push @code, "for (var $item->{value_identifier} of " .
					$self->compile_value_expression($item->{expression}) . ") {\n";

		}

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
		push @code, "} else if (" . $self->compile_value_expression($item->{expression}) . ") {\n";
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

	} elsif ($item->{type} eq 'raw_html_expression_node') {
		return $self->compile_argument_expression($item->{expression}, 'html')

	} elsif ($item->{type} eq 'expression_node') {
		return $self->compile_argument_expression($item->{expression}, 'text')

	} elsif ($item->{type} eq 'glass_helper') {
		die "invalid helper: $item->{identifier} on line $item->{line_number}";
		
	} else {
		die "invalid item: $item->{type} on line $item->{line_number}";
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
					push @code, $self->compile_argument_expression(
							{ type => '_site_base_expression' }, 'html_attribute');
				}
			}
			push @code, $self->compile_argument_expression($tag->{attributes}{$key}, 'html_attribute');
			$self->{text_accumulator} .= "\"";
		}
	}
	$self->{text_accumulator} .= ">";

	push @code, $self->compile_argument_expression($tag->{text_expression}, 'text') if exists $tag->{text_expression};

	push @code, $self->compile_block($tag->{block}) if exists $tag->{block};

	# my $end_tag = "</$identifier>";
	$self->{text_accumulator} .= "</$identifier>";

	return @code
}

sub compile_arguments {
	my ($self, $arguments) = @_;
	my @args;
	foreach my $key (sort keys %$arguments) {
		push @args, "'$key': " . $self->compile_value_expression($arguments->{$key});
	}
	return "{" . join(', ', @args) . "}"
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
			or $expression->{type} eq '_site_base_expression'
			or $expression->{type} eq '_csrf_token_expression'
			or $expression->{type} eq 'access_expression'
			or $expression->{type} eq 'length_expression'
			or $expression->{type} eq 'method_call_expression'
			or $expression->{type} eq 'localized_string_expression') {
		if ($context eq 'html_attribute' or $context eq 'text') {
			return $self->flush_accumulator, "text += this.htmlspecialchars(" .
				$self->compile_value_expression($expression) . ");\n";
		} else {
			return $self->flush_accumulator, "text += " . $self->compile_value_expression($expression) . ";\n";
		}

	} elsif ($expression->{type} eq 'less_than_expression'
			or $expression->{type} eq 'greater_than_expression'
			or $expression->{type} eq 'less_than_or_equal_expression'
			or $expression->{type} eq 'greater_than_or_equal_expression'
			or $expression->{type} eq 'equals_expression'
			or $expression->{type} eq 'array_expression'
			or $expression->{type} eq 'object_expression'
			or $expression->{type} eq 'native_identifier_expression'
			or $expression->{type} eq 'model_identifier_expression') {
		die "error on line $expression->{line_number}: cannot use $expression->{type} directly in html";

	} elsif ($expression->{type} eq 'interpolation_expression') {
		return map $self->compile_argument_expression($_, $context), @{$expression->{expressions}}

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

	# } elsif ($expression->{type} eq 'localized_string_expression') {
	# 	return "\$runtime->get_localized_string(\'$expression->{namespace_identifier}\', \'$expression->{identifier}\')"

	} elsif ($expression->{type} eq 'interpolation_expression') {
		return join ' + ', '""', map $self->compile_value_expression($_), @{$expression->{expressions}}
		
	} elsif ($expression->{type} eq '_site_base_expression') {
		return "PaleWhite.get_site_base()";
		
	} elsif ($expression->{type} eq '_csrf_token_expression') {
		return "PaleWhite.get_csrf_token()";

	} elsif ($expression->{type} eq 'variable_expression') {
		# $self->{text_accumulator} .= "' . \$args[\"$expression->{identifier}\"] . '";
		# if ($expression->{identifier} eq '_site_base') {
		# 	return "\$runtime->site_base";
		# } elsif ($expression->{identifier} eq '_csrf_token') {
		# 	return "\$runtime->csrf_token";
		# } els
		if ($expression->{identifier} eq '_time') {
			return "Math.floor(Date.now() / 1000)";
		} elsif ($expression->{identifier} eq 'runtime') {
			return "PaleWhite";
		} elsif (exists $self->{local_variable_scope}{$expression->{identifier}}) {
			return "$expression->{identifier}";
		} else {
			return "args.$expression->{identifier}";
		}

	} elsif ($expression->{type} eq 'access_expression') {
		my $sub_expression = $self->compile_value_expression($expression->{expression});
		# $self->{text_accumulator} .= "' . \$args[\"$expression->{identifier}\"] . '";
		return "$sub_expression.$expression->{identifier}";

	} elsif ($expression->{type} eq 'method_call_expression') {
		if ($expression->{expression}{type} eq 'native_identifier_expression'
				or $expression->{expression}{type} eq 'model_identifier_expression') {
			my $sub_expression = $self->format_classname($expression->{expression}{identifier});
			my $arguments_list = $self->compile_value_expression_list($expression->{arguments_list});
			return "$sub_expression.$expression->{identifier}($arguments_list)";
		} else {
			my $sub_expression = $self->compile_value_expression($expression->{expression});
			my $arguments_list = $self->compile_value_expression_list($expression->{arguments_list});
			# $self->{text_accumulator} .= "' . \$args[\"$expression->{identifier}\"] . '";
			return "$sub_expression.$expression->{identifier}($arguments_list)";
		}

	} elsif ($expression->{type} eq 'array_expression') {
		my $expression_list = $self->compile_value_expression_list($expression->{expression_list});
		# $self->{text_accumulator} .= "' . \$args[\"$expression->{identifier}\"] . '";
		return "[$expression_list]";

	} elsif ($expression->{type} eq 'object_expression') {
		my $object = $self->compile_arguments($expression->{object_fields});
		# $self->{text_accumulator} .= "' . \$args[\"$expression->{identifier}\"] . '";
		return "$object";

	} elsif ($expression->{type} eq 'length_expression') {
		my $sub_expression = $self->compile_value_expression($expression->{expression});
		# $self->{text_accumulator} .= "' . \$args[\"$expression->{identifier}\"] . '";
		return "$sub_expression.length";

	} elsif ($expression->{type} eq 'less_than_expression') {
		my $left_expression = $self->compile_value_expression($expression->{left_expression});
		my $right_expression = $self->compile_value_expression($expression->{right_expression});
		return "( $left_expression < $right_expression )";

	} elsif ($expression->{type} eq 'greater_than_expression') {
		my $left_expression = $self->compile_value_expression($expression->{left_expression});
		my $right_expression = $self->compile_value_expression($expression->{right_expression});
		return "( $left_expression > $right_expression )";

	} elsif ($expression->{type} eq 'less_than_or_equal_expression') {
		my $left_expression = $self->compile_value_expression($expression->{left_expression});
		my $right_expression = $self->compile_value_expression($expression->{right_expression});
		return "( $left_expression <= $right_expression )";

	} elsif ($expression->{type} eq 'greater_than_or_equal_expression') {
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
