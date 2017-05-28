#!/usr/bin/env perl
package PaleWhite::ControllerPHPCompiler;
use strict;
use warnings;

use feature 'say';

use Data::Dumper;



sub new {
	my ($class, %args) = @_;
	my $self = bless {}, $class;

	return $self
}



sub compile {
	my ($self, $tree) = @_;

	my $code = "<?php\n\n";
	$code .= join '', $self->compile_controller($_) foreach @$tree;

	return $code
}

sub map_class_name {
	my ($self, $classname) = @_;

	return "/$classname" =~ s/\//\\/gr;
}

sub compile_controller {
	my ($self, $controller) = @_;
	die "invalid controller: $controller->{type}" unless $controller->{type} eq 'controller_definition';

	my $identifier = $controller->{identifier};
	my @code;

	my $parent = 'PaleWhite/Controller'; # $template->{arguments}[2] // 
	$parent = $self->map_class_name($parent);

	push @code, $self->compile_controller_route($controller);
	
	@code = map "\t$_", @code;
	@code = ("class $identifier extends $parent {\n", @code, "}\n", "\n");

	return @code
}

sub compile_controller_route {
	my ($self, $controller) = @_;
	my @code;

	my @paths;
	if (exists $controller->{paths}) {
		@paths = @{$controller->{paths}};
	}
	return @code unless @paths;

	push @code, "parent::route(\$path, \$args);\n";
	# push @code, "\n";
	foreach my $path (@paths) {
		push @code, $self->compile_path($path);
	}

	# push @code, "return \$text;\n";

	@code = map "\t$_", @code;
	@code = ("public function route (string \$path, array \$args) {\n", @code, "}\n", "\n");

	return @code
}

sub compile_path {
	my ($self, $path) = @_;
	my @code;

	if (@{$path->{arguments}}) {
		foreach my $arg (@{$path->{arguments}}) {
			push @code, "if (!isset(\$args['$arg']))\n";
			push @code, "\tthrow new \\Exception('missing argument \"$arg\" to path \"$path->{path}\"');\n";
		}
		foreach my $arg (@{$path->{arguments}}) {
			push @code, "\$$arg = \$args['$arg'];\n";
		}
		push @code, "\n";
	}

	push @code, map $self->compile_action($_), @{$path->{block}};

	@code = map "\t$_", @code;
	@code = ("if (\$path === '$path->{path}') {\n", @code, "}\n", "\n");

	return @code
}

# sub compile_template_render_block {
# 	my ($self, $template) = @_;
# 	my @code;

# 	my %blocks;
# 	if (exists $template->{block}) {
# 		foreach my $item (grep { $_->{type} eq 'glass_helper' and $_->{identifier} eq 'block' } @{$template->{block}}) {
# 			$blocks{$item->{arguments}[0]} = $item;
# 		}
# 	}

# 	return @code unless keys %blocks;

# 	push @code, "\$text = parent::render_block(\$block, \$args);\n";
# 	push @code, "\n";

# 	foreach my $block (sort keys %blocks) {
# 		my @block_code = $self->compile_block($blocks{$block}{block});
# 		push @block_code, $self->flush_accumulator;

# 		push @code, "if (\$block === '$block') {\n";
# 		push @code, map "\t$_", @block_code;
# 		push @code, "}\n";
# 	}

# 	push @code, "\n";
# 	push @code, "return \$text;\n";

# 	@code = map "\t$_", @code;
# 	@code = ("public function render_block (string \$block, array \$args) {\n", @code, "}\n", "\n");

# 	return @code
# }

# sub compile_block {
# 	my ($self, $block) = @_;

# 	my @code;
# 	foreach my $item (@$block) {
# 		push @code, $self->compile_item($item);
# 	}

# 	return @code
# }

sub compile_action {
	my ($self, $action) = @_;

	if ($action->{type} eq 'render_template') {
		my $arguments = $self->compile_arguments_array($action->{arguments});
		return "echo ((new $action->{identifier}())->render($arguments));\n"
	# } elsif ($item->{type} eq 'glass_helper' and $item->{identifier} eq 'block') {
	# 	return $self->flush_accumulator, "\$text .= \$this->render_block('$item->{arguments}[0]', \$args);\n"
	# } elsif ($item->{type} eq 'expression_node') {
	# 	return $self->compile_argument_expression($item->{expression}), map $self->compile_argument_expression($_), @{$item->{text}}
	} else {
		die "invalid action: $action->{type}";
	}
}

