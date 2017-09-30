<?php

namespace PaleWhite;

abstract class Controller {

	public function route (Request $req, Response $res) {}
	public function route_ajax (Request $req, Response $res) {}
	public function route_api (Request $req, Response $res) {}

	public function route_event ($event, array $args) {
		throw new \PaleWhite\InvalidException("undefined event requested: '$event'");
	}
	
	public function validate ($type, $value) {
		throw new \PaleWhite\InvalidException("undefined validator requested: '$type'");
	}

	public function action ($action, array $args) {
		throw new \PaleWhite\InvalidException("undefined action requested: '$action'");
	}
}


