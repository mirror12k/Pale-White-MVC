<?php

namespace PaleWhite;

abstract class Plugin {
	public function on_registered() {
		global $runtime;

		foreach ($this->event_hooks as $event_id)
			$runtime->register_event_hook($event_id, array($this, 'route_event_hook'));
	}

	public function route_event_hook ($event, array $args) {
		throw new \PaleWhite\InvalidException("undefined event hook routed: '$event'");
	}
}


