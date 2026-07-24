-- Fail if rbxassetid:// appears outside allowlisted deployment files.
-- Run: lune run scripts/audit-assets.luau

local fs = require("@lune/fs")
local process = require("@lune/process")

-- Deployment / pure URI builders only. Do not expand without policy change.
local ALLOWLIST = {
	["src/shared/IconAssets.luau"] = true,
	["src/shared/AssetIds.luau"] = true,
}

local function walk(dir: string, out: { string })
	for _, name in ipairs(fs.readDir(dir)) do
		local path = dir .. "/" .. name
		if fs.isDir(path) then
			if name ~= ".git" and name ~= "build" and name ~= "node_modules" then
				walk(path, out)
			end
		elseif string.sub(name, -5) == ".luau" or string.sub(name, -4) == ".lua" then
			table.insert(out, path)
		end
	end
end

-- Audit production sources only (tests may assert URI strings).
local files = {}
walk("src", files)

local findings = {}
for _, path in ipairs(files) do
	local rel = path
	if string.sub(rel, 1, 2) == "./" then
		rel = string.sub(rel, 3)
	end
	local body = fs.readFile(path)
	if string.find(body, "rbxassetid://", 1, true) then
		if not ALLOWLIST[rel] then
			table.insert(findings, rel)
		end
	end
end

if #findings > 0 then
	print("audit-assets: FAIL rbxassetid outside allowlist:")
	for _, f in ipairs(findings) do
		print("  - " .. f)
	end
	process.exit(1)
end

-- Prove IconAssets is the cloud-id home (file exists; may still be all zeros).
assert(fs.isFile("src/shared/IconAssets.luau"), "IconAssets.luau missing")
print("audit-assets: PASS (allowlist IconAssets+AssetIds for rbxassetid://)")
