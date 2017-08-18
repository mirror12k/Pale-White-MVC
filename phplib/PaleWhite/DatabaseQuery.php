<?php


namespace PaleWhite;

class DatabaseQuery {
	public function __construct(DatabaseDriver $db, $query_type) {
		$this->db = $db;
		$this->query_type = $query_type;
		$this->query_args = array();
	}

	public function fields(array $fields) {
		$this->query_args['fields'] = $fields;
		return $this;
	}

	public function table($table) {
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

	public function limit($limit) {
		$this->query_args['limit'] = (int)$limit;
		return $this;
	}

	public function offset($offset) {
		$this->query_args['offset'] = (int)$offset;
		return $this;
	}

	public function order($order) {
		$order = (string)$order;

		if ($order === 'ascending' || $order === 'descending')
			$this->query_args['order'] = $order;
		else
			throw new \PaleWhite\InvalidException('invalid row order: "$order"');

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
				$query .= ' ' . $this->compile_where_clause($this->query_args['where']);
			}

			if (isset($this->query_args['order'])) {
				if ($this->query_args['order'] === 'ascending')
					$query .= ' ORDER BY id ASC';
				else
					$query .= ' ORDER BY id DESC';
			}

			if (isset($this->query_args['limit'])) {
				if (isset($this->query_args['offset']))
					$query .= ' LIMIT ' . $this->query_args['offset'] . ',' . $this->query_args['limit'];
				else
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
						throw new \PaleWhite\InvalidException("invalid value type for where field $field: " . gettype($value));
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
						throw new \PaleWhite\InvalidException("invalid value type for where field $field: " . gettype($value));
					}
					$values[] = "$field = $value";
				}
				$query .= ' SET ' . implode(', ', $values);
			}

			if (isset($this->query_args['where'])) {
				$query .= ' ' . $this->compile_where_clause($this->query_args['where']);
			}

			if (isset($this->query_args['order'])) {
				if ($this->query_args['order'] === 'ascending')
					$query .= ' ORDER BY id ASC';
				else
					$query .= ' ORDER BY id DESC';
			}

			if (isset($this->query_args['limit'])) {
				if (isset($this->query_args['offset']))
					$query .= ' LIMIT ' . $this->query_args['offset'] . ',' . $this->query_args['limit'];
				else
					$query .= ' LIMIT ' . $this->query_args['limit'];
			}

			return $query;
		} elseif ($this->query_type === 'delete') {
			$query = 'DELETE';


			if (isset($this->query_args['table'])) {
				$query .= ' FROM `' . $this->db->escape_string($this->query_args['table']) . '`';
			}

			if (isset($this->query_args['where'])) {
				$query .= ' ' . $this->compile_where_clause($this->query_args['where']);
			}

			if (isset($this->query_args['order'])) {
				if ($this->query_args['order'] === 'ascending')
					$query .= ' ORDER BY id ASC';
				else
					$query .= ' ORDER BY id DESC';
			}

			if (isset($this->query_args['limit'])) {
				if (isset($this->query_args['offset']))
					$query .= ' LIMIT ' . $this->query_args['offset'] . ',' . $this->query_args['limit'];
				else
					$query .= ' LIMIT ' . $this->query_args['limit'];
			}

			return $query;

		} else {
			throw new \PaleWhite\InvalidException("invalid query_type: " . $this->query_type);
		}
	}

	public function compile_where_clause($where_clause)
	{
		$fields = array();
		foreach ($where_clause as $field => $value) {
			$field = '`' . $this->db->escape_string($field) . '`';
			if (is_array($value)) {
				$escaped_values = array();
				foreach ($value as $subvalue) {
					if (is_string($subvalue)) {
						$escaped_values[] = '\'' . $this->db->escape_string($subvalue) . '\'';
					} elseif (is_numeric($subvalue)) {
						$escaped_values[] = "$subvalue";
					} else {
						throw new \PaleWhite\InvalidException("invalid value type for where field $field: " . gettype($value));
					}
				}
				if (count($escaped_values) < 1)
					throw new \PaleWhite\InvalidException("empty value list for where field $field!");

				$escaped_values = implode(",", $escaped_values);
				$fields[] = "$field IN ($escaped_values)";
			} else {
				if (is_string($value)) {
					$value = '\'' . $this->db->escape_string($value) . '\'';
				} elseif (is_numeric($value)) {
					$value = "$value";
				} else {
					throw new \PaleWhite\InvalidException("invalid value type for where field $field: " . gettype($value));
				}
				$fields[] = "$field = $value";
			}
		}

		if (count($fields) > 0)
			return 'WHERE ' . implode(' AND ', $fields);
		else
			return '';
	}

	public function fetch() {
		$result = $this->db->query($this);

		if ($this->query_type === 'select') {
			$data = array();
			for ($i = 0; $i < $result->num_rows; $i++) {
				$data[] = $result->fetch_assoc();
			}
			$result->free();
		} else {
			$data = $result;
		}
		return $data;
	}
}

