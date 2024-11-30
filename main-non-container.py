import time
import random
import string
import os


def is_prime(n):
    """Check if a number is prime."""
    if n <= 1:
        return False
    if n <= 3:
        return True
    if n % 2 == 0 or n % 3 == 0:
        return False
    i = 5
    while i * i <= n:
        if n % i == 0 or n % (i + 2) == 0:
            return False
        i += 6
    return True


def calculate_primes_for_duration(duration_seconds):
    """Calculate prime numbers for the specified duration in seconds."""
    start_time = time.time()
    primes = []
    current_number = 2

    while time.time() - start_time < duration_seconds:
        if is_prime(current_number):
            primes.append(current_number)
        current_number += 1

    return primes


def generate_random_filename(extension="txt"):
    """Generate a random filename with the given extension."""
    random_str = ''.join(random.choices(string.ascii_letters + string.digits, k=24))
    return f"{random_str}.{extension}"


def write_highest_prime_to_file(duration_seconds):
    """Calculate primes for the given duration and write the highest prime to a shared volume."""
    primes = calculate_primes_for_duration(duration_seconds)
    if primes:
        highest_prime = primes[-1]
        filename = generate_random_filename()
        filepath = os.path.join("./data-non-container", filename)
        with open(filepath, "w") as file:
            file.write(f"{highest_prime}")
    else:
        print("No primes were found within the duration.")


if __name__ == "__main__":
    duration = 30
    write_highest_prime_to_file(duration)
