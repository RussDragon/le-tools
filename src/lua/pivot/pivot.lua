--------------------------------------------------------------------------------
-- pivot.lua: generate pivot tables from tab-separated data
-- This file is a part of le-tools library
-- Copyright (c) le-tools authors (see file `COPYRIGHT` for the license)
--------------------------------------------------------------------------------

require 'lua-nucleo'

local table_sort, table_remove = table.sort, table.remove

local is_table
      = import 'lua-nucleo/type.lua'
      {
        'is_table'
      }

local split_by_char
      = import 'lua-nucleo/string.lua'
      {
        'split_by_char'
      }

local make_concatter
      = import 'lua-nucleo/string.lua'
      {
        'make_concatter'
      }

local tpretty
      = import 'lua-nucleo/tpretty.lua'
      {
        'tpretty'
      }

--------------------------------------------------------------------------------

local create_pivot_processor
do
  local rules
  local step, print_or_step
  local output

  local group_sort_by_sum_fn = function(lhs, rhs)
    return lhs.value > rhs.value
  end

  step = function(dataset, rule_index, prefix)

    -- get column rule
    local rule = rules[rule_index]

    -- aggregate groups
    local groups = { }
    for i = 1, #dataset do
      local row = dataset[i]
      -- ignore excluded rows
      if row then
        local key = row[rule.column]
        local group = groups[key]
        if not group then
          group = { }
          group.key = key
          -- NB: index group by key and by position,
          --     to allow both fast access and use of table.sort
          groups[#groups + 1] = group
          groups[key] = group
        end
        -- calculate sum over group
        group.value = (group.value or 0) + row.value
        -- collect relevant rows
        group[#group + 1] = i
      end
    end

    -- sort groups by sum, descending order
    table_sort(groups, group_sort_by_sum_fn)

    -- pick top rows according to column rule
    local dataset_value = dataset.value
    local sum = 0
    if rule.by_percent then
      -- calculate absolute limit for sum of rows we should collect
      local factor = 100 / dataset_value
      -- collect top rows
      local i = 1
      while sum < rule.count and i < #groups do
        -- account row in sum
        local group = groups[i]
        local value = factor * group.value
        sum = sum + value
        -- remove rows in group from dataset, to not account multiple times
        for j = 1, #group do
          local index = group[j]
          group[j] = dataset[index]
          dataset[index] = false
          dataset.value = dataset.value - group[j].value
        end
        print_or_step(group, rule_index + 1, prefix, group.key, ("%3.4f%%"):format(value))
        i = i + 1
      end
      -- append Others row, if specified
      if rule.others then
        -- drill-down one step deeper using original dataset without extracted rows,
        -- or output if column rules ended
        print_or_step(dataset, rule_index + 1, prefix, rule.others, ("%3.4f%%"):format(100 - sum))
      end
    else
      -- count of rows to collect can not exceed total number of rows in group
      local count = rule.count
      if count > #groups then
        count = #groups
      end
      -- collect 'count' top rows
      for i = 1, count do
        -- account row in sum
        local group = groups[i]
        sum = sum + group.value
        -- remove rows in group from dataset, to not account multiple times
        for j = 1, #group do
          local index = group[j]
          group[j] = dataset[index]
          dataset[index] = false
          dataset.value = dataset.value - group[j].value
        end
        print_or_step(group, rule_index + 1, prefix, group.key, group.value)
      end
      -- append Others row, if specified
      if rule.others then
        -- drill-down one step deeper using original dataset without extracted rows,
        -- or output if column rules ended
        print_or_step(dataset, rule_index + 1, prefix, rule.others, dataset_value - sum)
      end
    end

  end

  print_or_step = function(dataset, rule_index, prefix, key, value)
    if rule_index > #rules then
      output(prefix .. key .. "\t" .. value .. "\n")
    else
      step(dataset, rule_index, prefix .. key .. "\t" .. value .. "\t")
    end
  end

  -- NB: if input is table its content is replaced with falses,
  --     so consider cloning input table
  local process = function(input)

    local dataset = { }
    dataset.value = 0

    -- use input table directly or parse stdin
    if is_table(input) then
      for line = 1, #input do
        local fields = input[line]
        fields.key = #dataset + 1
        fields.value = tonumber(table_remove(fields, 1))
        dataset[fields.key] = fields
        dataset.value = dataset.value + fields.value
      end
    else
      for line in io.lines() do
        local fields = split_by_char(line, "\t")
        fields.key = #dataset + 1
        fields.value = tonumber(table_remove(fields, 1))
        dataset[fields.key] = fields
        dataset.value = dataset.value + fields.value
      end
    end

    -- create output buffer
    local concat
    output, concat = make_concatter()

    -- start pivoting of full dataset from column definition 1 with no prefix
    -- NB: it will recursively call itself until the whole dataset processed
    step(dataset, 1, "")

    -- return output buffer
    return concat()

  end

  create_pivot_processor = function(args)

    -- parse column rules
    rules = { }
    for i = 1, #args do
      local column, count, by_percent, others =
          args[i]:match("(%d+)=(%d+)(%%?)(%+?%w*)")
      assert(column, args[i] .. ": bad rule format");
      rules[#rules + 1] =
        {
          column = tonumber(column);
          count = tonumber(count);
          by_percent = by_percent == "%";
          others = others == "+"
              and "Others"
              or (others:find("+") == 1
                  and others:sub(2)
                  or false);
        }
    end
    assert(rules[1], "must specify at least one column rule")

    return process

  end

end

--------------------------------------------------------------------------------

return
{
  create_pivot_processor = create_pivot_processor;
}
