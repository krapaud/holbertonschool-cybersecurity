#!/usr/bin/env python3
"""Tests for the main BreachCheck functions."""

import unittest

from breach_check import check_policy, load_config
from utils import hash_password, validate_line


class TestBreachCheck(unittest.TestCase):
    """Test the main checks used by BreachCheck."""

    @classmethod
    def setUpClass(cls):
        load_config()

    def test_validate_line_with_valid_data(self):
        self.assertTrue(validate_line("user@example.com:password123"))

    def test_validate_line_with_invalid_format(self):
        self.assertFalse(validate_line("user@example.com;password123"))

    def test_validate_line_with_missing_part(self):
        self.assertFalse(validate_line("user@example.com:"))
        self.assertFalse(validate_line("password123"))

    def test_check_policy_with_short_password(self):
        self.assertEqual(check_policy("short"), "WEAK")

    def test_check_policy_with_numeric_password(self):
        self.assertEqual(check_policy("123456"), "WEAK")

    def test_check_policy_with_compliant_password(self):
        self.assertEqual(check_policy("safe1234!"), "COMPLIANT")

    def test_hash_password_is_repeatable(self):
        first_hash = hash_password("password123", "salt")
        second_hash = hash_password("password123", "salt")
        self.assertEqual(first_hash, second_hash)


if __name__ == "__main__":
    unittest.main()
