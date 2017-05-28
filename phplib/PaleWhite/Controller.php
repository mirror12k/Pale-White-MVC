<?php

namespace PaleWhite;

abstract class Controller {

	public function route (string $path, array $args) {}
	public function validate (string $type, $value) {
		return $value;
	}
}


