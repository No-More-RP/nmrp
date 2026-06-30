IS_SERVER = Server ~= nil; --- Tell whether we're running in server or client context. (Client is nil on the server, Server is nil on the client.)
IS_CLIENT = Client ~= nil; --- Tell whether we're running in server or client context. (Client is nil on the server, Server is nil on the client.)

Promise.OnUnhandledRejection(function(reason)
    Console.Error(("Unhandled promise rejection: %s"):format(tostring(reason)));
end);

require 'lib/Index.lua'; -- loads globals (table, class, threading, command) then classes (hook, event-emitter)
require 'locales/Index.lua'; -- registers the "nmrp" locale namespace (en/fr)
