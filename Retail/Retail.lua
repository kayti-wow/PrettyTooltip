-- Retail's own code lives in the Retail/ folder, which only retail's .toc
-- (PrettyTooltip_Mainline.toc) loads; this file comes first. Retail/README.md
-- says how it reaches the shared code. In short, each file is named for the
-- shared file it serves:
-- - Retail/<path>.lua loads just before <path>.lua and adds data to its lists
--   (ns.contribute), or, where retail's .toc leaves <path>.lua out, stands in
--   for it (Retail/Data/Schools.lua).
-- - Retail/<path>Extension.lua loads just after <path>.lua and changes what it
--   does: a tooltip type's descriptor.extension, or ns.replace.
-- Shared code never asks which client it runs on.
local _, ns = ...
-- Retail's files share their parts here. Only the tests and the package check
-- ask whether it is there (ns.IsRetail).
ns.Retail = {}
