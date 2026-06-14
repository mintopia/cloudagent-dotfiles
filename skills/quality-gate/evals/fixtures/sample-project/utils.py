"""Utility functions for the sample project."""


def add(a, b):
    return a + b


def parse_date(date_str):
    """Parse a date string in YYYY-MM-DD format."""
    parts = date_str.split("-")
    return {"year": int(parts[0]), "month": int(parts[1]), "day": int(parts[2])}


def calculate_total(items, discount=0):
    """Calculate total price of items with optional discount."""
    total = sum(item["price"] * item["quantity"] for item in items)
    return total - discount
