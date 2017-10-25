<?php

namespace PaleWhite\Glass;

abstract class Template {
	public function render (array $args) {
		return '';
	}

	public function render_block ($block, array $args) {
		return '';
	}
}