sub compile_arguments_array {
	my ($self, $arguments) = @_;


	my @expressions;
	foreach my $key (sort keys %$arguments) {
		push @expressions, "'$key' => " . $self->compile_expression($arguments->{$key});
	}

	return 'array(' . join (', ', @expressions) . ')'
}

# sub compile_html_tag {
# 	my ($self, $tag) = @_;
# 	my @code;

# 	my $identifier = $tag->{identifier} // 'div';

# 	$self->{text_accumulator} .= "<$identifier";
# 	$self->{text_accumulator} .= " id=\"$tag->{id}\"" if exists $tag->{id};
# 	$self->{text_accumulator} .= ' class="' . join (' ', @{$tag->{class}}) . '"' if exists $tag->{class};

# 	if (exists $tag->{attributes}) {
# 		foreach my $key (sort keys %{$tag->{attributes}}) {
# 			$self->{text_accumulator} .= " $key=\"";
# 			push @code, $self->compile_argument_expression($tag->{attributes}{$key});
# 			$self->{text_accumulator} .= "\"";

# 		}
# 	}
# 	$self->{text_accumulator} .= ">";
# 	# push @fields, map "$_=" . $self->compile_html_attribute($tag->{attributes}{$_}), keys %{$tag->{attributes}} if exists $tag->{attributes};

# 	# my $start_tag = '<' . join (' ', @fields) . '>';
# 	# $self->{text_accumulator} .= $start_tag;

# 	push @code, map $self->compile_argument_expression($_), @{$tag->{text}} if exists $tag->{text};

# 	push @code, $self->compile_block($tag->{block}) if exists $tag->{block};

# 	# my $end_tag = "</$identifier>";
# 	$self->{text_accumulator} .= "</$identifier>";

# 	return @code
# }

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

# sub compile_argument_expression {
# 	my ($self, $expression) = @_;

# 	if ($expression->{type} eq 'string_expression') {
# 		$self->{text_accumulator} .= $expression->{string};
# 		return
		
# 	} elsif ($expression->{type} eq 'variable_expression') {
# 		# $self->{text_accumulator} .= "' . \$args[\"$expression->{identifier}\"] . '";
# 		# return $self->flush_accumulator, "\$text .= \$args[\"$expression->{identifier}\"];\n";
# 		return $self->flush_accumulator, "\$text .= " . $self->compile_value_expression($expression) . ";\n";

# 	} elsif ($expression->{type} eq 'access_expression') {
# 		# $self->{text_accumulator} .= "' . \$args[\"$expression->{identifier}\"] . '";
# 		return $self->flush_accumulator, "\$text .= " . $self->compile_value_expression($expression) . ";\n";

# 	} elsif ($expression->{type} eq 'interpolation_expression') {
# 		return map $self->compile_argument_expression($_), @{$expression->{expressions}}
# 		# $self->{text_accumulator} .= "' . \$args[\"$expression->{identifier}\"] . '";
# 		# return $self->flush_accumulator, "\$text .= " . $self->compile_value_expression($expression) . ";\n";

# 	} else {
# 		die "unknown expression: $expression->{type}";
# 	}
# }

sub compile_expression {
	my ($self, $expression) = @_;

	if ($expression->{type} eq 'string_expression') {
		return "\"$expression->{string}\""
		
	} elsif ($expression->{type} eq 'variable_expression') {
		# $self->{text_accumulator} .= "' . \$args[\"$expression->{identifier}\"] . '";
		return "\$$expression->{identifier}";

	} elsif ($expression->{type} eq 'access_expression') {
		my $sub_expression = $self->compile_expression($expression->{expression});
		# $self->{text_accumulator} .= "' . \$args[\"$expression->{identifier}\"] . '";
		return "$sub_expression->$expression->{identifier}";

	} else {
		die "unknown expression: $expression->{type}";
	}
}





sub main {
	use Data::Dumper;
	use Sugar::IO::File;
	use PaleWhite::ControllerParser;

	my $parser = PaleWhite::ControllerParser->new;
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
