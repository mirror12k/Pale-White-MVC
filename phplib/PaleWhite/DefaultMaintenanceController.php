<?php

namespace PaleWhite;

class DefaultMaintenanceController extends \PaleWhite\Controller {
	public function route (Request $req, Response $res) {
		$res->body = "<!doctype html><html><head><title>Maintenance Mode!</title></head>"
			. "<body><h1>Website down for maintenance...</h1><p>please come back later</p></body></html>";
	}
	public function route_ajax (Request $req, Response $res) {
		$res->body = array('status' => 'error', 'error' => 'Website down for maintenance...');
	}
}


