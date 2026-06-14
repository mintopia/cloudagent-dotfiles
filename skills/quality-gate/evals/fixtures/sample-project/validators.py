"""Input validation helpers."""

import re


def validate_email(email):
    pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
    if re.match(pattern, email):
        return True
    return False


def validate_username(username):
    """Username must be 3-20 chars, alphanumeric and underscores only."""
    if len(username) < 3 or len(username) > 20:
        return False
    # BUG: regex is wrong, allows hyphens which it shouldn't
    if re.match(r'^[a-zA-Z0-9_-]+$', username):
        return True
    return False


def validate_age(age):
    """Age must be a positive integer between 0 and 150."""
    if not isinstance(age, int):
        return False
    if age < 0 or age > 150:
        return False
    return True
