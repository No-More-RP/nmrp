--- Index.lua: project locale pack. Loads the per-package translation files; each
--- one self-registers under the "nmrp" namespace via Locale.Namespace("nmrp").
--- Required from Shared/Index.lua, so both realms (server + client) register.
require 'en.lua';
require 'fr.lua';
