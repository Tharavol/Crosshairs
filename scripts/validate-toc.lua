-- validate-toc.lua
-- SPDX-License-Identifier: GPL-3.0
--
-- Checks the .toc against the files on disk. A TOC that lists a file which doesn't
-- exist -- or exists under a different case -- fails silently in-game: WoW loads the
-- addon, skips the missing file, and raises nothing. That is how the lowercase
-- `crosshairs.toc` survived to v1.2.3, so it's worth a CI gate.
--
-- File names come from `git ls-files` rather than the filesystem, because Windows and
-- macOS report a case-insensitive match and would hide exactly the bug being looked for.
-- Git records the true case on every platform.
--
-- Usage: lua scripts/validate-toc.lua   (run from the repository root)

local errors = {}

local function fail(fmt, ...)
    errors[#errors + 1] = string.format(fmt, ...)
end

local function readFile(path)
    local handle = io.open(path, "r")
    if not handle then return nil end
    local contents = handle:read("*a")
    handle:close()
    return contents
end

-- Every tracked path, exact-case, as a set plus an ordered list.
local function trackedFiles()
    local pipe = assert(io.popen("git ls-files"), "could not run `git ls-files`")
    local set, list = {}, {}
    for rawLine in pipe:lines() do
        local path = rawLine:gsub("\r$", "")
        if path ~= "" then
            set[path] = true
            list[#list + 1] = path
        end
    end
    pipe:close()
    assert(#list > 0, "`git ls-files` returned nothing -- run this from the repository root")
    return set, list
end

local tracked, trackedList = trackedFiles()

-- package-as from .pkgmeta is the name the zip extracts to, and the folder WoW loads.
local function packageName()
    local pkgmeta = readFile(".pkgmeta")
    if not pkgmeta then
        fail(".pkgmeta not found")
        return nil
    end
    local name = pkgmeta:match("package%-as:%s*([^\r\n]+)")
    if not name then
        fail(".pkgmeta has no `package-as:` key")
        return nil
    end
    return (name:gsub("%s+$", ""))
end

local packageAs = packageName()

local tocs = {}
for _, path in ipairs(trackedList) do
    if path:match("^[^/]+%.toc$") then tocs[#tocs + 1] = path end
end

if #tocs == 0 then
    fail("no .toc file found in the repository root")
end

for _, tocPath in ipairs(tocs) do
    local basename = tocPath:match("^(.+)%.toc$")

    -- The packager also accepts Name_Flavor.toc for per-flavour builds.
    if packageAs and basename ~= packageAs and basename:match("^([^_]+)_") ~= packageAs then
        fail("%s: basename %q does not match `package-as: %s` in .pkgmeta",
            tocPath, basename, packageAs)
    end

    local contents = readFile(tocPath)
    if not contents then
        fail("%s: could not be read", tocPath)
    else
        local interface, version
        local lineNumber = 0
        for rawLine in (contents .. "\n"):gmatch("([^\n]*)\n") do
            lineNumber = lineNumber + 1
            local line = rawLine:gsub("\r$", ""):gsub("^%s+", ""):gsub("%s+$", "")

            local key, value = line:match("^##%s*([%w%-]+)%s*:%s*(.-)$")
            if key then
                if key:lower() == "interface" then interface = value end
                if key:lower() == "version" then version = value end
            elseif line ~= "" and not line:match("^#") then
                -- A content line: a file the addon expects to load.
                local file = line:match("^([^%s]+)")
                if file then
                    local relative = file:gsub("\\", "/")
                    if not tracked[relative] then
                        local hint = ""
                        for candidate in pairs(tracked) do
                            if candidate:lower() == relative:lower() then
                                hint = string.format(" -- tracked as %q (case mismatch)", candidate)
                                break
                            end
                        end
                        fail("%s:%d: lists %q, which is not a tracked file%s",
                            tocPath, lineNumber, file, hint)
                    end
                end
            end
        end

        if not interface then
            fail("%s: no `## Interface:` line", tocPath)
        elseif not interface:match("^%d%d%d%d%d%d?$") then
            fail("%s: `## Interface: %s` is not a 5- or 6-digit number", tocPath, interface)
        end

        if not version or version == "" then
            fail("%s: no `## Version:` line", tocPath)
        end
    end
end

if #errors > 0 then
    io.stderr:write("TOC validation failed:\n")
    for _, message in ipairs(errors) do
        io.stderr:write("  - " .. message .. "\n")
    end
    os.exit(1)
end

io.write(string.format("TOC validation passed (%d file%s checked)\n",
    #tocs, #tocs == 1 and "" or "s"))
