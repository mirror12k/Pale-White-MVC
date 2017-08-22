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

	public function render_template ($template_class, array $args) {
		$template = new $template_class();
		return $template->render($args);
	}

	public function get_site_base() {
		global $config;
		return $config['site_base'];
	}

	public function get_localized_string($localization_namespace, $field) {
		global $runtime;
		$current_localization = (string)$runtime['current_localization'];
		if ($current_localization === '')
			throw new \PaleWhite\InvalidException("no current localization set!");

		$class = "\\Localization\\$current_localization\\$localization_namespace";
		if (!class_exists($class))
			throw new \PaleWhite\InvalidException("no localization definition found for $localization_namespace:$current_localization");

		return $class::$$field;
	}

	public function get_csrf_token() {
		return $_SESSION['pale_white_csrf_token'];
	}
}


