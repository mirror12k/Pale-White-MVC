<?php

namespace PaleWhite;

abstract class Controller {

	public function route (string $path, array $args) {}
	
	public function validate (string $type, $value) {
		throw new \Exception("undefined validator requested: '$type'");
	}

	public function action (string $action, array $args) {
		throw new \Exception("undefined action requested: '$action'");
	}
}


