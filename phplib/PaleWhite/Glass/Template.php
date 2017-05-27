<?php

namespace PaleWhite\Glass;

abstract class Template {
	public $_data;

	public function render (array $args) {
		return '';
	}

	public function render_block (string $block, array $args) {
		return '';
	}
}


