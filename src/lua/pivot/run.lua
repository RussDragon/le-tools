#!/usr/bin/env le-lua-interpreter

--------------------------------------------------------------------------------
-- run.lua: tool for making pivot tables from tab-separated data
-- This file is a part of le-tools library
-- Copyright (c) le-tools authors (see file `COPYRIGHT` for the license)
--------------------------------------------------------------------------------

require 'lua-nucleo'

local create_pivot_processor
      = import 'le-tools/pivot/pivot.lua'
      {
        'create_pivot_processor'
      }

local make_concatter
      = import 'lua-nucleo/string.lua'
      {
        'make_concatter'
      }

local tiwalk
      = import 'lua-nucleo/table-utils.lua'
      {
        'tiwalk'
      }

local tpretty
      = import 'lua-nucleo/tpretty.lua'
      {
        'tpretty'
      }

--------------------------------------------------------------------------------

local run = function(format, ...)
  -- make pivot table
  local pivot = create_pivot_processor({...})()
  -- output with respoect to format
  -- Lua table
  if format == "lua" then
    io.write(tpretty(pivot), "\n")
  -- JSON
  elseif format == "json" then
    -- NB: can't use tiwalk since it doesn't provide index
    --     to distinguish the last element
    local function to_json(elem, index)
      if index > 1 then
        io.write(",")
      end
      io.write("{")
      io.write(
          '"k":"',
          elem.key,
          '","v":"',
          elem.value,
          '"'
        )
      if elem.children then
        io.write(',"c":')
        io.write("[")
        for i = 1, #elem.children do
          to_json(elem.children[i], i)
        end
        io.write("]")
      end
      io.write("}")
    end
    io.write("[")
    for i = 1, #pivot do
      to_json(pivot[i], i)
    end
    io.write("]", "\n")
  -- tree
  elseif format == "html" then
    local cat, concat = make_concatter()
    local function to_tree(elem, prefix)
      local output = function(...)
        local args = {...}
        for i = 1, #args do
          cat(prefix .. args[i])
        end
      end
      output(
          '<li class="tree">',
          "\t" .. '<span class="tree-item">' .. elem.key .. " " .. elem.value .. '</span>'
        )
      if elem.children and #elem.children > 0 then
        output("\t" .. '<ul class="tree">')
        tiwalk(to_tree, elem.children, prefix .. "\t\t")
        output("\t" .. '</ul>')
      end
      output('</li>')
    end
    cat('<ul class="tree">')
    tiwalk(to_tree, pivot, "\t")
    cat('</ul>')
    io.write(concat("\n"))
  -- text with node paths expansion
  else
    local function to_text(elem, prefix)
      if elem.children then
        tiwalk(
            to_text,
            elem.children,
            prefix .. elem.key .. "\t" .. elem.value .. "\t"
          )
      else
        io.write(prefix, elem.key, "\t", elem.value, "\n")
      end
    end
    tiwalk(to_text, pivot, "")
  end
end

--------------------------------------------------------------------------------

return
{
  run = run;
}
