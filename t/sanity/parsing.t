print("1..2")

# This tests an indentation bug where a top-level statement immediately
# following a def with an if was attached to the last clause of the if, rather
# than the top-level.
def foo():
    if 1:
        # This comment checks for a different parsefail, where the NEWLINE
        # token didn't correctly skip blank lines.
        print("ok 2")
print("ok 1")

foo()

# vim: ft=python
