from validators import validate_email, validate_username, validate_age


def test_valid_email():
    assert validate_email("user@example.com") is True


def test_invalid_email():
    assert validate_email("not-an-email") is False


def test_valid_username():
    assert validate_username("alice_123") is True


def test_username_with_hyphen_should_fail():
    """This test fails - validate_username incorrectly allows hyphens."""
    assert validate_username("alice-bob") is False


def test_username_too_short():
    assert validate_username("ab") is False


def test_valid_age():
    assert validate_age(25) is True


def test_negative_age():
    assert validate_age(-1) is False
