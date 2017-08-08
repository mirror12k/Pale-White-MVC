<?php

namespace PaleWhite\Glass;

abstract class Template {
	public $_data;

	public function render (array $args) {
		return '';
	}

	public function render_block ($block, array $args) {
		return '';
	}

	public function get_site_base() {
		global $config;
		return $config['site_base'];
	}

	public function get_csrf_token() {
		return $_SESSION['pale_white_csrf_token'];
	}
}


