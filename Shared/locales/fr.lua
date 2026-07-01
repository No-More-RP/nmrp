local L <const> = Locale.Namespace("nmrp");

L:Register('fr', {
    inventory = {
        title = "Inventaire",
        close = "Fermer",
        unit_weight = "kg",
        hint = {
            use = "Double-clic : utiliser",
            move = "Glisser : déplacer",
            drop = "Clic droit : jeter",
            close = "Échap : fermer",
        },
        item = {
            actions = "double-clic pour utiliser, clic droit pour jeter",
        },
    },
    chat = {
        placeholder = "Entrée pour envoyer · / pour une commande · Échap pour fermer",
        welcome = "Bienvenue, appuie sur T pour discuter, / pour une commande.",
        bind_description = "Ouvrir/Fermer le chat",
    },
});
