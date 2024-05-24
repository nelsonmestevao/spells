#!/usr/bin/env python3
import i3

# yay python-i3-py
# pip install i3-py


def get_active_screens():
    screens = i3.get_outputs()
    return filter(lambda x: x['active'], screens)


def get_focused_workspace():
    workspaces = i3.get_workspaces()
    return next(filter(lambda x: x['focused'], workspaces))


def main():
    active_screens = get_active_screens()
    current_workspace = get_focused_workspace()

    other_screen = next(
        filter(lambda x: x['current_workspace'] != current_workspace['name'],
               active_screens))

    i3.move("workspace to output", other_screen['name'])


if __name__ == "__main__":
    main()
