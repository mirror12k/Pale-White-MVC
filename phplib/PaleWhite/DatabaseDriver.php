<?php

namespace PaleWhite;

class DatabaseDriver {

	public $mysql_host;
	public $mysql_username;
	public $mysql_password;
	public $mysql_database;

	public $mysql_connection;

	public $connected;

	public function __construct(array $args) {
		$this->mysql_host = $args['mysql_host'];
		$this->mysql_username = $args['mysql_username'];
		$this->mysql_password = $args['mysql_password'];
		$this->mysql_database = $args['mysql_database'];
		$this->connected = false;
	}

	public function __get($name) {
		if ($name === 'insert_id') {
			return $this->mysql_connection->insert_id;
		} elseif ($name === 'affected_rows') {
			return $this->mysql_connection->affected_rows;
		}
	}

	public function connect() {
		$this->mysql_connection = new \mysqli($this->mysql_host, $this->mysql_username, $this->mysql_password, $this->mysql_database);
		if ($this->mysql_connection->connect_error) {
			throw new \Exception('Database Connect Error: (' . $this->mysql_connection->connect_errno . ') ' . $this->mysql_connection->connect_error);
		}
		$this->connected = true;
	}

	public function select() {
		return new DatabaseQuery($this, 'select');
	}

	public function insert() {
		return new DatabaseQuery($this, 'insert');
	}

	public function update() {
		return new DatabaseQuery($this, 'update');
	}

	public function delete() {
		return new DatabaseQuery($this, 'delete');
	}

	public function escape_string($string) {
		if (!$this->connected)
			$this->connect();

		$string = str_replace("`", "``", $string);
		return $this->mysql_connection->real_escape_string($string);
	}

	public function query(DatabaseQuery $query) {
		if (!$this->connected)
			$this->connect();

		$query_string = $query->compile();
		error_log("[PaleWhite] executing mysql query: '$query_string'");
		$result = $this->mysql_connection->query($query_string);
		if ($this->mysql_connection->error) {
			throw new \Exception('Database query error: ' . $this->mysql_connection->error);
		}
		return $result;
	}
}


