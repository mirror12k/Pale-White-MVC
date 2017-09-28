<?php

namespace PaleWhite;

abstract class ViewController {
	public function load_args (array $args) {
		return $args;
	}

	public function action ($action, array $args) {
		throw new \PaleWhite\InvalidException("undefined action requested: '$action'");
	}
}


