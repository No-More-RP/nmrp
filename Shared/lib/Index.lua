--- Boot only loads globals/ (they extend _G and must exist before anything runs).
--- classes/ are importable, each is required on demand by its consumer
--- (e.g. `require 'lib/classes/hook.lua'`), so they are intentionally NOT loaded here.
require 'globals/Index.lua';
