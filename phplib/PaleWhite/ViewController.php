<?php

namespace PaleWhite;

abstract class ViewController {
	public function args_block (array $args) {
		return $args;
	}
	public function more_args_block (array $args) {
		return array();
	}

	public function load_args (array $args) {
		$args = (array)$this->args_block($args);
		$args = array_merge($args, (array)$this->more_args_block($args));
		return $args;
	}

	public function action ($action, array $args) {
		throw new \PaleWhite\InvalidException("undefined action requested: '$action'");
	}
}


