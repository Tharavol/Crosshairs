-- test_helpers.lua
-- SPDX-License-Identifier: GPL-3.0
--
-- A minimal, dependency-free test runner: no rock beyond the luacheck one CI already
-- installs. Spec files call M.Test(name, fn); fn raises (via M.AssertEqual etc.) to fail.

local M = { passed = 0, failed = 0 }

function M.Test(name, fn)
    local ok, err = pcall(fn)
    if ok then
        M.passed = M.passed + 1
        print("  ok   " .. name)
    else
        M.failed = M.failed + 1
        print("  FAIL " .. name .. ": " .. tostring(err))
    end
end

function M.AssertEqual(actual, expected, msg)
    if actual ~= expected then
        error(string.format("%s: expected %s, got %s", msg or "values differ",
            tostring(expected), tostring(actual)), 2)
    end
end

function M.AssertTrue(value, msg)
    if not value then error(msg or "expected a truthy value", 2) end
end

function M.AssertFalse(value, msg)
    if value then error(msg or "expected a falsy value", 2) end
end

function M.Summary()
    print(string.format("\n%d passed, %d failed", M.passed, M.failed))
    return M.failed == 0
end

return M
