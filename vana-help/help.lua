-- This resource's pages in /help (see server.lua). Every resource with commands has a help.lua like
-- it: `HelpPages`, one page per command or topic, and getHelpPages exported in its meta.xml.
--   name     the command (without /) or a topic's name;  topic = true for a page that isn't a command
--   usage    how to type it;  aliases: other names for it
--   right    the ACL right that shows it (the command's own, "command.<name>"); none: everyone
--   console  console only (the self-tests)
--   summary  one line for the list;  text: the page;  see: related pages
HelpPages = {
    { name = "help", aliases = { "?" }, usage = "/help [command, topic or word]",
      summary = "This manual: the commands and topics you can use",
      text = [[With nothing after it, the list of everything you can use, by area. With a command's or topic's name, its page; with any other word, the pages that mention it.

In the manual: Up/Down to choose (or scroll a page), Enter to open, Backspace to go back, Escape to close.

Only what you're allowed to use is listed: admin commands show to admins, the self-tests only at the server console.]],
      see = { "man" } },
    { name = "man", usage = "/man <command or topic>", summary = "One page of the manual (as /help <name>)",
      text = [[Opens the page for a command or topic, as /help <name> does.]], see = { "help" } },
}

function getHelpPages() return HelpPages end
