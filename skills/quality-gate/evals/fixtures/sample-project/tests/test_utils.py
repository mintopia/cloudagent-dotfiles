from utils import add, parse_date, calculate_total


def test_add():
    assert add(2, 3) == 5


def test_parse_date():
    result = parse_date("2024-01-15")
    assert result == {"year": 2024, "month": 1, "day": 15}


def test_parse_date_empty_string():
    """This test fails - parse_date crashes on empty strings."""
    result = parse_date("")
    assert result is None


def test_calculate_total():
    items = [{"price": 10, "quantity": 2}, {"price": 5, "quantity": 3}]
    assert calculate_total(items) == 35


def test_calculate_total_with_discount():
    """This test fails - discount should be percentage, not flat amount."""
    items = [{"price": 100, "quantity": 1}]
    assert calculate_total(items, discount=10) == 90.0
