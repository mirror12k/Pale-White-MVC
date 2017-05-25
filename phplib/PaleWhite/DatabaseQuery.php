<?php


namespace PaleWhite;

class DatabaseQuery {
	public function __construct(DatabaseDriver $db, string $query_type) {
		$this->db = $db;
		$this->query_type = $query_type;
		$this->query_args = array();
	}

	public function fields(array $fields) {
		$this->query_args['fields'] = $fields;
		return $this;
	}

	public function table(string $table) {
		$this->query_args['table'] = (string)$table;
		return $this;
	}

	public function values(array $args) {
		if (!isset($this->query_args['values']))
			$this->query_args['values'] = array();
		foreach ($args as $field => $value) {
			$this->query_args['values'][$field] = $value;
		}
		return $this;
	}

	public function where(array $args) {
		if (!isset($this->query_args['where']))
			$this->query_args['where'] = array();
		foreach ($args as $field => $value) {
			$this->query_args['where'][$field] = $value;
		}
		return $this;
	}

	public function limit(int $limit) {
		$this->query_args['limit'] = (int)$limit;
		return $this;
	}

	public function compile() {
		if ($this->query_type === 'select') {
			$query = 'SELECT';

			if (isset($this->query_args['fields'])) {
				$fields = array();
				foreach ($this->query_args['fields'] as $field) {
					$fields[] = '`' . $this->db->escape_string($field) . '`';
				}
			} else {
				$fields = array('*');
			}
			$query .= ' ' . implode(', ', $fields);

			if (isset($this->query_args['table'])) {
				$query .= ' FROM `' . $this->db->escape_string($this->query_args['table']) . '`';
			}

			if (isset($this->query_args['where'])) {
				$fields = array();
				foreach ($this->query_args['where'] as $field => $value) {
					$field = '`' . $this->db->escape_string($field) . '`';
					if (is_string($value)) {
						$value = '\'' . $this->db->escape_string($value) . '\'';
					} elseif (is_numeric($value)) {
						$value = "$value";
					} else {
						die("invalid value type for where field $field: " . gettype($value));
					}
					$fields[] = "$field = $value";
				}

				$query .= ' WHERE ' . implode(' AND ', $fields);
			}

			if (isset($this->query_args['limit'])) {
				$query .= ' LIMIT ' . $this->query_args['limit'];
			}

			return $query;

		} elseif ($this->query_type === 'insert') {
			$query = 'INSERT';

			if (isset($this->query_args['table'])) {
				$query .= ' INTO `' . $this->db->escape_string($this->query_args['table']) . '`';
			}

			if (isset($this->query_args['values'])) {
				$fields = array();
				foreach ($this->query_args['values'] as $field => $value) {
					$fields[] = '`' . $this->db->escape_string($field) . '`';
				}
				$query .= ' (' . implode(', ', $fields) . ')';

				$values = array();
				foreach ($this->query_args['values'] as $field => $value) {
					if (is_string($value)) {
						$value = '\'' . $this->db->escape_string($value) . '\'';
					} elseif (is_numeric($value)) {
						$value = "$value";
					} else {
						die("invalid value type for where field $field: " . gettype($value));
					}
					$values[] = $value;
				}
				$query .= ' VALUES (' . implode(', ', $values) . ')';
			}

			return $query;

		} elseif ($this->query_type === 'update') {
			$query = 'UPDATE';

			if (isset($this->query_args['table'])) {
				$query .= ' `' . $this->db->escape_string($this->query_args['table']) . '`';
			}

			if (isset($this->query_args['values'])) {
				$values = array();
				foreach ($this->query_args['values'] as $field => $value) {
					$field = '`' . $this->db->escape_string($field) . '`';
					if (is_string($value)) {
						$value = '\'' . $this->db->escape_string($value) . '\'';
					} elseif (is_numeric($value)) {
						$value = "$value";
					} else {
						die("invalid value type for where field $field: " . gettype($value));
					}
					$values[] = "$field = $value";
				}
				$query .= ' SET ' . implode(', ', $values);
			}

			if (isset($this->query_args['where'])) {
				$fields = array();
				foreach ($this->query_args['where'] as $field => $value) {
					$field = '`' . $this->db->escape_string($field) . '`';
					if (is_string($value)) {
						$value = '\'' . $this->db->escape_string($value) . '\'';
					} elseif (is_numeric($value)) {
						$value = "$value";
					} else {
						die("invalid value type for where field $field: " . gettype($value));
					}
					$fields[] = "$field = $value";
				}

				$query .= ' WHERE ' . implode(' AND ', $fields);
			}

			if (isset($this->query_args['limit'])) {
				$query .= ' LIMIT ' . $this->query_args['limit'];
			}

			return $query;

		} else {
			die("invalid query_type: " . $this->query_type);
		}
	}

	public function fetch() {
		$result = $this->db->query($this);

		if ($this->query_type === 'select') {
			$data = array();
			for ($i = 0; $i < $result->num_rows; $i++) {
				$data[] = $result->fetch_assoc();
			}
		} else {
			$data = $result;
		}
		return $data;
	}
}

