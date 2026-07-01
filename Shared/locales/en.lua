local L <const> = Locale.Namespace("nmrp");

L:Register('en', {
    inventory = {
        title = "Inventory",
        close = "Close",
        unit_weight = "kg",
        hint = {
            use = "Double-click: use",
            move = "Drag: move",
            drop = "Right-click: drop",
            close = "Escape: close",
        },
        item = {
            actions = "double-click to use, right-click to drop",
        },
    },
    chat = {
        placeholder = "Enter to send · / for a command · Esc to close",
        welcome = "Welcome, press T to chat, / for a command.",
    },
});
